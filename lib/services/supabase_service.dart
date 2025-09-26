// =====================================
// lib/services/supabase_service.dart
// =====================================
import 'dart:developer' as dev;
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

/// アニメ一覧を取得（get_anime_with_ratings RPC）
/// SQL 定義:
///   get_anime_with_ratings(
///     p_keyword text,
///     p_year_min int,
///     p_year_max int,
///     p_genres text[],
///     p_genre_mode text,   -- 'or' | 'and'
///     p_services text[],
///     p_limit int,
///     p_offset int
///   )
Future<List<Map<String, dynamic>>> fetchCatalog({
  String? keyword,
  int? yearMin,
  int? yearMax,
  List<String>? genres,
  String genreMode = 'or',
  List<String>? services,
  int limit = 50,
  int offset = 0,
}) async {
  final params = <String, dynamic>{
    'p_keyword': keyword,
    'p_year_min': yearMin,
    'p_year_max': yearMax,
    'p_genres': genres,
    'p_genre_mode': genreMode,
    'p_services': services,
    'p_limit': limit,
    'p_offset': offset,
  }..removeWhere((_, v) => v == null);

  final res = await supabase.rpc('get_anime_with_ratings', params: params);
  if (res is List) {
    return res.cast<Map<String, dynamic>>();
  } else {
    throw Exception('RPC get_anime_with_ratings failed: $res');
  }
}

/// 件数サマリーを取得（count_filtered_anime RPC）
/*
  想定RPCのシグネチャ（例）:
    count_filtered_anime(
      q text,
      year_min int,
      year_max int,
      genres text[],
      services text[],
      genre_mode text
    ) returns jsonb like:
      { "total_count": 123, "watched_count": 45 }

  ※ まだ作っていない環境でも落ちないようにフォールバックあり
*/
Future<(int total, int watched)> fetchCounts({
  String? keyword,
  int? yearMin,
  int? yearMax,
  List<String>? genres,
  List<String>? services,
  String genreMode = 'or',
}) async {
  final params = <String, dynamic>{
    'q': keyword,
    'year_min': yearMin,
    'year_max': yearMax,
    'genres': (genres == null || genres.isEmpty) ? null : genres,
    'services': (services == null || services.isEmpty) ? null : services,
    'genre_mode': genreMode,
  }..removeWhere((_, v) => v == null);

  try {
    final res = await supabase.rpc('count_filtered_anime', params: params);
    if (res is Map<String, dynamic>) {
      final total = (res['total_count'] ?? 0) as int;
      final watched = (res['watched_count'] ?? 0) as int;
      return (total, watched);
    } else {
      throw Exception('RPC count_filtered_anime returned non-map: $res');
    }
  } catch (e, st) {
    // フォールバック：RPCが未実装/権限なし等でもUIを止めない
    dev.log('count_filtered_anime RPC failed, fallback to client count: $e',
        name: 'supabase_service', stackTrace: st);

    // ざっくり件数だけクライアント側で（watched は 0 とする）
    final list = await fetchCatalog(
      keyword: keyword,
      yearMin: yearMin,
      yearMax: yearMax,
      genres: genres,
      genreMode: genreMode,
      services: services,
      limit: 5000, // 上限広め（必要に応じて調整）
      offset: 0,
    );
    return (list.length, 0);
  }
}

/// 投票（1ユーザー＝1票/作品×サービス×地域）
/// SQL: vote_streaming(p_anime_id text, p_service text, p_region text,
///                    p_available boolean, p_source_url text, p_note text)
Future<void> voteStreaming({
  required String animeId,
  required String service,
  required String region, // 例: "JP"
  required bool available,
  String? sourceUrl,
  String? note,
}) async {
  final params = <String, dynamic>{
    'p_anime_id': animeId,
    'p_service': service,
    'p_region': region,
    'p_available': available,
    'p_source_url': sourceUrl,
    'p_note': note,
  }..removeWhere((_, v) => v == null);

  await supabase.rpc('vote_streaming', params: params);
}

/// 集計取得（confidence でしきい値）
/// SQL: get_streaming_consensus(p_anime_id text, p_service text,
///                             p_region text, p_min_conf float8)
Future<List<Map<String, dynamic>>> fetchStreamingConsensus({
  required String animeId,
  String? service,  // 例: 'Netflix'（小文字化はサーバ側で対応済み）
  String? region,   // 例: 'JP'（大文字化はサーバ側で対応済み）
  double minConfidence = 0.6,
}) async {
  final res = await supabase.rpc('get_streaming_consensus', params: {
    'p_anime_id': animeId,
    'p_service': service,
    'p_region': region,
    'p_min_conf': minConfidence,
  });
  if (res is List) {
    return res.cast<Map<String, dynamic>>();
  }
  throw Exception('RPC get_streaming_consensus failed: $res');
}