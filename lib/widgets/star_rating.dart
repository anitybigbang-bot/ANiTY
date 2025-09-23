import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final int max;
  final int? value;            // 1..5 or null
  final void Function(int)? onChanged;
  final void Function()? onClear;

  const StarRating({
    super.key,
    this.max = 5,
    required this.value,
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 1; i <= max; i++)
          IconButton(
            iconSize: 28,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            icon: Icon(
              i <= (value ?? 0) ? Icons.star : Icons.star_border,
            ),
            onPressed: onChanged == null ? null : () => onChanged!(i),
            tooltip: '$i',
          ),
        if (value != null && onClear != null) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '評価を削除',
            onPressed: onClear,
          ),
        ],
      ],
    );
  }
}