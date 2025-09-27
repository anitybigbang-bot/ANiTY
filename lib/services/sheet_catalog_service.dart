// lib/services/sheet_catalog_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';

/// ===============================
/// 公開スプレッドシートの URL 設定
/// ===============================
/// 推奨: CSV エクスポート URL（速くて安定）
/// 例）https://docs.google.com/spreadsheets/d/XXXXX/export?format=csv&gid=0
const String sheetCsvUrl =
    'https://docs.google.com/spreadsheets/d/e/2PACX-1vQDuU5C38ca3OUnRXeJVA70SjrWv-vMUBvc6rkegtIyBH-GKmf7x2JBfm-yGu5hYyAsP82w7eQ9RWcL/pub?output=csv';

/// フォールバック: pubhtml（遅く壊れやすいので最終手段）
/// 例）https://docs.google.com/spreadsheets/d/e/XXXXXXXX/pubhtml
const String sheetHtmlUrl =
    'https://docs.google.com/spreadsheets/d/e/2PACX-1vQDuU5C38ca3OUnRXeJVA70SjrWv-vMUBvc6rkegtIyBH-GKmf7x2JBfm-yGu5hYyAsP82w7eQ9RWcL/pubhtml';

/// 想定ヘッダー（今回のシート構成）:
/// anilist_id, title_native, title_romaji, title_english, year, streams_json
///
/// 返り値は Supabase RPC に近い形の Map 配列:
/// { id, title, kana, year, genres(List<String>), streams(List<Map>),
///   anilist_id, summary, avg_rating:null, rating_count:null, user_rating:null }
class SheetCatalogService {
  /// 一覧取得（CSV → 失敗したら pubhtml をパース）
  static Future<List<Map<String, dynamic>>> fetch() async {
    // 1) まず CSV を試す
    final csv = await _tryFetchCsv(sheetCsvUrl);
    if (csv != null) {
      return _normalizeFromRows(csv);
    }

    // 2) CSV が取れないときは、pubhtml を簡易パース（遅い/壊れやすい → 最終手段）
    final htmlRows = await _tryFetchHtmlTable(sheetHtmlUrl);
    if (htmlRows != null) {
      return _normalizeFromRows(htmlRows);
    }

    throw Exception('シートの取得に失敗しました（CSV も HTML も読めず）');
  }

  // ---------------------------
  // CSV を取得して 2次元配列へ
  // ---------------------------
  static Future<List<List<String>>?> _tryFetchCsv(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return null;

      // 一応 content-type を見て、CSVでなさそうなら null
      final ct = res.headers['content-type'] ?? '';
      if (!ct.contains('text/csv') && !res.body.contains(',')) {
        return null;
      }

      // 文字化け対策で bytes→utf8
      final text = const Utf8Decoder().convert(res.bodyBytes);
      final rows = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(text);

      // すべて String 化
      return rows
          .map((r) => r.map((e) => (e ?? '').toString()).toList())
          .toList()
          .cast<List<String>>();
    } catch (_) {
      return null;
    }
  }

  // ----------------------------------------
  // pubhtml の <table> を超簡易にパースして 2次元配列へ
  // ※ レイアウト変更に弱いので CSV 使えるなら CSV を使って！
  // ----------------------------------------
  static Future<List<List<String>>?> _tryFetchHtmlTable(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) return null;
      final html = const Utf8Decoder().convert(res.bodyBytes);

      // <tr> ... </tr> 単位で拾い、各 <td> をテキスト抽出
      final rowExp = RegExp(r'<tr[^>]*>(.*?)</tr>', caseSensitive: false, dotAll: true);
      final cellExp = RegExp(r'<t[dh][^>]*>(.*?)</t[dh]>', caseSensitive: false, dotAll: true);

      final rows = <List<String>>[];
      for (final m in rowExp.allMatches(html)) {
        final rowHtml = m.group(1) ?? '';
        final cells = <String>[];
        for (final c in cellExp.allMatches(rowHtml)) {
          final raw = c.group(1) ?? '';
          final text = _stripHtml(raw)
              .replaceAll('\u00A0', ' ') // nbsp
              .replaceAll('\n', ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          cells.add(text);
        }
        if (cells.isNotEmpty) rows.add(cells);
      }

      if (rows.isEmpty) return null;
      return rows;
    } catch (_) {
      return null;
    }
  }

  // HTML タグ除去（超簡易）
  static String _stripHtml(String src) =>
      src.replaceAll(RegExp(r'<[^>]*>'), '');

  // ---------------------------
  // 2次元配列 → 正規化 Map 配列
  // ---------------------------
  static List<Map<String, dynamic>> _normalizeFromRows(List<List<String>> rows) {
    if (rows.isEmpty) return [];

    // 1行目はヘッダー
    final headers = rows.first.map((e) => e.trim()).toList();
    final dataRows = rows.skip(1);

    // カラム位置を特定（見出しの大小/全角半角は前提通りで扱う）
    int idxOf(String name) => headers.indexWhere((h) => h == name);

    final iAnilist = idxOf('anilist_id');
    final iNative  = idxOf('title_native');
    final iRomaji  = idxOf('title_romaji');
    final iEnglish = idxOf('title_english');
    final iYear    = idxOf('year');
    final iStreams = idxOf('streams_json');

    final out = <Map<String, dynamic>>[];

    for (final r in dataRows) {
      // 行長に注意して安全に取り出すヘルパ
      String get(int idx) => (idx >= 0 && idx < r.length) ? (r[idx]).trim() : '';

      // ---- 型整形（Anime 相当）----
      final anilistRaw = get(iAnilist);
      if (anilistRaw.isEmpty) continue; // 主キー相当が無ければスキップ

      final id = anilistRaw; // 文字列として流用
      final anilistId = int.tryParse(anilistRaw);

      final title   = get(iRomaji);   // 表示タイトルはローマ字を採用
      final kana    = get(iNative);   // 日本語原題は kana 相当へ
      final summary = get(iEnglish);  // 英語題を summary に補助的に格納

      // year
      int? year;
      final y = get(iYear);
      if (y.isNotEmpty) {
        final n = int.tryParse(y);
        if (n != null) year = n;
      }

      // streams: JSON 配列推奨（例: [{"service":"Netflix","region":"JP"}]）
      dynamic streams = <dynamic>[];
      final streamsStr = get(iStreams);
      if (streamsStr.isNotEmpty) {
        try {
          final decoded = json.decode(streamsStr);
          if (decoded is List) {
            streams = decoded;
          }
        } catch (_) {
          // もし「Netflix,Prime」などのカンマ区切りだったら service 名だけで配列化
          final byComma = streamsStr
              .split(RegExp(r'[,、]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          if (byComma.isNotEmpty) {
            streams = byComma.map((s) => {'service': s}).toList();
          }
        }
      }

      out.add({
        'id': id,
        'title': title,
        'kana': kana,
        'year': year,
        'genres': <String>[],   // このシートには genres が無いので空で運用
        'streams': streams,
        'anilist_id': anilistId,
        'summary': summary,

        // Supabase RPC 互換のダミー列
        'avg_rating': null,
        'rating_count': null,
        'user_rating': null,
      });
    }

    return out;
  }
}