import '../pages/anime_list_page.dart' show RankFilter;

class FilterPreset {
  final String name;
  final String keyword;
  final List<String> genres;
  final double starMin;
  final double starMax;
  final String? service;
  final RankFilter? rank; // Gold/Silver（null なら all 扱い）

  FilterPreset({
    required this.name,
    required this.keyword,
    required this.genres,
    required this.starMin,
    required this.starMax,
    required this.service,
    this.rank,
  });

  FilterPreset copyWith({String? name}) => FilterPreset(
        name: name ?? this.name,
        keyword: keyword,
        genres: genres,
        starMin: starMin,
        starMax: starMax,
        service: service,
        rank: rank,
      );

  /// 旧形式: name||keyword||genres||starMin||starMax||service||tier
  ///   tier: "all"|"major"|"submajor"
  /// 新形式: 末尾 "rank": "all"|"gold"|"silver"（旧互換で解釈）
  factory FilterPreset.fromJsonString(String s) {
    final parts = s.split('||');
    String? tail = parts.length >= 7 ? parts[6] : null;

    RankFilter? rf;
    switch (tail) {
      case 'gold':
      case 'major': // 旧互換
        rf = RankFilter.gold;
        break;
      case 'silver':
      case 'submajor': // 旧互換
        rf = RankFilter.silver;
        break;
      case 'all':
      default:
        rf = null; // null = all
    }
    return FilterPreset(
      name: parts[0],
      keyword: parts.length > 1 ? parts[1] : '',
      genres: parts.length > 2 && parts[2].isNotEmpty ? parts[2].split(',') : [],
      starMin: parts.length > 3 ? (double.tryParse(parts[3]) ?? 0) : 0,
      starMax: parts.length > 4 ? (double.tryParse(parts[4]) ?? 5) : 5,
      service: parts.length > 5 && parts[5].isNotEmpty ? parts[5] : null,
      rank: rf,
    );
  }

  String toJsonString() {
    final t = switch (rank) {
      RankFilter.gold => 'gold',
      RankFilter.silver => 'silver',
      RankFilter.all || null => 'all',
    };
    return [
      name,
      keyword,
      genres.join(','),
      starMin.toString(),
      starMax.toString(),
      service ?? '',
      t,
    ].join('||');
  }
}