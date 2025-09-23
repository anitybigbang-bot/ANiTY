import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

/// アニメ一覧を取得（get_anime_with_ratings RPC）
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
  final params = {
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
/// total = 該当件数, watched = その中で視聴済み件数
Future<(int total, int watched)> fetchCounts({
  String? keyword,
  int? yearMin,
  int? yearMax,
  List<String>? genres,
  List<String>? services,
  String genreMode = 'or',
}) async {
  final params = {
    'q': keyword,
    'year_min': yearMin,
    'year_max': yearMax,
    'genres': (genres == null || genres.isEmpty) ? null : genres,
    'services': (services == null || services.isEmpty) ? null : services,
    'genre_mode': genreMode,
  }..removeWhere((_, v) => v == null);

  final res = await supabase.rpc('count_filtered_anime', params: params);
  if (res is Map<String, dynamic>) {
    final total = (res['total_count'] ?? 0) as int;
    final watched = (res['watched_count'] ?? 0) as int;
    return (total, watched);
  } else {
    throw Exception('RPC count_filtered_anime failed: $res');
  }
}

/// 投票（1ユーザー＝1票/作品×サービス×地域）
Future<void> voteStreaming({
  required String animeId,
  required String service,
  required String region, // "JP" 推奨
  required bool available,
  String? sourceUrl,
  String? note,
}) async {
  final params = {
    'p_anime_id': animeId,
    'p_service': service,
    'p_region': region,
    'p_available': available,
    'p_source_url': sourceUrl,
    'p_note': note,
  }..removeWhere((_, v) => v == null);
  await supabase.rpc('vote_streaming', params: params);
}

/// 集計取得（confidenceでしきい値）
Future<List<Map<String, dynamic>>> fetchStreamingConsensus({
  required String animeId,
  String? service,  // 例: 'Netflix'
  String? region,   // 例: 'JP'
  double minConfidence = 0.6, // 例: 0.6
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