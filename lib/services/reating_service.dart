import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ローカルと Supabase を橋渡しするレーティングサービス
class RatingService {
  static const _kLocalRatedPrefix = 'rated:'; // 'rated:anime_id' -> 1..5
  static const _kLocalWatched = 'watched'; // Set<String> (anime_id)

  final SupabaseClient? _sb;

  RatingService([SupabaseClient? client]) : _sb = client;

  Future<int?> getLocalRating(String animeId) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt('$_kLocalRatedPrefix$animeId');
  }

  Future<Set<String>> getWatched() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getStringList(_kLocalWatched)?.toSet() ?? <String>{};
  }

  Future<void> setRating(String animeId, int rating) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('$_kLocalRatedPrefix$animeId', rating);

    // 星が付いたら視聴済みに自動チェック
    final w = await getWatched();
    if (rating >= 1) {
      w.add(animeId);
      await sp.setStringList(_kLocalWatched, w.toList());
    }

    // Supabase RPC 呼び出し（設定済みなら）
    if (_sb != null) {
      try {
        await _sb!.rpc('upsert_rating', params: {
          'p_anime_id': animeId,
          'p_rating': rating,
        });
      } catch (_) {
        // ネットワーク/認可の失敗は握りつぶし（オフラインでもUI継続）
      }
    }
  }

  Future<void> toggleWatched(String animeId, bool watched) async {
    final sp = await SharedPreferences.getInstance();
    final w = await getWatched();
    if (watched) {
      w.add(animeId);
    } else {
      w.remove(animeId);
    }
    await sp.setStringList(_kLocalWatched, w.toList());
  }
}