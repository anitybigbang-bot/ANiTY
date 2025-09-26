// =====================================
// lib/services/rating_service.dart（完成版）
// =====================================

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/anime.dart';

/// 未ログイン（匿名含む）時に投げる例外
class AuthRequired implements Exception {
  const AuthRequired([this.message = 'ログインが必要です']);
  final String message;
  @override
  String toString() => message;
}

/// Supabase の User が匿名アカウントかを判定
bool _isAnonymousUser(User? user) {
  if (user == null) return false;

  // appMetadata から判定
  final appMeta = user.appMetadata ?? const <String, dynamic>{};
  if (appMeta['provider'] == 'anonymous') return true;
  if (appMeta['providers'] is List &&
      (appMeta['providers'] as List).contains('anonymous')) {
    return true;
  }

  // SDK によっては isAnonymous プロパティがある
  try {
    final dyn = user as dynamic;
    if (dyn.isAnonymous == true) return true;
  } catch (_) {}

  // userMetadata 側の保険
  final meta = user.userMetadata;
  if (meta != null && meta is Map && meta['is_anonymous'] == true) {
    return true;
  }
  return false;
}

/// 単一ユーザー用の RatingsService
/// - [rate]       星評価を追加/更新/削除
/// - [attachRatings] 一覧に avg/count + 自分の星を合成
abstract class RatingsService {
  Future<List<Anime>> attachRatings(List<Anime> anime);
  Future<Anime> rate(String animeId, int? stars);

  factory RatingsService.mock() => _MockRatingsService();
  factory RatingsService.supabase() => _SupabaseRatingsService();
}

// =========================
// ローカルのみのモック実装
// =========================
class _MockRatingsService implements RatingsService {
  final Map<String, _RatingAgg> _store = {};

  @override
  Future<List<Anime>> attachRatings(List<Anime> anime) async {
    for (final a in anime) {
      final agg = _store[a.id] ??= _RatingAgg();
      agg.reset();
      if (a.userRating != null) {
        agg.setUser(a.userRating);
      }
    }
    return anime.map((a) {
      final agg = _store[a.id]!;
      return a.copyWith(
        avgRating: agg.avg,
        ratingCount: agg.count,
        userRating: agg.user,
      );
    }).toList();
  }

  @override
  Future<Anime> rate(String animeId, int? stars) async {
    final agg = _store[animeId] ??= _RatingAgg();
    agg.setUser(stars);
    return Anime(
      id: animeId,
      title: '',
      genres: const [],
      streams: const [],
      avgRating: agg.avg,
      ratingCount: agg.count,
      userRating: agg.user,
    );
  }
}

class _RatingAgg {
  int count = 0;
  double sum = 0;
  int? user;

  void reset() {
    count = 0;
    sum = 0;
    user = null;
  }

  void setUser(int? newRating) {
    final old = user;

    if (old == null && newRating == null) return;

    if (old == null && newRating != null) {
      user = newRating;
      count += 1;
      sum += newRating;
      return;
    }
    if (old != null && newRating == null) {
      user = null;
      count = (count - 1).clamp(0, 1 << 30);
      sum -= old;
      if (sum < 0) sum = 0;
      return;
    }
    if (old != null && newRating != null) {
      user = newRating;
      sum += (newRating - old);
      if (sum < 0) sum = 0;
      return;
    }
  }

  double get avg => count == 0 ? 0 : (sum / count);
}

// =============================
// Supabase 連携実装
// =============================
class _SupabaseRatingsService implements RatingsService {
  static const _kLocalRatedPrefix = 'rated:'; // SharedPreferences キー
  SupabaseClient get _sb => Supabase.instance.client;

  // ---- ローカル星の読み書き ----
  Future<int?> _getLocalRating(String animeId) async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt('$_kLocalRatedPrefix$animeId');
  }

  Future<void> _setLocalRating(String animeId, int? rating) async {
    final sp = await SharedPreferences.getInstance();
    final key = '$_kLocalRatedPrefix$animeId';
    if (rating == null) {
      await sp.remove(key);
    } else {
      await sp.setInt(key, rating);
    }
  }

  // ---- 一覧に avg/count と自分の星 を合成 ----
  @override
  Future<List<Anime>> attachRatings(List<Anime> anime) async {
    if (anime.isEmpty) return anime;

    try {
      final ids = anime.map((a) => a.id).toList();

      final rows = await _sb
          .from('rating_aggregates')
          .select('anime_id, avg_rating, rating_count')
          .inFilter('anime_id', ids);

      final Map<String, (double?, int?)> byId = {
        for (final r in (rows as List))
          (r['anime_id'] as String): (
            (r['avg_rating'] as num?)?.toDouble(),
            (r['rating_count'] as num?)?.toInt(),
          )
      };

      final sp = await SharedPreferences.getInstance();

      return anime.map((a) {
        final t = byId[a.id];
        final avg = t?.$1 ?? a.avgRating;
        final cnt = t?.$2 ?? a.ratingCount;
        final my = sp.getInt('$_kLocalRatedPrefix${a.id}') ?? a.userRating;
        return a.copyWith(
          avgRating: avg,
          ratingCount: cnt,
          userRating: my,
        );
      }).toList();
    } catch (_) {
      // 失敗時はローカル星だけ反映
      final sp = await SharedPreferences.getInstance();
      return anime.map((a) {
        final my = sp.getInt('$_kLocalRatedPrefix${a.id}') ?? a.userRating;
        return a.copyWith(userRating: my);
      }).toList();
    }
  }

  // ---- 評価（追加/更新/削除） ----
  @override
  Future<Anime> rate(String animeId, int? stars) async {
    // 認証チェック（未ログイン or 匿名はログイン誘導）
    final user = _sb.auth.currentUser;
    if (user == null || _isAnonymousUser(user)) {
      throw const AuthRequired();
    }

    // 1) まずローカル更新（UI 即時反映）
    await _setLocalRating(animeId, stars);

    try {
      // 2) Supabase RPC へ送信
      await _sb.rpc('upsert_rating', params: {
        'p_anime_id': animeId,
        'p_rating': stars,
      });

      // 3) 最新の集計を読み直し
      final rows = await _sb
          .from('rating_aggregates')
          .select('avg_rating, rating_count')
          .eq('anime_id', animeId);

      double? avg;
      int? cnt;
      if (rows is List && rows.isNotEmpty) {
        final r = rows.first as Map<String, dynamic>;
        avg = (r['avg_rating'] as num?)?.toDouble();
        cnt = (r['rating_count'] as num?)?.toInt();
      }

      return Anime(
        id: animeId,
        title: '',
        genres: const [],
        streams: const [],
        avgRating: avg,
        ratingCount: cnt,
        userRating: stars,
      );
    } catch (_) {
      // 失敗時はローカル星のみ返す
      final my = await _getLocalRating(animeId);
      return Anime(
        id: animeId,
        title: '',
        genres: const [],
        streams: const [],
        avgRating: null,
        ratingCount: null,
        userRating: my,
      );
    }
  }
}