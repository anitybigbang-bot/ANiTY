import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/anime.dart';
import '../models/rank.dart'; // ★ ページからではなく共通Rankを参照
import 'star_bar.dart';

class AnimeRow extends StatelessWidget {
  const AnimeRow({
    super.key,
    required this.anime,
    required this.rank,
    required this.expanded,
    required this.watched,
    required this.onToggleExpand,
    required this.onToggleWatched,
    required this.onRate,
  });

  final Anime anime;
  final Rank rank;
  final bool expanded;
  final bool watched;
  final VoidCallback onToggleExpand;
  final void Function(bool) onToggleWatched;
  final void Function(int) onRate;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onToggleExpand,
          leading: CircleAvatar(
            child: Text((anime.avgRating ?? 0).toStringAsFixed(1)),
          ),
          title: Row(
            children: [
              Expanded(child: Text(anime.title)),
              if (rank != Rank.other)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Chip(
                    label: Text(rank == Rank.gold ? 'Gold' : 'Silver'),
                    visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (anime.year != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('${anime.year}'),
                ),
              Tooltip(
                message: '視聴済み',
                child: Checkbox(
                  value: watched,
                  onChanged: (v) => onToggleWatched(v ?? false),
                ),
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          crossFadeState:
              expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 180),
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (anime.summary != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      anime.summary!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Row(
                  children: [
                    StarBar(
                      value: anime.userRating ?? 0,
                      onChanged: onRate,
                    ),
                    const SizedBox(width: 8),
                    Text('平均 ${(anime.avgRating ?? 0).toStringAsFixed(2)}'
                        ' (${anime.ratingCount ?? 0})'),
                  ],
                ),
                const SizedBox(height: 6),
                if (anime.genres.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: -8,
                    children: [for (final g in anime.genres) Chip(label: Text(g))],
                  ),
                  const SizedBox(height: 6),
                ],
                if (anime.streams.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in anime.streams)
                        OutlinedButton(
                          onPressed: () => launchUrl(
                            Uri.parse(s.url),
                            mode: LaunchMode.externalApplication,
                          ),
                          child: Text(s.service),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }
}