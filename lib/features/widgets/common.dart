import 'package:flutter/material.dart';

import '../../core/constants/doc_type_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/models.dart';
import 'decorations.dart';
import 'motion.dart';

/// Section header — small caps label with optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final c = context.docColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Row(
        children: [
          Container(
            width: 18,
            height: 4,
            decoration: BoxDecoration(
              color: c.coral,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    letterSpacing: 1.4,
                    color: c.plum.withValues(alpha: 0.7),
                  ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Empty state with a decorative composition: soft blob + icon badge +
/// dots, message and optional CTA. Interesting but quiet.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;
  final Color? accent;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.docColors;
    final a = accent ?? c.lavender;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 110,
              height: 110,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CornerBlob(
                      color: a.withValues(alpha: 0.16),
                      size: 110,
                    ),
                  ),
                  const Positioned(
                    bottom: 4,
                    left: 0,
                    child: SparkleIcon(size: 12, color: Color(0xFFB98214)),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: a.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(icon, size: 30, color: a),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: c.plum.withValues(alpha: 0.65),
                  ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Processing-status pill with per-state colors: mint=ready, gold=indexed,
/// lavender=processing, pink=imported, coral=failed.
class StatusChip extends StatelessWidget {
  final ProcessingStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = context.docColors;
    final (Color color, Color bg, IconData icon) = switch (status) {
      ProcessingStatus.ready => (c.mint, c.mintSoft, Icons.check_circle_rounded),
      ProcessingStatus.indexed => (c.gold, c.goldSoft, Icons.inventory_2_rounded),
      ProcessingStatus.processing => (c.lavender, c.lavenderSoft, Icons.hourglass_top_rounded),
      ProcessingStatus.imported => (c.pink, c.pinkSoft, Icons.schedule_rounded),
      ProcessingStatus.failed => (c.coral, c.coralSoft, Icons.error_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            status.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

/// Skeleton block for loading states.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.docColors;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: c.outline.withValues(alpha: 0.45),
      ),
    );
  }
}

/// Document card with a file-type identity: neutral warm card body, colored
/// icon badge, left accent bar and type badge — never a flat gray rectangle.
class DocumentTile extends StatelessWidget {
  final Document document;
  final VoidCallback? onTap;
  final Widget? trailing;

  const DocumentTile({
    super.key,
    required this.document,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.docColors;
    final accent = DocTypeColors.accent(document.format);
    final theme = Theme.of(context);

    return FadeSlideIn(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Material(
          color: c.surfaceWarm,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: c.outline.withValues(alpha: 0.8)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // Left accent bar in the format's color.
                  Container(
                    width: 5,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Rounded-square icon badge.
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: Text(
                        DocTypeColors.badge(document.format),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${document.format.label} · ${document.status.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: accent.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
