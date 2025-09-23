// lib/lib/ratings.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bootstrap_supabase.dart';

Future<void> saveRating({
  required String animeId,
  required int rating, // 1..5
}) async {
  await supabase.rpc('upsert_rating', params: {
    'p_anime_id': animeId,
    'p_rating': rating,
  });
}

// 削除（NULL 指定）
Future<void> deleteRating(String animeId) async {
  await supabase.rpc('upsert_rating', params: {
    'p_anime_id': animeId,
    'p_rating': null,
  });
}