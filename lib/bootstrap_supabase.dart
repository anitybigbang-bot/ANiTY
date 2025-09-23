// lib/bootstrap_supabase.dart
import 'package:supabase_flutter/supabase_flutter.dart';

late final SupabaseClient supabase;

/// Supabase 初期化
Future<void> initSupabase({
  required String url,
  required String anonKey,
}) async {
  await Supabase.initialize(
    url: url,
    anonKey: anonKey,
  );
  supabase = Supabase.instance.client;
}