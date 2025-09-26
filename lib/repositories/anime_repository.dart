// =====================================
// lib/repositories/anime_repository.dart（完成版）
//  - まずは p_services=null で “全部” 取る（確実に表示するため）
//  - 主要配信フィルタで 0 件/極端に少ない場合は自動で全件にフォールバック
//  - 500件ずつページング
// =====================================
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/anime.dart';

class AnimeRepository {
  final _client = Supabase.instance.client;

  /// デバッグログ
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

  /// 作品を“全件”取得（ページング）
  ///
  /// - まずは **p_services = null** で（サーバー側で配信フィルタを掛けない）
  ///   - これで UI に最低限「全部」表示できるようにする
  /// - もし「主要配信のみ」にしたくなったら、`preferMajorOnly: true` を渡す
  ///   - ただし結果が 0 件 or 極端に少なければ **自動で全件にフォールバック**
  Future<List<Anime>> fetchAll({bool preferMajorOnly = false}) async {
    _log('fetchAll(preferMajorOnly=$preferMajorOnly) start');

    // まずは “安全に” 全件
    if (!preferMajorOnly) {
      final data = await _fetchPaged(pServices: null);
      _log('fetchAll: got ${data.length} rows (no service filter)');
      return data;
    }

    // preferMajorOnly=true の場合は 2 段構え
    final major = await _fetchPaged(pServices: majorServices);
    _log('fetchAll: majorServices first try => ${major.length} rows');

    // 「0件」「極端に少ない」なら “全件” でフォールバック
    if (major.isEmpty || major.length < 10) {
      _log('fetchAll: fallback to ALL (major too few)');
      final all = await _fetchPaged(pServices: null);
      _log('fetchAll: fallback got ${all.length} rows');
      // それでも0ならそのまま返す
      return all.isNotEmpty ? all : major;
    }

    return major;
  }

  /// RPC `get_anime_with_ratings` をページングで叩く
  Future<List<Anime>> _fetchPaged({List<String>? pServices}) async {
    const batch = 500;
    int offset = 0;
    final all = <Anime>[];

    while (true) {
      final params = <String, dynamic>{
        'p_keyword'   : null,
        'p_year_min'  : null,
        'p_year_max'  : null,
        'p_genres'    : null,
        'p_genre_mode': 'or',
        'p_services'  : pServices, // ← null ならフィルタなし
        'p_limit'     : batch,
        'p_offset'    : offset,
      };

      // supabase_dart v2系は rpc().select() の形もあるが、ANiTY環境では
      // すでに List が返る実装で動いていたため、ここではそれに合わせる。
      final result = await _client.rpc('get_anime_with_ratings', params: params);

      // 返ってきた型を堅牢に List<Map<String,dynamic>> へ
      final List<Map<String, dynamic>> rows;
      if (result is List) {
        rows = result.map<Map<String, dynamic>>((e) {
          if (e is Map<String, dynamic>) return e;
          return Map<String, dynamic>.from(e as Map);
        }).toList();
      } else {
        // 万一 Map で返った場合などの保険（空にする）
        _log('rpc returned non-list: ${result.runtimeType}');
        rows = const [];
      }

      if (rows.isEmpty) break;

      all.addAll(rows.map((m) => Anime.fromSupabase(m)));
      if (rows.length < batch) break; // 最終ページ
      offset += batch;
    }

    return all;
  }
}