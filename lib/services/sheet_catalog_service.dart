// lib/services/sheet_catalog_service.dart
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:convert' as convert;

/// === 公開シートの CSV URL を入れてください =======================
/// 例) https://docs.google.com/spreadsheets/d/e/.../pub?output=csv
const String sheetCsvUrl =
    'https://docs.google.com/spreadsheets/d/e/xxxxxxx/pub?output=csv';

/// 任意（フォールバック用）。未使用ならそのままでOK
const String sheetHtmlUrl = '';

class SheetCatalogService {
  /// CSV → 正規化 Map<List> を返す
  static Future<List<Map<String, dynamic>>> fetch() async {
    final rows = await _tryFetchCsv(sheetCsvUrl);
    if (rows == null || rows.isEmpty) {
      throw Exception('シートのCSVが取得できませんでした。URL/公開設定を確認してください。');
    }
    return _normalizeFromRows(rows);
  }

  /// CSV を 2次元配列に
  static Future<List<List<String>>?> _tryFetchCsv(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) return null;

    final text = const Utf8Decoder().convert(res.bodyBytes);
    final rows = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(text);

    return rows
        .map((r) => r.map((e) => (e ?? '').toString()).toList())
        .toList()
        .cast<List<String>>();
  }

  /// 2次元配列 → ANiTYの内部形式に正規化
  ///
  /// 期待最小ヘッダー: anilist_id, title_native, title_english, year, streams_json
  /// なくても良い: title, kana, genres, summary など（存在すれば使う）
  static List<Map<String, dynamic>> _normalizeFromRows(List<List<String>> rows) {
    if (rows.isEmpty) return [];
    final headers = rows.first.map((e) => e.trim()).toList();
    final dataRows = rows.skip(1);

    // ヘッダーのインデックス取得（無ければ -1）
    int idx(String name) => headers.indexWhere((h) => h == name);

    final iAnilist   = idx('anilist_id');
    final iTitleNat  = idx('title_native');
    final iTitleEng  = idx('title_english');
    final iYear      = idx('year');
    final iStreams   = idx('streams_json');

    // 任意項目（存在すれば利用）
    final iTitle     = idx('title');
    final iKana      = idx('kana');
    final iGenres    = idx('genres');
    final iSummary   = idx('summary');

    final out = <Map<String, dynamic>>[];

    for (final r in dataRows) {
      // 取り出しヘルパ
      String at(int i) => (i >= 0 && i < r.length) ? r[i].trim() : '';

      // タイトル決定（優先順: title_native > title_english > title）
      final titleNative  = at(iTitleNat);
      final titleEnglish = at(iTitleEng);
      final titleAny     = at(iTitle);
      final title = (titleNative.isNotEmpty
              ? titleNative
              : (titleEnglish.isNotEmpty ? titleEnglish : titleAny))
          .trim();

      // 年
      int? year;
      final y = at(iYear);
      if (y.isNotEmpty) {
        final n = int.tryParse(y);
        if (n != null) year = n;
      }

      // anilist_id
      int? anilistId;
      final aid = at(iAnilist);
      if (aid.isNotEmpty) {
        final n = int.tryParse(aid);
        if (n != null) anilistId = n;
      }

      // ID: anilist_id > (title + year のハッシュ)
      String id;
      if (anilistId != null) {
        id = 'anilist:$anilistId';
      } else {
        final base = '${title}|${year ?? ''}';
        id = 'sheet:${md5.convert(convert.utf8.encode(base)).toString()}';
      }

      // streams_json（JSON推奨）→ List<Map> へ
      List<dynamic> streams = const [];
      final streamsJson = at(iStreams);
      if (streamsJson.isNotEmpty) {
        try {
          final decoded = json.decode(streamsJson);
          if (decoded is List) streams = decoded;
        } catch (_) {
          // カンマ区切り "Netflix,Prime Video" などに緊急対応
          final byComma = streamsJson
              .split(RegExp(r'[,、]'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
          if (byComma.isNotEmpty) {
            streams = byComma.map((s) => {'service': s}).toList();
          }
        }
      }

      // 任意: kana / genres / summary
      final kana = at(iKana);
      final genresStr = at(iGenres);
      final genres = genresStr.isEmpty
          ? <String>[]
          : genresStr
              .split(RegExp(r'[,、]\s*|\s+'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
      final summary = at(iSummary);

      // 最低限、タイトルが無い行はスキップ
      if (title.isEmpty) continue;

      out.add({
        'id': id,
        'title': title,
        'kana': kana.isEmpty ? null : kana,
        'year': year,
        'genres': genres,
        'streams': streams,          // List<Map> or []
        'anilist_id': anilistId,
        'summary': summary.isEmpty ? null : summary,
        // Supabase RPC 互換のダミー列
        'avg_rating': null,
        'rating_count': null,
        'user_rating': null,
      });
    }

    return out;
    }
}