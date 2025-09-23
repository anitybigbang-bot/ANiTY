// =====================================
// lib/models/anime.dart
// =====================================

/// 配信リンク1件（streamsの要素）
class StreamLink {
  final String service; // Netflix, Prime Video など
  final String url;

  const StreamLink({required this.service, required this.url});

  factory StreamLink.fromJson(Map<String, dynamic> j) => StreamLink(
        service: (j['service'] ?? '').toString(),
        url: (j['url'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {'service': service, 'url': url};

  @override
  String toString() => 'StreamLink(service: $service, url: $url)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StreamLink &&
          runtimeType == other.runtimeType &&
          service == other.service &&
          url == other.url;

  @override
  int get hashCode => Object.hash(service, url);
}

/// 作品モデル（Supabase RPC `get_anime_with_ratings` の1行に対応）
class Anime {
  final String id;
  final String title;
  final String? kana;
  final int? year;
  final List<String> genres;
  final String? summary;            // 旧 undefined_getter 対策で任意
  final List<StreamLink> streams;   // jsonb: [{service,url}]

  // 集計/個人評価（rating_totals + my_ratings 結合結果）
  final double? avgRating;          // avg_rating
  final int? ratingCount;           // rating_count
  final int? userRating;            // user_rating (1..5)

  const Anime({
    required this.id,
    required this.title,
    this.kana,
    this.year,
    required this.genres,
    this.summary,
    required this.streams,
    this.avgRating,
    this.ratingCount,
    this.userRating,
  });

  /// Supabaseの戻り(Map)→Anime（カラム名のスネーク/キャメル混在に耐性あり）
  factory Anime.fromSupabase(Map<String, dynamic> m) => Anime.fromJson(m);

  /// キャメル/スネーク両対応 + 型安全に変換
  static Anime fromJson(Map<String, dynamic> j) {
    // streams: jsonb array -> List<StreamLink>
    final streamsRaw = (j['streams'] is List) ? j['streams'] as List : const [];
    final streams = streamsRaw
        .map((e) => StreamLink.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    // genres: text[] -> List<String>
    final genresRaw = (j['genres'] is List) ? j['genres'] as List : const [];
    final genres = genresRaw.map((e) => e.toString()).toList();

    // 平均評価: num? -> double?
    final avgRaw = j['avg_rating'] ?? j['avgRating'];
    final double? avg =
        (avgRaw == null) ? null : (avgRaw as num).toDouble();

    // 件数: dynamic -> int?
    final cntRaw = j['rating_count'] ?? j['ratingCount'];
    final int? ratingCnt = (cntRaw is int)
        ? cntRaw
        : (cntRaw is num)
            ? cntRaw.toInt()
            : null;

    // 自分の評価: dynamic -> int?
    final urRaw = j['user_rating'] ?? j['userRating'];
    final int? userRating =
        (urRaw is int) ? urRaw : (urRaw is num) ? urRaw.toInt() : null;

    return Anime(
      id: (j['id'] ?? '').toString(),
      title: (j['title'] ?? '').toString(),
      kana: j['kana'] as String?,
      year: (j['year'] is int)
          ? j['year'] as int
          : (j['year'] is num)
              ? (j['year'] as num).toInt()
              : null,
      genres: genres,
      summary: j['summary'] as String?,
      streams: streams,
      avgRating: avg,
      ratingCount: ratingCnt,
      userRating: userRating,
    );
  }

  /// JSON化（アプリ内保持やテスト用）
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'kana': kana,
        'year': year,
        'genres': genres,
        'summary': summary,
        'streams': streams.map((e) => e.toJson()).toList(),
        'avg_rating': avgRating,
        'rating_count': ratingCount,
        'user_rating': userRating,
      };

  /// リスト変換
  static List<Anime> listFromJson(List<dynamic> arr) =>
      arr.map((e) => Anime.fromJson(Map<String, dynamic>.from(e))).toList();

  /// 一部だけ更新した新インスタンスを返す
  Anime copyWith({
    String? title,
    String? kana,
    int? year,
    List<String>? genres,
    String? summary,
    List<StreamLink>? streams,
    double? avgRating,
    int? ratingCount,
    int? userRating,
  }) =>
      Anime(
        id: id,
        title: title ?? this.title,
        kana: kana ?? this.kana,
        year: year ?? this.year,
        genres: genres ?? this.genres,
        summary: summary ?? this.summary,
        streams: streams ?? this.streams,
        avgRating: avgRating ?? this.avgRating,
        ratingCount: ratingCount ?? this.ratingCount,
        userRating: userRating ?? this.userRating,
      );

  /// 便利: 配信サービス名一覧
  List<String> get streamServices =>
      streams.map((s) => s.service).where((s) => s.isNotEmpty).toList();

  /// 便利: 指定サービスのURL（最初の1件）
  String? urlForService(String serviceNameLower) {
    final m = streams.firstWhere(
      (s) => s.service.toLowerCase() == serviceNameLower.toLowerCase(),
      orElse: () => const StreamLink(service: '', url: ''),
    );
    return m.url.isEmpty ? null : m.url;
  }

  @override
  String toString() =>
      'Anime(id: $id, title: $title, year: $year, avg: $avgRating, cnt: $ratingCount, me: $userRating)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Anime &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          title == other.title &&
          kana == other.kana &&
          year == other.year &&
          _listEq(genres, other.genres) &&
          summary == other.summary &&
          _listEq(streams, other.streams) &&
          avgRating == other.avgRating &&
          ratingCount == other.ratingCount &&
          userRating == other.userRating;

  @override
  int get hashCode => Object.hash(
        id,
        title,
        kana,
        year,
        Object.hashAll(genres),
        summary,
        Object.hashAll(streams),
        avgRating,
        ratingCount,
        userRating,
      );

  static bool _listEq<T>(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}