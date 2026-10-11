import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeacherExamResultsScreen extends StatelessWidget {
  final String examId;
  final String examTitle;

  const TeacherExamResultsScreen({
    super.key,
    required this.examId,
    required this.examTitle,
  });

  int _toInt(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse('$value') ?? 0;
  }

  String _formatDate(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return 'Belum tersedia';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final resultsQuery = FirebaseFirestore.instance
        .collectionGroup('exam_results')
        .where('examId', isEqualTo: examId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Ujian Siswa'),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  examTitle,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Daftar nilai dan status pengerjaan siswa.',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: resultsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Gagal memuat hasil ujian',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            snapshot.error.toString(),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Kembali'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 56,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Belum ada siswa yang mengerjakan ujian.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final results = [...docs];

                results.sort((a, b) {
                  final aDate = a.data()['submittedAt'];
                  final bDate = b.data()['submittedAt'];

                  final aMillis = aDate is Timestamp
                      ? aDate.millisecondsSinceEpoch
                      : 0;

                  final bMillis = bDate is Timestamp
                      ? bDate.millisecondsSinceEpoch
                      : 0;

                  return bMillis.compareTo(aMillis);
                });

                final passedCount = results.where((doc) {
                  return doc.data()['passed'] == true;
                }).length;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            title: 'Sudah Mengerjakan',
                            value: '${results.length}',
                            icon: Icons.people_outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryCard(
                            title: 'Lulus',
                            value: '$passedCount',
                            icon: Icons.check_circle_outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ...results.map((doc) {
                      final data = doc.data();

                      final studentId =
                      (data['studentId'] ?? '').toString();

                      final score = _toInt(data['score']);
                      final earnedPoints =
                      _toInt(data['earnedPoints']);
                      final totalPoints =
                      _toInt(data['totalPoints']);
                      final correctAnswers =
                      _toInt(data['correctAnswers']);
                      final totalQuestions =
                      _toInt(data['totalQuestions']);

                      final passed = data['passed'] == true;

                      // Nama cadangan jika profil belum dapat dibaca.
                      final storedName = (
                          data['studentName'] ??
                              data['name'] ??
                              ''
                      ).toString().trim();

                      final fallbackName = storedName.isNotEmpty
                          ? storedName
                          : studentId.isNotEmpty
                          ? 'Siswa ${studentId.length > 8 ? studentId.substring(0, 8) : studentId}'
                          : 'Siswa tidak diketahui';

                      final color =
                      passed ? Colors.green : Colors.red;

                      final rawAnswers = data['answers'];
                      final answers = rawAnswers is Map
                          ? Map<String, dynamic>.from(rawAnswers)
                          : <String, dynamic>{};

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    child: StudentInitial(
                                      studentId: studentId,
                                      fallbackName: fallbackName,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        StudentNameText(
                                          studentId: studentId,
                                          fallbackName: fallbackName,
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'UID: ${studentId.isEmpty ? '-' : studentId}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '$score',
                                        style: TextStyle(
                                          fontSize: 25,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                      Text(
                                        passed ? 'LULUS' : 'BELUM LULUS',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  Expanded(
                                    child: _ResultInfo(
                                      label: 'Jawaban benar',
                                      value:
                                      '$correctAnswers/$totalQuestions',
                                    ),
                                  ),
                                  Expanded(
                                    child: _ResultInfo(
                                      label: 'Poin',
                                      value: '$earnedPoints/$totalPoints',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Dikumpulkan: '
                                    '${_formatDate(data['submittedAt'])}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (studentId.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              TeacherExamAnswerScreen(
                                                studentId: studentId,
                                                studentName: fallbackName,
                                                examId: examId,
                                                answers: answers,
                                              ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.visibility_outlined,
                                    ),
                                    label: const Text('Lihat Jawaban'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Mengambil nama siswa dari users/{studentId}.
class StudentNameText extends StatelessWidget {
  final String studentId;
  final String fallbackName;

  const StudentNameText({
    super.key,
    required this.studentId,
    required this.fallbackName,
  });

  @override
  Widget build(BuildContext context) {
    if (studentId.isEmpty) {
      return Text(
        fallbackName,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data();

        final name = (
            userData?['name'] ??
                userData?['fullName'] ??
                userData?['displayName'] ??
                userData?['nama'] ??
                ''
        ).toString().trim();

        final displayName =
        name.isNotEmpty ? name : fallbackName;

        return Text(
          displayName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        );
      },
    );
  }
}

/// Menampilkan inisial berdasarkan nama dari profil.
class StudentInitial extends StatelessWidget {
  final String studentId;
  final String fallbackName;

  const StudentInitial({
    super.key,
    required this.studentId,
    required this.fallbackName,
  });

  @override
  Widget build(BuildContext context) {
    if (studentId.isEmpty) {
      return Text(fallbackName.substring(0, 1).toUpperCase());
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get(),
      builder: (context, snapshot) {
        final profileName =
        (snapshot.data?.data()?['name'] ?? '')
            .toString()
            .trim();

        final name = profileName.isNotEmpty
            ? profileName
            : fallbackName;

        return Text(name.substring(0, 1).toUpperCase());
      },
    );
  }
}

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
      child: Padding(
        padding: const EdgeInsets.all(14),
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
                fontSize: 24,
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

class _ResultInfo extends StatelessWidget {
  final String label;
  final String value;

  const _ResultInfo({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class TeacherExamAnswerScreen extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String examId;
  final Map<String, dynamic> answers;

  const TeacherExamAnswerScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.examId,
    required this.answers,
  });

  @override
  Widget build(BuildContext context) {
    final entries = answers.entries.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jawaban Siswa'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Nama juga diambil dari profil agar halaman jawaban
          // menampilkan nama siswa yang sebenarnya.
          StudentNameText(
            studentId: studentId,
            fallbackName: studentName,
          ),
          const SizedBox(height: 4),
          Text('ID Siswa: $studentId'),
          Text('ID Ujian: $examId'),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Tidak ada data jawaban.'),
              ),
            )
          else
            ...entries.map((entry) {
              final answer = entry.value.toString().trim();

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(
                    Icons.question_answer_outlined,
                  ),
                  title: Text('ID Soal: ${entry.key}'),
                  subtitle: Text(
                    answer.isEmpty ? 'Tidak dijawab' : answer,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}