// =====================================
// lib/pages/anime_list_page.dart  （シート優先：SHEET_CSV_URL があればシート→失敗時 Supabase）
// =====================================
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http; // ★ 追加
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 認証状態チェック用

import '../core/constants.dart';
import '../models/anime.dart';
import '../models/filter_preset.dart';
import '../repositories/anime_repository.dart';
import '../services/rating_service.dart'; // AuthRequired を catch するためにも必要
import '../widgets/anime_row.dart';
import '../widgets/filter_panel.dart';
import '../pages/login_page.dart'; // ログイン画面へ遷移
import '../models/rank.dart';

// ★ 追加：サーバー件数RPCを呼ぶサービス
import '../services/supabase_service.dart';

/// 表示用ランクフィルタ
enum RankFilter { all, gold, silver }
/// 視聴状態フィルタ
enum WatchedFilter { all, watched, unwatched }
/// ジャンルの結合モード
enum GenreFilterMode { or, and }

class AnimeListPage extends StatefulWidget {
  const AnimeListPage({super.key});
  @override
  State<AnimeListPage> createState() => _AnimeListPageState();
}

class _AnimeListPageState extends State<AnimeListPage> {
  void _log(String msg) {
    if (kDebugMode) debugPrint('[AnimeListPage] $msg');
  }

  // ★ 追加：ビルド時に --dart-define=SHEET_CSV_URL=... を渡すと入る
  static const String _sheetCsvUrl =
      String.fromEnvironment('SHEET_CSV_URL', defaultValue: '');

  late final AnimeRepository _repo;
  late final RatingsService _ratings;

  final Set<String> _expandedIds = {};
  final Set<String> _watchedIds = {};
  final Set<String> _ratingBusyIds = {}; // 星連打ガード

  bool _filtersOpen = true;

  List<Anime> _all = [];
  List<Anime> _filtered = [];

  // フィルタ条件
  String _keyword = '';
  Set<String> _genreFilter = {};
  GenreFilterMode _genreMode = GenreFilterMode.or;
  double _starMin = 0, _starMax = 5;
  Set<String> _serviceFilters = {};
  RankFilter _rankFilter = RankFilter.all;
  WatchedFilter _watchedFilter = WatchedFilter.all;
  int? _yearMinSelected, _yearMaxSelected;

  List<FilterPreset> _presets = [];
  bool _loading = true;
  String? _error;

  // ★ 追加：サーバー集計結果
  int _serverTotal = 0;
  int _serverWatched = 0;
  bool _countLoading = false;

  // 初回ロードを FutureBuilder で待つ用
  Future<void>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _log('initState');
    _repo = AnimeRepository();
    _ratings = RatingsService.supabase(); // Supabase 経由の評価サービス

