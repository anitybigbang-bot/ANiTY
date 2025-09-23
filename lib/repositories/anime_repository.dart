// =====================================
// lib/repositories/anime_repository.dart
// =====================================
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/anime.dart';

class AnimeRepository {
  final _client = Supabase.instance.client;

  /// 主要ストリーミングあり作品のみを“全件”取得（500件ずつページング）
  Future<List<Anime>> fetchAll() async {
    const batch = 500;
    int offset = 0;
    final all = <Anime>[];

    // フィルタ：主要配信が1つでもあるものだけ
    final services = [
      'Netflix',
      'Prime Video',
      'hulu',
      'U-NEXT',
      'dアニメストア',
      'Disney+',
    ];

    while (true) {
      final result = await _client.rpc('get_anime_with_ratings', params: {
        'p_keyword'   : null,
        'p_year_min'  : null,
        'p_year_max'  : null,
        'p_genres'    : null,
        'p_genre_mode': 'or',
        'p_services'  : ['Netflix','Prime Video','U-NEXT','hulu','Disney+','dアニメストア','Crunchyroll'],
        'p_limit'     : batch,
        'p_offset'    : offset,
      });

      final rows = (result as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) break;

      all.addAll(rows.map((m) => Anime.fromSupabase(m)));
      if (rows.length < batch) break; // 最後のページ
      offset += batch;
    }

    return all;
  }
}