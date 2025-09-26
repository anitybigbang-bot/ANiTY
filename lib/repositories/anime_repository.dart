// =====================================
// lib/repositories/anime_repository.dart（完成版）
//  - まずは Googleスプレッドシートを優先して取得
//  - 取得0件/失敗時は Supabase RPC(get_anime_with_ratings)にフォールバック
//  - Supabase側は p_services=null で“全件”→必要なら主要配信に絞り
//  - 500件ずつページング
// =====================================
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/anime.dart';
import '../services/sheet_catalog_service.dart';

class AnimeRepository {
  final _client = Supabase.instance.client;

  /// シートを優先するか（デフォルト true）
  final bool useSheetFirst;

  AnimeRepository({this.useSheetFirst = true});

  void _log(String msg) {
    if (kDebugMode) debugPrint('[AnimeRepository] $msg');
  }

  /// 主要配信のラベル群（※DBの `streams[*].service` と大文字小文字無視で一致）
  static const List<String> majorServices = [
    'Netflix',
    'Prime Video',
    'U-NEXT',
    'hulu',
    'Disney+',
    'dアニメストア',
    'Crunchyroll',
  ];

  /// 作品一覧を取得
  ///
  /// 1) useSheetFirst=true の場合は **シート** から取得を試行
  ///    - 1件以上取れたらそれを返す
  ///    - 0件/例外時は Supabase にフォールバック
  /// 2) Supabase は p_services=null で“全件”取得（確実に表示）し、
  ///    preferMajorOnly=true のときだけ主要配信を試し、少なければ全件に戻す
  Future<List<Anime>> fetchAll({bool preferMajorOnly = false}) async {
    // --- まずはシートを試す ---
    if (useSheetFirst) {
      try {
        _log('fetchAll: try SheetCatalogService.fetch()');
        final rows = await SheetCatalogService.fetch();
        _log('fetchAll: sheet rows = ${rows.length}');
        if (rows.isNotEmpty) {
          final list = rows.map((m) => Anime.fromSupabase(m)).toList();
          _log('fetchAll: return from sheet (${list.length})');
          return list;
        }
      } catch (e) {
        _log('fetchAll: sheet fetch failed -> $e (fallback to Supabase)');
      }
    }

    // --- シートが空/失敗 → Supabase RPC にフォールバック ---
    _log('fetchAll: fallback to Supabase RPC (preferMajorOnly=$preferMajorOnly)');
    if (!preferMajorOnly) {
      final data = await _fetchPaged(pServices: null);
      _log('fetchAll: Supabase ALL = ${data.length}');
      return data;
    }

    // preferMajorOnly=true の場合は 2段構え
    final major = await _fetchPaged(pServices: majorServices);
    _log('fetchAll: Supabase majorOnly = ${major.length}');
    if (major.isEmpty || major.length < 10) {
      _log('fetchAll: major too few -> fallback ALL');
      final all = await _fetchPaged(pServices: null);
      _log('fetchAll: Supabase ALL (fallback) = ${all.length}');
      return all.isNotEmpty ? all : major;
    }
    return major;
  }

  /// RPC `get_anime_with_ratings` をページングで叩く
  Future<List<Anime>> _fetchPaged({List<String>? pServices}) async {
    const batch = 500;
    int offset = 0;
    final out = <Anime>[];

    while (true) {
      final params = <String, dynamic>{
        'p_keyword'   : null,
        'p_year_min'  : null,
        'p_year_max'  : null,
        'p_genres'    : null,
        'p_genre_mode': 'or',
        'p_services'  : pServices, // ← null ならフィルタなし（全件）
        'p_limit'     : batch,
        'p_offset'    : offset,
      };

      final result = await _client.rpc('get_anime_with_ratings', params: params);

      // List<Map<String,dynamic>> に寄せる
      final List<Map<String, dynamic>> rows;
      if (result is List) {
        rows = result.map<Map<String, dynamic>>((e) {
          if (e is Map<String, dynamic>) return e;
          return Map<String, dynamic>.from(e as Map);
        }).toList();
      } else {
        _log('rpc returned non-list: ${result.runtimeType}');
        break;
      }

      if (rows.isEmpty) break;

      out.addAll(rows.map((m) => Anime.fromSupabase(m)));
      if (rows.length < batch) break; // 最終ページ
      offset += batch;
    }

    return out;
  }
}