    // 初回ロード（FutureBuilder で待機）
    _loadFuture = _bootstrap();
  }

  /// 初期化〜一覧取得（シート優先→失敗なら Supabase）
  Future<void> _bootstrap() async {
    _log('_bootstrap: start (sheetFirst=${_sheetCsvUrl.isNotEmpty})');
    try {
      await _loadPresets();
      await _loadWatched();

      List<Anime> list = [];

      // --- シート優先 ---
      if (_sheetCsvUrl.isNotEmpty) {
        try {
          list = await _fetchFromSheetCsv(_sheetCsvUrl);
          _log('_bootstrap: sheet rows=${list.length}');
        } catch (e) {
          _log('_bootstrap: sheet fetch failed -> fallback to Supabase. error=$e');
        }
      }

      // --- フォールバック：Supabase ---
      if (list.isEmpty) {
        _log('_bootstrap: fetchAll(Supabase)');
        list = await _repo.fetchAll();
      }

      _log('_bootstrap: attachRatings');
      final withRatings = await _ratings.attachRatings(list); // 自分の評価を合成（RPCで同梱なら恒等）

      if (!mounted) return;
      setState(() {
        _all = withRatings;
        _filtered = _calcFiltered();
        _loading = false;
        _error = null;
      });

      // ★ 初回の件数も取得
      await _loadCounts();

      _log('_bootstrap: done (items=${_all.length})');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
      _log('_bootstrap: error=$e');
      rethrow; // FutureBuilder でも検知できるように投げ直す
    }
  }

  // ===== シートCSV → Anime[] 変換 =====
  Future<List<Anime>> _fetchFromSheetCsv(String url) async {
    _log('_fetchFromSheetCsv: GET $url');
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('CSV HTTP ${res.statusCode}');
    }
    final csv = utf8.decode(res.bodyBytes);

    // 1行目=ヘッダ（id,title,kana,summary,year,genres,services）
    final lines = csv.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return [];

    final header = _splitCsvLine(lines.first);
    final idx = {
      for (int i = 0; i < header.length; i++) header[i].trim().toLowerCase(): i
    };

    List<Anime> out = [];
    for (int i = 1; i < lines.length; i++) {
      final cols = _splitCsvLine(lines[i]);

      String get(String name) {
        final j = idx[name];
        return (j == null || j >= cols.length) ? '' : cols[j].trim();
      }

      final id = get('id');
      final title = get('title');
      if (id.isEmpty || title.isEmpty) continue;

      // optional
      final kana = get('kana');
      final summary = get('summary');
      final yearStr = get('year');
      final year = int.tryParse(yearStr);
      final genres = _splitTags(get('genres'));   // カンマ or / 区切りを想定
      final services = _splitTags(get('services'));

      // Anime へのマッピング
      // ここでは一般的なフィールド名に合わせた例。
      // （あなたの Anime モデルのコンストラクタに合わせて調整してください）
      final anime = Anime(
        id: id,
        title: title,
        kana: kana.isEmpty ? null : kana,
        summary: summary.isEmpty ? null : summary,
        year: year,
        genres: genres,
        // streams: List<StreamInfo> 的な型であれば最小限に詰める
        streams: services.map((s) => StreamLink(service: s, url: '')).toList(),
        // 評価関連は最初は空でOK（attachRatingsで合成）
        avgRating: null,
        ratingCount: null,
        userRating: null,
      );

      out.add(anime);
    }
    return out;
  }

  /// 超軽量CSV行パーサ（ダブルクオート対応・最低限）
  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        // 連続 "" はエスケープ
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        result.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    result.add(buf.toString());
    return result;
  }

  List<String> _splitTags(String raw) {
    if (raw.isEmpty) return const [];
    final sep = raw.contains(',') ? ',' : raw.contains('/') ? '/' : '、';
    return raw
        .split(sep)
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _loadFuture = _bootstrap();
    });
    await _loadFuture;
  }

  Future<void> _loadPresets() async {
    _log('_loadPresets');
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('filter_presets') ?? [];
    _presets = raw.map((s) => FilterPreset.fromJsonString(s)).toList();
    _log('_loadPresets: count=${_presets.length}');
  }

  Future<void> _savePresets() async {
    _log('_savePresets');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'filter_presets',
      _presets.map((e) => e.toJsonString()).toList(),
    );
  }

  Rank _rankOf(Anime a) {
    final avg = a.avgRating ?? 0.0;
    final cnt = a.ratingCount ?? 0;

    if (cnt >= kGoldMinCount && avg >= kGoldHiAvg) return Rank.gold;

    final byCountAvg =
        (cnt >= kSilverCnt1 && avg >= kSilverAvg1) ||
        (cnt >= kSilverCnt2 && avg >= kSilverAvg2);
    if (byCountAvg) return Rank.silver;

    return Rank.other;
  }

  List<Anime> _calcFiltered() {
    _log('_calcFiltered: start');
    final selectedServicesLower =
        _serviceFilters.map((e) => e.toLowerCase()).toSet();
    final kw = _keyword.trim();

    final filtered = _all.where((a) {
      final okKeyword = kw.isEmpty ||
          a.title.contains(kw) ||
          (a.kana?.contains(kw) ?? false) ||
          (a.summary?.contains(kw) ?? false);

      final okGenre = _genreFilter.isEmpty ||
          (_genreMode == GenreFilterMode.or
              ? a.genres.any(_genreFilter.contains)
              : _genreFilter.every((g) => a.genres.contains(g)));

      final avg = a.avgRating ?? 0;
      final okStar = avg >= _starMin && avg <= _starMax;

      final okService = selectedServicesLower.isEmpty ||
          a.streams.any((s) => selectedServicesLower.contains(s.service.toLowerCase()));

      final y = a.year ?? 0;
      final okYear =
          (_yearMinSelected == null || y >= _yearMinSelected!) &&
          (_yearMaxSelected == null || y <= _yearMaxSelected!);

      final r = _rankOf(a);
      final okRank = _rankFilter == RankFilter.all ||
          (_rankFilter == RankFilter.gold && r == Rank.gold) ||
          (_rankFilter == RankFilter.silver && r == Rank.silver);

      final okWatched = _watchedFilter == WatchedFilter.all ||
          (_watchedFilter == WatchedFilter.watched && _watchedIds.contains(a.id)) ||
          (_watchedFilter == WatchedFilter.unwatched && !_watchedIds.contains(a.id));

      return okKeyword && okGenre && okStar && okService && okYear && okRank && okWatched;
    }).toList();

    _log('_calcFiltered: done (filtered=${filtered.length})');
    return filtered;
  }

  void _refreshFiltered() {
    if (!mounted) return;
    setState(() => _filtered = _calcFiltered());
    // ★ フィルタ更新のたびにサーバー件数も更新
    _loadCounts();
  }

  // ★ 追加：サーバーの件数を取得（count_filtered_anime RPC）
  Future<void> _loadCounts() async {
    _log('_loadCounts: start');
    setState(() => _countLoading = true);
    try {
      final (t, w) = await fetchCounts(
        keyword: _keyword.isEmpty ? null : _keyword,
        genres: _genreFilter.isEmpty ? null : _genreFilter.toList(),
        yearMin: _yearMinSelected,
        yearMax: _yearMaxSelected,
        services: _serviceFilters.isEmpty ? null : _serviceFilters.toList(),
      );
      if (!mounted) return;
      setState(() {
        _serverTotal = t;
        _serverWatched = w;
        _countLoading = false;
      });
      _log('_loadCounts: done total=$_serverTotal watched=$_serverWatched');
    } catch (e) {
      if (!mounted) return;
      setState(() => _countLoading = false);
      _log('_loadCounts: error=$e');
      // 失敗してもUIは落とさず、件数は前回値のままにする
    }
  }

  /// 未ログインならログイン画面へ誘導（true=ログイン済/false=未ログインのまま）
  Future<bool> _requireAuth(BuildContext context) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) return true;

    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );

    // 戻り値が null の場合でも、遷移先でログイン完了していれば OK にする
    return ok == true || Supabase.instance.client.auth.currentUser != null;
  }

  /// 星タップ → 認証チェック → RPC で保存 → ローカルリスト更新
  Future<void> _setRating(Anime anime, int stars) async {
    _log('_setRating: anime=${anime.id}, stars=$stars');

    // 1) 認証チェック（未ログインなら遷移）
    final authed = await _requireAuth(context);
    if (!authed) {
      _log('_setRating: cancelled (not authed)');
      return;
    }

    // 2) 連打ガード
    if (_ratingBusyIds.contains(anime.id)) {
      _log('_setRating: skip (busy)');
      return;
    }
    _ratingBusyIds.add(anime.id);

    // 3) 同じ星を再タップで「削除(null)」
    final current = anime.userRating;
    final int? newRating = (current == stars) ? null : stars;

    // 4) 失敗時に戻す用コピー
    final backup = anime;

    try {
      final updated = await _ratings.rate(anime.id, newRating);

      if (!mounted) return;
      setState(() {
        final idx = _all.indexWhere((x) => x.id == anime.id);
        if (idx >= 0) {
          _all[idx] = _all[idx].copyWith(
            userRating: updated.userRating,
            avgRating: updated.avgRating,
            ratingCount: updated.ratingCount,
          );
        }
        _filtered = _calcFiltered();
      });

      // ★ 評価が変わったら「視聴済み件数」に影響するので再集計
      _loadCounts();

    // ← 念のため、サービス層が AuthRequired を投げた場合もここで捕捉して遷移
    } on AuthRequired {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      // ログイン後に再タップしてもらう（自動再送はしない）
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログイン後にもう一度★をタップしてください')),
      );

    } catch (e) {
      _log('_setRating: error=$e');
      if (!mounted) return;
      setState(() {
        final idx = _all.indexWhere((x) => x.id == backup.id);
        if (idx >= 0) _all[idx] = backup;
        _filtered = _calcFiltered();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('評価の送信に失敗しました: $e')),
      );
    } finally {
      _ratingBusyIds.remove(anime.id);
    }
  }

  Future<void> _loadWatched() async {
    _log('_loadWatched');
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('watched_ids') ?? const <String>[];
    _watchedIds
      ..clear()
      ..addAll(ids.where((e) => e.trim().isNotEmpty));
    _log('_loadWatched: count=${_watchedIds.length}');
  }

  Future<void> _saveWatched() async {
    _log('_saveWatched');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('watched_ids', _watchedIds.toList());
  }

  void _toggleWatched(String id, bool v) {
    _log('_toggleWatched: id=$id, v=$v');
    if (id.trim().isEmpty) return;
    setState(() {
      if (v) {
        _watchedIds.add(id);
      } else {
        _watchedIds.remove(id);
      }
      _filtered = _calcFiltered();
    });
    _saveWatched();
  }

  // ===== 検索 + 開閉/保存/履歴 =====
  Widget _buildSearchAndActionsRow({required bool filtersOpen}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('検索:'),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'タイトル検索',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              ),
              onChanged: (v) {
                _keyword = v.trim();
                _log('keyword changed: "$_keyword"');
                _refreshFiltered();
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: FilledButton.tonal(
                    onPressed: () {
                      setState(() => _filtersOpen = !_filtersOpen);
                      _log('_filtersOpen toggled: now=$_filtersOpen');
                    },
                    child: Text(filtersOpen ? '閉じる' : '開く'),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 40,
                child: FilledButton(
                  onPressed: () async {
                    _log('save filter preset dialog open');
                    final nameController =
                        TextEditingController(text: 'プリセット ${_presets.length + 1}');
                    final name = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('フィルタを保存'),
                        content: TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: '名前'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('キャンセル'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(ctx, nameController.text.trim()),
                            child: const Text('保存'),
                          ),
                        ],
                      ),
                    );
                    if (name == null || name.isEmpty) return;
                    setState(() {
                      _presets.add(
                        FilterPreset(
                          name: name,
                          keyword: _keyword,
                          genres: _genreFilter.toList(),
                          starMin: _starMin,
                          starMax: _starMax,
                          service:
                              _serviceFilters.isEmpty ? null : _serviceFilters.first,
                          rank: _rankFilter,
                        ),
                      );
                    });
                    await _savePresets();
                    _log('preset saved: $name');
                  },
                  child: const Text('フィルタを保存'),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                height: 40,
                child: PopupMenuButton<int>(
                  tooltip: '保存済みフィルタ',
                  itemBuilder: (ctx) => [
                    for (int i = 0; i < _presets.length; i++)
                      PopupMenuItem<int>(
                        value: i,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_presets[i].name),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () async {
                                    final c = TextEditingController(
                                        text: _presets[i].name);
                                    final newName = await showDialog<String>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('プリセット名の変更'),
                                        content: TextField(controller: c),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx),
                                            child: const Text('キャンセル'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, c.text.trim()),
                                            child: const Text('保存'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (newName == null || newName.isEmpty) return;
                                    setState(() {
                                      _presets[i] =
                                          _presets[i].copyWith(name: newName);
                                    });
                                    await _savePresets();
                                    _log('preset renamed: $newName');
                                  },
                                  icon: const Icon(Icons.edit),
                                ),
                                IconButton(
                                  onPressed: () async {
                                    final removed = _presets.removeAt(i);
                                    setState(() {});
                                    await _savePresets();
                                    _log('preset removed: ${removed.name}');
                                  },
                                  icon: const Icon(Icons.delete),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                  onSelected: (i) {
                    final p = _presets[i];
                    setState(() {
                      _keyword = p.keyword;
                      _genreFilter = p.genres.toSet();
                      _starMin = p.starMin;
                      _starMax = p.starMax;
                      _serviceFilters =
                          p.service == null ? <String>{} : {p.service!};
                      _rankFilter = p.rank ?? RankFilter.all;
                      _filtered = _calcFiltered();
                    });
                    _log('preset applied: ${p.name}');
                    _loadCounts(); // ★ プリセット適用時も件数更新
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text('履歴', style: TextStyle(fontSize: 15)),
                  ),
                ),
              ),
            ],
          ),

          // ★ 追加：件数バー（サーバー集計）
          const SizedBox(height: 8),
          _CountsBar(
            total: _serverTotal,
            watched: _serverWatched,
            loading: _countLoading,
          ),
        ],
      ),
    );
  }

  // ===== build =====
  @override
  Widget build(BuildContext context) {
    _log('build (loading=$_loading, error=$_error, filtered=${_filtered.length})');
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        // ロード中
        if (snapshot.connectionState == ConnectionState.waiting || _loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // エラー
        if (snapshot.hasError || _error != null) {
          final msg = (_error ?? snapshot.error)?.toString() ?? 'unknown';
          return Scaffold(
            appBar: AppBar(
              title: const Text('ANiTY'),
              actions: [
                IconButton(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  tooltip: '再読込',
                ),
              ],
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('読み込みエラー: $msg'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('再試行'),
                  ),
                ],
              ),
            ),
          );
        }

        // 正常表示
        return Scaffold(
          appBar: AppBar(
            title: const Text('ANiTY'),
            actions: [
              IconButton(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                tooltip: '再読込',
              ),
            ],
          ),
          body: ScrollConfiguration(
            behavior: const _NoGlowBehavior(),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildSearchAndActionsRow(filtersOpen: _filtersOpen),
                ),
                if (_filtersOpen) ...[
                  SliverToBoxAdapter(
                    child: FilterPanel(
                      // 入力
                      genreFilter: _genreFilter,
                      genreMode: _genreMode,
                      serviceFilters: _serviceFilters,
                      rankFilter: _rankFilter,
                      watchedFilter: _watchedFilter,
                      starMin: _starMin,
                      starMax: _starMax,
                      yearMin: _yearMinSelected,
                      yearMax: _yearMaxSelected,
                      // 更新コールバック
                      onChangeGenreMode: (m) {
                        _genreMode = m;
                        _log('genreMode changed: $m');
                        _refreshFiltered();
                      },
                      onToggleGenre: (g, v) {
                        if (v) {
                          _genreFilter.add(g);
                        } else {
                          _genreFilter.remove(g);
                        }
                        _log('toggleGenre: $g -> $v');
                        _refreshFiltered();
                      },
                      onClearGenres: () {
                        _genreFilter.clear();
                        _log('clearGenres');
                        _refreshFiltered();
                      },
                      onToggleService: (s, v) {
                        if (v) {
                          _serviceFilters.add(s);
                        } else {
                          _serviceFilters.remove(s);
                        }
                        _log('toggleService: $s -> $v');
                        _refreshFiltered();
                      },
                      onClearServices: () {
                        _serviceFilters.clear();
                        _log('clearServices');
                        _refreshFiltered();
                      },
                      onSetYearRange: (minY, maxY) {
                        _yearMinSelected = minY;
                        _yearMaxSelected = maxY;
                        _log('setYearRange: $minY ~ $maxY');
                        _refreshFiltered();
                      },
                      onClearYearRange: () {
                        _yearMinSelected = null;
                        _yearMaxSelected = null;
                        _log('clearYearRange');
                        _refreshFiltered();
                      },
                      onSetStarRange: (min, max) {
                        _starMin = min;
                        _starMax = max;
                        _log('setStarRange: $min ~ $max');
                        _refreshFiltered();
                      },
                      onResetStarRange: () {
                        _starMin = 0;
                        _starMax = 5;
                        _log('resetStarRange');
                        _refreshFiltered();
                      },
                      onChangeRank: (r) {
                        _rankFilter = r;
                        _log('rankFilter changed: $r');
                        _refreshFiltered();
                      },
                      onChangeWatched: (w) {
                        _watchedFilter = w;
                        _log('watchedFilter changed: $w');
                        _refreshFiltered();
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: Divider(height: 1)),
                ] else
                  const SliverToBoxAdapter(child: Divider(height: 1)),

                if (_filtered.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('該当なし')),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, idx) {
                        if (idx.isOdd) return const Divider(height: 1);
                        final itemIndex = idx ~/ 2;
                        final a = _filtered[itemIndex];
                        return AnimeRow(
                          anime: a,
                          rank: _rankOf(a),
                          expanded: _expandedIds.contains(a.id),
                          watched: _watchedIds.contains(a.id),
                          onToggleExpand: () => setState(() {
                            _expandedIds.contains(a.id)
                                ? _expandedIds.remove(a.id)
                                : _expandedIds.add(a.id);
                            _log('toggleExpand: id=${a.id}, expanded=${_expandedIds.contains(a.id)}');
                          }),
                          onToggleWatched: (v) => _toggleWatched(a.id, v),
                          onRate: (v) => _setRating(a, v), // ★ 星タップで実行
                        );
                      },
                      childCount: _filtered.isEmpty ? 0 : (_filtered.length * 2 - 1),
                    ),
                  ),

                SliverPadding(padding: EdgeInsets.only(bottom: bottomInset)),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ★ 追加：件数バー用の小さなウィジェット
class _CountsBar extends StatelessWidget {
  final int total;
  final int watched;
  final bool loading;
  const _CountsBar({
    required this.total,
    required this.watched,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        if (loading)
          const SizedBox(
            width: 18,
            height: 18,
            child: Padding(
              padding: EdgeInsets.only(right: 6),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        Text(
          loading ? '集計中…' : '$total 件中 $watched 件視聴済み',
          style: style,
        ),
      ],
    );
  }
}

class _NoGlowBehavior extends ScrollBehavior {
  const _NoGlowBehavior();
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}