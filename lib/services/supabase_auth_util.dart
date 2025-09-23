import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabaseの匿名ユーザーを検出して true を返す
bool isAnonymousUser(User? user) {
  if (user == null) return false;

  // GoTrueの標準プロバイダ判定
  final provider = user.appMetadata['provider'];
  if (provider == 'anonymous') return true;

  // 一部SDKが isAnonymous を持つ場合に備えてゆるく参照
  try {
    final dyn = user as dynamic;
    if (dyn.isAnonymous == true) return true;
  } catch (_) {}

  // user_metadata 側のフラグも一応確認
  final meta = user.userMetadata;
  if (meta is Map && (meta?['is_anonymous'] == true)) return true;

  return false;
}