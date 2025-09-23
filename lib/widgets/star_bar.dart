// lib/widgets/star_bar.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// シンプル＆拡張可能な星評価ウィジェット（1〜5）
/// - 作品カード上でそのまま評価できる（「押さなくてもすぐ評価」）
/// - 長押しでクリア（0）
/// - readOnly で閲覧専用表示
/// - showValueLabel で数値ラベル表示
/// - enableHoverPreview=false なら「かざしても光らない」（方式A）
class StarBar extends StatefulWidget {
  final int value; // 現在の評価（0〜starCount）
  final int starCount; // 星の数（デフォルト5）
  final double size; // アイコンサイズ
  final double spacing; // 星の間隔
  final bool readOnly; // 読み取り専用
  final bool showValueLabel; // 数値ラベル表示
  final bool allowClear; // クリア許可（長押し/同じ星タップ）
  final bool enableHoverPreview; // かざしたときに光らせるか（既定false）
  final ValueChanged<int>? onChanged; // 変更時コールバック

  const StarBar({
    super.key,
    required this.value,
    this.starCount = 5,
    this.size = 24,
    this.spacing = 2,
    this.readOnly = false,
    this.showValueLabel = false,
    this.allowClear = true,
    this.enableHoverPreview = false, // ★追加：既定で“光らせない”
    this.onChanged,
  }) : assert(value >= 0);

  @override
  State<StarBar> createState() => _StarBarState();
}

class _StarBarState extends State<StarBar> {
  int? _hoverValue; // Web/Desktop のホバー用（enableHoverPreview=true のときだけ使用）

  bool get _isInteractive => !widget.readOnly && widget.onChanged != null;

  void _handleTap(int newValue) {
    if (!_isInteractive) return;
    // 同じ星をタップしたら 0 に戻す（allowClear=true のとき）
    if (widget.allowClear && newValue == widget.value) {
      widget.onChanged!(0);
    } else {
      widget.onChanged!(newValue);
    }
  }

  void _handleLongPress() {
    if (!_isInteractive || !widget.allowClear) return;
    widget.onChanged!(0);
  }

  bool get _isDesktopLike =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  Widget build(BuildContext context) {
    // enableHoverPreview=false の場合は hover 値を完全に無視
    final activeValue = (widget.enableHoverPreview ? (_hoverValue ?? widget.value) : widget.value);

    final stars = List.generate(widget.starCount, (i) {
      final index = i + 1; // 星は1始まり
      final filled = index <= activeValue;

      Widget icon = Icon(
        filled ? Icons.star : Icons.star_border,
        size: widget.size,
        color: filled ? Colors.amber : Theme.of(context).disabledColor,
        semanticLabel: '$index/${widget.starCount}',
      );

      Widget tappable = GestureDetector(
        onTap: () => _handleTap(index),
        onLongPress: _handleLongPress,
        behavior: HitTestBehavior.opaque, // アイコンの周囲もクリック可
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
          child: icon,
        ),
      );

      if (_isInteractive && widget.enableHoverPreview && _isDesktopLike) {
        // ★ ホバー時プレビューを“有効化したときだけ”MouseRegionを使う
        tappable = MouseRegion(
          onEnter: (_) => setState(() => _hoverValue = index),
          onExit: (_) => setState(() => _hoverValue = null),
          child: tappable,
        );
      }

      // readOnly の場合はただの表示（イベントなし）
      if (!_isInteractive) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
          child: icon,
        );
      }

      return tappable;
    });

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: stars,
    );

    if (!widget.showValueLabel) return row;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        row,
        const SizedBox(width: 6),
        Text(
          '${widget.value}/${widget.starCount}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}