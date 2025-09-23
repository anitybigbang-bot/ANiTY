// lib/lib/get_catalog.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../bootstrap_supabase.dart';
import '../../models/anime.dart';

Future<List<Anime>> fetchCatalog({
  String? keyword,
  int? yearMin,
  int? yearMax,
  List<String>? genres,
  String genreMode = 'or', // 'or' | 'and'
  List<String>? services,
  int limit = 100,
  int offset = 0,
}) async {
  final params = {
    'p_keyword':      keyword,
    'p_year_min':     yearMin,
    'p_year_max':     yearMax,
    'p_genres':       genres,
    'p_genre_mode':   genreMode,
    'p_services':     services,
    'p_limit':        limit,
    'p_offset':       offset,
  }..removeWhere((k, v) => v == null);

  final res = await supabase.rpc('get_anime_with_ratings', params: params);
  final list = (res as List).cast<Map<String, dynamic>>();
  return list.map(Anime.fromJson).toList();
}