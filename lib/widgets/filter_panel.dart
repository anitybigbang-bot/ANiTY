import 'package:flutter/material.dart';
import '../core/constants.dart';
import '../pages/anime_list_page.dart';

class FilterPanel extends StatelessWidget {
  const FilterPanel({
    super.key,
    // 入力
    required this.genreFilter,
    required this.genreMode,
    required this.serviceFilters,
    required this.rankFilter,
    required this.watchedFilter,
    required this.starMin,
    required this.starMax,
    required this.yearMin,
    required this.yearMax,
    // コールバック
    required this.onChangeGenreMode,
    required this.onToggleGenre,
    required this.onClearGenres,
    required this.onToggleService,
    required this.onClearServices,
    required this.onSetYearRange,
    required this.onClearYearRange,
    required this.onSetStarRange,
    required this.onResetStarRange,
    required this.onChangeRank,
    required this.onChangeWatched,
  });

  // 入力値（現在の状態）
  final Set<String> genreFilter;
  final GenreFilterMode genreMode;
  final Set<String> serviceFilters;
  final RankFilter rankFilter;
  final WatchedFilter watchedFilter;
  final double starMin;
  final double starMax;
  final int? yearMin;
  final int? yearMax;

  // 更新系
  final void Function(GenreFilterMode) onChangeGenreMode;
  final void Function(String genre, bool selected) onToggleGenre;
  final VoidCallback onClearGenres;

  final void Function(String service, bool selected) onToggleService;
  final VoidCallback onClearServices;

  final void Function(int? minYear, int? maxYear) onSetYearRange;
  final VoidCallback onClearYearRange;

  final void Function(double min, double max) onSetStarRange;
  final VoidCallback onResetStarRange;

  final void Function(RankFilter) onChangeRank;
  final void Function(WatchedFilter) onChangeWatched;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ランク（クリアボタンは出さない要求に合わせて削除）
          const Text('おすすめランク'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('すべて'),
                selected: rankFilter == RankFilter.all,
                onSelected: (v) { if (v) onChangeRank(RankFilter.all); },
              ),
              ChoiceChip(
                label: const Text('Gold'),
                selected: rankFilter == RankFilter.gold,
                onSelected: (v) { if (v) onChangeRank(RankFilter.gold); },
              ),
              ChoiceChip(
                label: const Text('Silver'),
                selected: rankFilter == RankFilter.silver,
                onSelected: (v) { if (v) onChangeRank(RankFilter.silver); },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 視聴状態（クリアボタンなし）
          const Text('視聴状態'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('すべて'),
                selected: watchedFilter == WatchedFilter.all,
                onSelected: (v) { if (v) onChangeWatched(WatchedFilter.all); },
              ),
              ChoiceChip(
                label: const Text('視聴済み'),
                selected: watchedFilter == WatchedFilter.watched,
                onSelected: (v) { if (v) onChangeWatched(WatchedFilter.watched); },
              ),
              ChoiceChip(
                label: const Text('未視聴'),
                selected: watchedFilter == WatchedFilter.unwatched,
                onSelected: (v) { if (v) onChangeWatched(WatchedFilter.unwatched); },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ジャンル（AND/ORトグル＋クリア）
          Row(
            children: [
              const Text('ジャンル'),
              const Spacer(),
              ToggleButtons(
                isSelected: [
                  genreMode == GenreFilterMode.or,
                  genreMode == GenreFilterMode.and,
                ],
                onPressed: (i) => onChangeGenreMode(i == 0 ? GenreFilterMode.or : GenreFilterMode.and),
                constraints: const BoxConstraints(minHeight: 28, minWidth: 44),
                children: const [
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('OR')),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('AND')),
                ],
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onClearGenres,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(1, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('クリア'),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: kFixedGenres.map((g) {
              final selected = genreFilter.contains(g);
              return FilterChip(
                label: Text(g),
                selected: selected,
                visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (v) => onToggleGenre(g, v),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // サービス
          Row(
            children: [
              const Text('サービス'),
              const Spacer(),
              TextButton(
                onPressed: onClearServices,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(1, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('クリア'),
              ),
            ],
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: kFixedServices.map((s) {
              final selected = serviceFilters.contains(s);
              return FilterChip(
                label: Text(s),
                selected: selected,
                visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onSelected: (v) => onToggleService(s, v),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),

          // 年レンジ
          Row(
            children: [
              const Text('年レンジ'),
              const Spacer(),
              TextButton(
                onPressed: onClearYearRange,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(1, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('解除'),
              ),
            ],
          ),
          Builder(
            builder: (context) {
              const minYear = 1980;
              const maxYear = 2025;
              final effectiveMin = (yearMin ?? minYear).toDouble();
              final effectiveMax = (yearMax ?? maxYear).toDouble();

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${effectiveMin.toInt()}年'),
                      Text('${effectiveMax.toInt()}年'),
                    ],
                  ),
                  RangeSlider(
                    min: minYear.toDouble(),
                    max: maxYear.toDouble(),
                    divisions: (maxYear - minYear),
                    values: RangeValues(effectiveMin, effectiveMax),
                    labels: RangeLabels('${effectiveMin.toInt()}', '${effectiveMax.toInt()}'),
                    onChanged: (v) => onSetYearRange(v.start.round(), v.end.round()),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          // 星フィルタ
          Row(
            children: [
              const Text('星フィルタ'),
              const Spacer(),
              TextButton(
                onPressed: onResetStarRange,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(1, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('リセット'),
              ),
            ],
          ),
          SizedBox(
            width: 240,
            child: Row(
              children: [
                Text(starMin.toStringAsFixed(1)),
                Expanded(
                  child: RangeSlider(
                    min: 0,
                    max: 5,
                    divisions: 10,
                    values: RangeValues(starMin, starMax),
                    labels: RangeLabels(
                      starMin.toStringAsFixed(1),
                      starMax.toStringAsFixed(1),
                    ),
                    onChanged: (v) => onSetStarRange(v.start, v.end),
                  ),
                ),
                Text(starMax.toStringAsFixed(1)),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 集計（ここは親側で出すなら削ってOK）
          // 親のStateに依存しないので今回は省略
        ],
      ),
    );
  }
}