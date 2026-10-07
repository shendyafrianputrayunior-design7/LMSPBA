import 'package:flutter/material.dart';

class StudentExamResultScreen extends StatelessWidget {
  final String examId;
  final Map<String, dynamic> examData;

  final double score;
  final int earnedPoints;
  final int totalPoints;
  final int correctAnswers;
  final int totalQuestions;
  final int passingScore;
  final bool passed;

  const StudentExamResultScreen({
    super.key,
    required this.examId,
    required this.examData,
    required this.score,
    required this.earnedPoints,
    required this.totalPoints,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.passingScore,
    required this.passed,
  });

  String _formatScore() {
    if (score == score.roundToDouble()) {
      return score.toInt().toString();
    }

    return score.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final title =
    (examData['title'] ?? 'Ujian').toString();

    final subject =
    (examData['subject'] ??
        examData['courseName'] ??
        '-')
        .toString();

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Hasil Ujian'),
          centerTitle: true,
          automaticallyImplyLeading: false,
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),

            _buildResultHeader(context),

            const SizedBox(height: 24),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              subject,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 15,
              ),
            ),

            const SizedBox(height: 28),

            const Text(
              'Ringkasan Hasil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.help_outline,
                    title: 'Total Soal',
                    value: '$totalQuestions',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.check_circle_outline,
                    title: 'Benar',
                    value: '$correctAnswers',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.stars_outlined,
                    title: 'Poin',
                    value:
                    '$earnedPoints/$totalPoints',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.emoji_events_outlined,
                    title: 'Kelulusan',
                    value: passingScore > 0
                        ? '$passingScore'
                        : '-',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: passed
                    ? Colors.green.withOpacity(0.08)
                    : Colors.red.withOpacity(0.08),
                border: Border.all(
                  color: passed
                      ? Colors.green.withOpacity(0.25)
                      : Colors.red.withOpacity(0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    passed
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 36,
                    color: passed
                        ? Colors.green
                        : Colors.red,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          passed
                              ? 'Selamat, kamu lulus!'
                              : 'Kamu belum lulus',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: passed
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          passed
                              ? 'Nilai kamu memenuhi nilai kelulusan ujian.'
                              : passingScore > 0
                              ? 'Nilai kamu belum mencapai nilai kelulusan $passingScore.'
                              : 'Nilai kamu belum memenuhi kriteria kelulusan.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.popUntil(
                    context,
                        (route) => route.isFirst,
                  );
                },
                icon: const Icon(
                  Icons.home_outlined,
                ),
                label: const Text(
                  'Kembali ke Beranda',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.arrow_back,
                ),
                label: const Text(
                  'Kembali',
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHeader(BuildContext context) {
    final primaryColor =
        Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 28,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: primaryColor.withOpacity(0.08),
      ),
      child: Column(
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: passed
                  ? Colors.green.withOpacity(0.12)
                  : Colors.red.withOpacity(0.12),
            ),
            child: Center(
              child: Text(
                _formatScore(),
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: passed
                      ? Colors.green
                      : Colors.red,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Nilai Akhir',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.35),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}