import 'package:flutter/material.dart';

import '../models/wardrobe.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Horizontal garment row with swipe + arrow buttons.
class SwipeArrowRow extends StatefulWidget {
  const SwipeArrowRow({
    super.key,
    required this.garments,
    this.onTap,
    this.onRemove,
    this.height = 128,
    this.emptyLabel,
  });

  final List<Garment> garments;
  final void Function(Garment garment)? onTap;
  final void Function(Garment garment)? onRemove;
  final double height;
  final String? emptyLabel;

  @override
  State<SwipeArrowRow> createState() => _SwipeArrowRowState();
}

class _SwipeArrowRowState extends State<SwipeArrowRow> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _nudge(double delta) {
    if (!_controller.hasClients) return;
    final target = (_controller.offset + delta).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.garments.isEmpty) {
      return Text(
        widget.emptyLabel ?? 'Nothing here yet',
        style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600),
      );
    }

    final showArrows = widget.garments.length > 2;

    return Row(
      children: [
        if (showArrows)
          _ArrowButton(
            icon: Icons.chevron_left_rounded,
            onTap: () => _nudge(-(widget.height * 0.85)),
          ),
        Expanded(
          child: SizedBox(
            height: widget.height,
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              itemCount: widget.garments.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final garment = widget.garments[i];
                return SizedBox(
                  width: widget.height * 0.72,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  if (widget.onTap != null) {
                                    widget.onTap!(garment);
                                  } else {
                                    showPhotoZoom(context, garment);
                                  }
                                },
                                child: PhotoTile(garment: garment, radius: 14),
                              ),
                            ),
                            if (widget.onRemove != null)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Material(
                                  color: Colors.white,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () => widget.onRemove!(garment),
                                    child: const Padding(
                                      padding: EdgeInsets.all(2),
                                      child: Icon(Icons.close, size: 16),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        garment.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        garment.typeLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        if (showArrows)
          _ArrowButton(
            icon: Icons.chevron_right_rounded,
            onTap: () => _nudge(widget.height * 0.85),
          ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor: AppColors.terracottaSoft,
        foregroundColor: AppColors.terracotta,
      ),
      icon: Icon(icon),
    );
  }
}
