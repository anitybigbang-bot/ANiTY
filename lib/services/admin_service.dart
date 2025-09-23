// lib/services/admin_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> adminUpsert({
  required String id,
  required String title,
  String? kana,
  int? year,
  List<String> genres = const [],
  List<Map<String, String>> streams = const [],
}) async {
  await Supabase.instance.client.rpc('admin_upsert_anime', params: {
    'p_id': id,
    'p_title': title,
    'p_kana': kana,
    'p_year': year,
    'p_genres': genres,
    'p_streams': streams,
  });
}

Future<void> adminDelete(String id) async {
  await Supabase.instance.client.rpc('admin_delete_anime', params: {
    'p_id': id,
  });
}