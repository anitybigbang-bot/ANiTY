
class Anime {
  final String id;
  final String title;
  final List<String> genres;
  final double popularityScore;
  final double nicheScore;

  const Anime({
    required this.id,
    required this.title,
    required this.genres,
    required this.popularityScore,
    required this.nicheScore,
  });
}

enum Mark { watched, watching, wishlist }
