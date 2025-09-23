// anime_loder.dart
// ※ファイル名が loder になっているならそのままでOK。改名するなら import 影響に注意。
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

/// モデル（必要に応じてあなたの既存モデルに合わせて型名やフィールド名を合わせてください）
class Anime {
  final String id;
  final String title;
  final String? kana;
  final int? year;
  final List<String> genres;
  final List<dynamic> streams; // [{service,url}] の JSONB をそのまま
  final double? avgRating;
  final int? ratingCount;
  final int? userRating;

  Anime({
    required this.id,
    required this.title,
    this.kana,
    this.year,
    required this.genres,
    required this.streams,
    this.avgRating,
    this.ratingCount,
    this.userRating,
  });

  factory Anime.fromMap(Map<String, dynamic> m) {
    return Anime(
      id: m['id'] as String,
      title: m['title'] as String,
      kana: m['kana'] as String?,
      year: m['year'] as int?,
      genres: (m['genres'] as List?)?.cast<String>() ?? const [],
      streams: (m['streams'] as List?) ?? const [],
      avgRating: (m['avg_rating'] as num?)?.toDouble(),
      ratingCount: m['rating_count'] as int?,
      userRating: m['user_rating'] as int?,
    );
  }
}

/// 一覧取得：必要ならフィルタを渡してください（null はサーバ側で無視されます）
class AnimeRepository {
  Future<List<Anime>> fetch({
    String? keyword,
    int? yearMin,
    int? yearMax,
    List<String>? genres,
    String genreMode = 'or', // 'or' | 'and'
    List<String>? services,
    int limit = 500,
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
    };

    final res = await supabase.rpc(
      'get_anime_with_ratings',
      params: params,
    );

    // res は List<dynamic>（Map の配列）で返る想定
    final list = (res as List)
        .cast<Map<String, dynamic>>()
        .map(Anime.fromMap)
        .toList();

    return list;
  }

  /// 評価の登録/更新（削除は rating を null）
  Future<void> upsertRating({
    required String animeId,
    int? rating, // 1..5 / null で削除
  }) {
    return supabase.rpc('upsert_rating', params: {
      'p_anime_id': animeId,
      'p_rating': rating,
    });
  }
}