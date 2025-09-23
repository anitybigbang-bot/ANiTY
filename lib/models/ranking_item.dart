class RankingItem {
  final String animeId;
  final double avgRating;
  final int ratingCount;
  final double bayesScore;

  RankingItem({
    required this.animeId,
    required this.avgRating,
    required this.ratingCount,
    required this.bayesScore,
  });

  factory RankingItem.fromMap(Map<String, dynamic> m) => RankingItem(
        animeId: m['anime_id'] as String,
        avgRating: (m['avg_rating'] as num).toDouble(),
        ratingCount: (m['rating_count'] as num).toInt(),
        bayesScore: (m['bayes_score'] as num).toDouble(),
      );
}