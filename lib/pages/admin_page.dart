import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 管理者用：作品の登録/更新/削除 最小フォーム
/// 既存機能に干渉しない独立ページです。
/// 使い方：id を入力 → [読込] で既存データ取得 → 編集して [保存]
/// 新規作成はそのまま [保存] で upsert されます。削除は [削除]。
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final _formKey = GlobalKey<FormState>();

  final _id = TextEditingController();
  final _title = TextEditingController();
  final _kana = TextEditingController();
  final _year = TextEditingController();
  final _genres = TextEditingController(); // カンマ区切り: "SF, 日常"

  // streams は可変行：service / url
  final List<TextEditingController> _services = [];
  final List<TextEditingController> _urls = [];

  bool _loading = false;

  @override
  void dispose() {
    _id.dispose();
    _title.dispose();
    _kana.dispose();
    _year.dispose();
    _genres.dispose();
    for (final c in _services) c.dispose();
    for (final c in _urls) c.dispose();
    super.dispose();
  }

  SupabaseClient get _supa => Supabase.instance.client;

  void _ensureRow(int i) {
    while (_services.length <= i) {
      _services.add(TextEditingController());
      _urls.add(TextEditingController());
    }
  }

  void _clearStreams() {
    for (final c in _services) c.dispose();
    for (final c in _urls) c.dispose();
    _services.clear();
    _urls.clear();
  }

  List<Map<String, String>> _collectStreams() {
    final out = <Map<String, String>>[];
    for (var i = 0; i < _services.length; i++) {
      final s = _services[i].text.trim();
      final u = _urls[i].text.trim();
      if (s.isNotEmpty && u.isNotEmpty) {
        out.add({"service": s, "url": u});
      }
    }
    return out;
  }

  List<String> _collectGenres() {
    return _genres.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<void> _loadById() async {
    final id = _id.text.trim();
    if (id.isEmpty) {
      _snack('id を入力してください');
      return;
    }
    setState(() => _loading = true);
    try {
      final row = await _supa
          .from('anime_catalog')
          .select('id,title,kana,year,genres,streams')
          .eq('id', id)
          .maybeSingle();

      if (row == null) {
        _snack('未登録。新規作成できます');
        _title.clear();
        _kana.clear();
        _year.clear();
        _genres.clear();
        _clearStreams();
        setState(() {});
        return;
      }

      _title.text = (row['title'] ?? '').toString();
      _kana.text = (row['kana'] ?? '').toString();
      _year.text = row['year']?.toString() ?? '';
      final List<dynamic> g = (row['genres'] ?? []) as List<dynamic>;
      _genres.text = g.map((e) => e.toString()).join(', ');

      _clearStreams();
      final List<dynamic> streams = (row['streams'] ?? []) as List<dynamic>;
      for (var i = 0; i < streams.length; i++) {
        _ensureRow(i);
        final m = Map<String, dynamic>.from(streams[i] as Map);
        _services[i].text = (m['service'] ?? '').toString();
        _urls[i].text = (m['url'] ?? '').toString();
      }
      if (streams.isEmpty) {
        _ensureRow(0);
      }
      setState(() {});
      _snack('読込完了');
    } on PostgrestException catch (e) {
      _snack('読込エラー: ${e.message}');
    } catch (e) {
      _snack('読込エラー: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final id = _id.text.trim();
    final title = _title.text.trim();
    final kana = _kana.text.trim().isEmpty ? null : _kana.text.trim();
    final year = _year.text.trim().isEmpty ? null : int.tryParse(_year.text);
    final genres = _collectGenres();
    final streams = _collectStreams();

    setState(() => _loading = true);
    try {
      // 認証チェック（管理関数は内部で再チェックするが、UX向上のため事前確認）
      final uid = _supa.auth.currentUser?.id;
      if (uid == null) {
        _snack('未ログインです。ログインしてください。');
        return;
      }

      await _supa.rpc('admin_upsert_anime', params: {
        'p_id': id,
        'p_title': title,
        'p_kana': kana,
        'p_year': year,
        'p_genres': genres,
        'p_streams': jsonDecode(jsonEncode(streams)),
      });

      _snack('保存しました');
    } on PostgrestException catch (e) {
      _snack('保存エラー: ${e.message}');
    } catch (e) {
      _snack('保存エラー: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final id = _id.text.trim();
    if (id.isEmpty) {
      _snack('id を入力してください');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('削除確認'),
        content: Text('id="$id" を削除します。よろしいですか？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      final uid = _supa.auth.currentUser?.id;
      if (uid == null) {
        _snack('未ログインです。ログインしてください。');
        return;
      }
      await _supa.rpc('admin_delete_anime', params: {'p_id': id});
      _snack('削除しました');
      _title.clear();
      _kana.clear();
      _year.clear();
      _genres.clear();
      _clearStreams();
      _ensureRow(0);
      setState(() {});
    } on PostgrestException catch (e) {
      _snack('削除エラー: ${e.message}');
    } catch (e) {
      _snack('削除エラー: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );

  @override
  Widget build(BuildContext context) {
    final user = _supa.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin – アニメ管理'),
        actions: [
          if (user == null)
            TextButton(
              onPressed: () async {
                // とりあえず GitHub OAuth を例示（Supabase で有効化しているプロバイダを使って）
                try {
                  await _supa.auth.signInWithOAuth(OAuthProvider.github);
                } catch (e) {
                  _snack('ログイン開始に失敗: $e');
                }
              },
              child: const Text('ログイン', style: TextStyle(color: Colors.white)),
            )
          else
            PopupMenuButton(
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  child: Text('ログアウト (${user.email ?? (user.userMetadata?['name'] as String?) ?? user.id.substring(0, 6)})'),
                  onTap: () async {
                    await _supa.auth.signOut();
                    if (mounted) setState(() {});
                  },
                ),
              ],
            ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _loading,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _id,
                            decoration: const InputDecoration(
                              labelText: 'id（英数字・ハイフン。例: kimetsu-no-yaiba-2019）',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? '必須です' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: _loadById,
                          icon: const Icon(Icons.download),
                          label: const Text('読込'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(labelText: 'title', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? '必須です' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _kana,
                      decoration: const InputDecoration(labelText: 'kana（かな）', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _year,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'year（西暦）', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _genres,
                      decoration: const InputDecoration(
                        labelText: 'genres（カンマ区切り：例「SF, 日常」）',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('streams（service / url）', style: TextStyle(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            _ensureRow(_services.length);
                            setState(() {});
                          },
                          icon: const Icon(Icons.add),
                          tooltip: '行を追加',
                        ),
                        IconButton(
                          onPressed: () {
                            if (_services.isNotEmpty) {
                              _services.removeLast().dispose();
                              _urls.removeLast().dispose();
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.remove),
                          tooltip: '末尾を削除',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _services.length,
                      itemBuilder: (ctx, i) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(children: [
                            Expanded(
                              flex: 2,
                              child: TextField(
                                controller: _services[i],
                                decoration: const InputDecoration(
                                  hintText: 'service（例: Netflix / Prime Video / U-NEXT / dアニメストア / Disney+ / hulu）',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _urls[i],
                                decoration: const InputDecoration(
                                  hintText: 'url（https://...）',
                                  border: OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ]),
                        );
                      },
                    ),
                    if (_services.isEmpty)
                      FilledButton(
                        onPressed: () {
                          _ensureRow(0);
                          setState(() {});
                        },
                        child: const Text('streams を1行追加'),
                      ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: _save,
                          icon: const Icon(Icons.save),
                          label: const Text('保存（upsert）'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _delete,
                          icon: const Icon(Icons.delete),
                          label: const Text('削除'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(minHeight: 3),
              )
          ],
        ),
      ),
    );
  }
}
