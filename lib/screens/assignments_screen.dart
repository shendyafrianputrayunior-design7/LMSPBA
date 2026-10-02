import 'package:flutter/material.dart';
import '../widgets/app_bar_simple.dart';
import '../models/assignment.dart';
import '../widgets/assignment_card.dart';
import '../ui/app_spacing.dart';
import '../ui/layout.dart';

class AssignmentsScreen extends StatelessWidget {
  const AssignmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // =================================================
      // BACKGROUND
      // =================================================

      backgroundColor: theme.scaffoldBackgroundColor,

      // =================================================
      // APP BAR
      // =================================================

      appBar: AppBarSimple(
        title: 'Assignments',
      ),

      // =================================================
      // BODY
      // =================================================

      body: AppLayout.centeredConstrained(
        maxWidth: 720,

        child: ListView(
          physics: const BouncingScrollPhysics(),

          padding: AppSpacing.listPadding(context).copyWith(
            top: 20,
            bottom: 30,
          ),

          children: [
            // =================================================
            // HEADER
            // =================================================

            Text(
              'Your Assignments',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              'Stay on top of your tasks and deadlines.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 20),

            // =================================================
            // ASSIGNMENT SUMMARY
            // =================================================

            Container(
              padding: const EdgeInsets.all(18),

              decoration: BoxDecoration(
                // Tetap menggunakan primary sebagai
                // warna utama kartu summary.
                color: colorScheme.primary,

                borderRadius: BorderRadius.circular(20),

                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),

              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,

                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),

                    child: const Icon(
                      Icons.assignment_rounded,
                      color: Colors.white,
                      size: 25,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,

                      children: [
                        Text(
                          '${dummyAssignments.length} Assignments',

                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          'Keep your learning tasks organized',

                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 26),

            // =================================================
            // SECTION TITLE
            // =================================================

            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,

              children: [
                Text(
                  'All Assignments',

                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),

                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),

                  child: Text(
                    '${dummyAssignments.length}',

                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // =================================================
            // ASSIGNMENT LIST
            // =================================================

            for (final assignment in dummyAssignments) ...[
              AssignmentCard(
                assignment: assignment,
              ),

              const SizedBox(height: 14),
            ],

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}