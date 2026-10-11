
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeacherQuizScoresScreen extends StatelessWidget {
  final String quizId;
  final String quizTitle;

  const TeacherQuizScoresScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  Future<List<Map<String, dynamic>>> _loadScores() async {
    final firestore = FirebaseFirestore.instance;

    final usersSnapshot = await firestore.collection('users').get();

    final List<Map<String, dynamic>> results = [];

    for (final userDoc in usersSnapshot.docs) {
      final resultDoc = await firestore
          .collection('users')
          .doc(userDoc.id)
          .collection('quiz_results')
          .doc(quizId)
          .get();

      if (!resultDoc.exists) continue;

      final userData = userDoc.data();
      final resultData = resultDoc.data() ?? {};

      final rawSubmittedAt = resultData['submittedAt'];

      results.add({
        'studentId': userDoc.id,
        'name': (userData['name'] ??
            userData['displayName'] ??
            userData['fullName'] ??
            userData['email'] ??
            'Siswa')
            .toString(),
        'email': (userData['email'] ?? '').toString(),
        'score': _toInt(resultData['score']),
        'correctAnswers': _toInt(resultData['correctAnswers']),
        'totalQuestions': _toInt(resultData['totalQuestions']),
        'passed': resultData['passed'] == true,
        'submittedAt': rawSubmittedAt,
      });
    }

    results.sort((a, b) {
      final aTime = a['submittedAt'];
      final bTime = b['submittedAt'];

      if (aTime is Timestamp && bTime is Timestamp) {
        return bTime.compareTo(aTime);
      }

      return (b['score'] as int).compareTo(a['score'] as int);
    });

    return results;
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nilai Quiz'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _loadScores(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat nilai quiz.\n\n${snapshot.error}\n\n'
                      'Pastikan aturan Firestore mengizinkan guru membaca '
                      'data siswa dan hasil quiz.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final scores = snapshot.data ?? [];

          if (scores.isEmpty) {
            return _buildEmptyState(context);
          }

          final passedCount =
              scores.where((item) => item['passed'] == true).length;

          final totalScore = scores.fold<int>(
            0,
                (sum, item) => sum + (item['score'] as int),
          );

          final average = totalScore / scores.length;

          return RefreshIndicator(
            onRefresh: () async {
              // FutureBuilder dibuat ulang melalui refresh halaman.
              // Tarik ke bawah untuk memperbarui data.
              await _loadScores();
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(context, scores.length),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        title: 'Peserta',
                        value: '${scores.length}',
                        icon: Icons.people_outline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Lulus',
                        value: '$passedCount',
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        title: 'Rata-rata',
                        value: average.toStringAsFixed(1),
                        icon: Icons.bar_chart_outlined,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                const Text(
                  'Daftar Nilai Siswa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                ...scores.map(
                      (item) => _StudentScoreCard(item: item),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int total) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(
            Icons.assessment_outlined,
            size: 36,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quizTitle,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$total siswa sudah mengerjakan',
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 72,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Nilai',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nilai akan muncul setelah siswa menyelesaikan quiz ini.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// RINGKASAN NILAI
// ==================================================================

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 8,
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
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// KARTU NILAI SISWA
// ==================================================================

class _StudentScoreCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _StudentScoreCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String;
    final email = item['email'] as String;
    final score = item['score'] as int;
    final correct = item['correctAnswers'] as int;
    final total = item['totalQuestions'] as int;
    final passed = item['passed'] == true;
    final submittedAt = item['submittedAt'];

    final submittedText = submittedAt is Timestamp
        ? _formatDate(submittedAt.toDate())
        : 'Waktu pengumpulan tidak tersedia';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Text(
                    name.isNotEmpty
                        ? name[0].toUpperCase()
                        : '?',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$score',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: passed ? Colors.green : Colors.red,
                      ),
                    ),
                    Text(
                      passed ? 'Lulus' : 'Belum lulus',
                      style: TextStyle(
                        fontSize: 12,
                        color: passed ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(
                  Icons.checklist_outlined,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Jawaban benar: $correct dari $total'),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    submittedText,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }
}
