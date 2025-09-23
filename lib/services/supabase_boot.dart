import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase を初期化して、未ログインなら匿名ログインまで済ませる。
Future<void> initSupabase({
  required String supabaseUrl,
  required String supabaseAnonKey,
}) async {
  // 1) initialize
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // 2) ensure anonymous session
  final auth = Supabase.instance.client.auth;
  if (auth.currentSession == null) {
    await auth.signInAnonymously();
  }
}