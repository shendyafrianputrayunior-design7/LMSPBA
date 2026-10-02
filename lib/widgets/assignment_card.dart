import 'package:flutter/material.dart';
import '../models/assignment.dart';
import '../ui/status_colors.dart';

class AssignmentCard extends StatelessWidget {
  final Assignment assignment;

  const AssignmentCard({
    super.key,
    required this.assignment,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final statusColors =
    theme.extension<StatusColors>();

    final isSubmitted = assignment.status == 'Submitted';

    final badgeBg = isSubmitted
        ? statusColors?.submittedBg ?? Colors.green.shade100
        : statusColors?.pendingBg ?? Colors.orange.shade100;

    final badgeFg = isSubmitted
        ? statusColors?.submittedFg ?? Colors.green.shade800
        : statusColors?.pendingFg ?? Colors.orange.shade800;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,

      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),

          border: Border.all(
            color: colorScheme.outline,
            width: 1,
          ),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                theme.brightness == Brightness.dark
                    ? 0.18
                    : 0.04,
              ),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),

        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Row(
            children: [

              // =================================================
              // ASSIGNMENT ICON
              // =================================================

              Container(
                width: 46,
                height: 46,

                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),

                child: Icon(
                  isSubmitted
                      ? Icons.task_alt_rounded
                      : Icons.assignment_outlined,
                  color: colorScheme.primary,
                  size: 23,
                ),
              ),

              const SizedBox(width: 14),

              // =================================================
              // TITLE & DESCRIPTION
              // =================================================

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,

                  children: [
                    Text(
                      assignment.title,

                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,

                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Row(
                      children: [
                        Icon(
                          isSubmitted
                              ? Icons.check_circle_outline_rounded
                              : Icons.schedule_rounded,
                          size: 15,
                          color: badgeFg,
                        ),

                        const SizedBox(width: 5),

                        Expanded(
                          child: Text(
                            isSubmitted
                                ? 'Assignment submitted'
                                : 'Waiting for submission',

                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,

                            style: textTheme.bodySmall?.copyWith(
                              color:
                              colorScheme.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // =================================================
              // STATUS BADGE
              // =================================================

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),

                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),

                child: Row(
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Icon(
                      isSubmitted
                          ? Icons.check_rounded
                          : Icons.access_time_rounded,
                      size: 14,
                      color: badgeFg,
                    ),

                    const SizedBox(width: 4),

                    Text(
                      assignment.status,

                      style: textTheme.labelSmall?.copyWith(
                        color: badgeFg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}