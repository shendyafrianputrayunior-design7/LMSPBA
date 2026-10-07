import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'student_exam_questions_screen.dart';

class StudentExamDetailScreen extends StatefulWidget {
  final String examId;
  final Map<String, dynamic> examData;

  const StudentExamDetailScreen({
    super.key,
    required this.examId,
    required this.examData,
  });

  @override
  State<StudentExamDetailScreen> createState() =>
      _StudentExamDetailScreenState();
}

class _StudentExamDetailScreenState
    extends State<StudentExamDetailScreen> {
  bool _loading = true;
  int _questionCount = 0;
  int _totalPoints = 0;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('exam_questions')
          .where('examId', isEqualTo: widget.examId)
          .get();

      int totalPoints = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final points = data['points'];

        if (points is int) {
          totalPoints += points;
        } else {
          totalPoints +=
              int.tryParse((points ?? '0').toString()) ?? 0;
        }
      }

      if (!mounted) return;

      setState(() {
        _questionCount = snapshot.docs.length;
        _totalPoints = totalPoints;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memuat soal ujian: $e',
          ),
        ),
      );
    }
  }

  String _getString(String key, [String fallback = '-']) {
    final value = widget.examData[key];

    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }

    return value.toString();
  }

  int _getInt(String key, [int fallback = 0]) {
    final value = widget.examData[key];

    if (value is int) {
      return value;
    }

    return int.tryParse(
      (value ?? '').toString(),
    ) ??
        fallback;
  }

  DateTime? _getDate(String key) {
    final value = widget.examData[key];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '-';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  Future<void> _startExam() async {
    if (_questionCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ujian ini belum memiliki soal.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Mulai Ujian?'),
          content: const Text(
            'Pastikan kamu sudah siap sebelum memulai ujian. '
                'Setelah dimulai, waktu pengerjaan akan berjalan.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Mulai'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentExamQuestionsScreen(
          examId: widget.examId,
          examData: widget.examData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _getString('title', 'Ujian');

    final subject = _getString(
      'subject',
      _getString('courseName'),
    );

    final description = _getString(
      'description',
      'Tidak ada deskripsi ujian.',
    );

    final duration = _getInt('duration');

    final passingScore = _getInt(
      'passingScore',
      0,
    );

    final date = _getDate('date');

    final className = _getString(
      'className',
      _getString('classId'),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Ujian'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: _loadQuestions,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withOpacity(0.08),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.12),
                    ),
                    child: Icon(
                      Icons.assignment_rounded,
                      size: 38,
                      color: Theme.of(context)
                          .colorScheme
                          .primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subject,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Informasi Ujian',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            _InfoCard(
              icon: Icons.help_outline,
              title: 'Jumlah Soal',
              value: '$_questionCount soal',
            ),

            _InfoCard(
              icon: Icons.timer_outlined,
              title: 'Durasi',
              value: duration > 0
                  ? '$duration menit'
                  : 'Tidak ditentukan',
            ),

            _InfoCard(
              icon: Icons.stars_outlined,
              title: 'Total Poin',
              value: '$_totalPoints poin',
            ),

            _InfoCard(
              icon: Icons.emoji_events_outlined,
              title: 'Nilai Kelulusan',
              value: passingScore > 0
                  ? '$passingScore'
                  : 'Tidak ditentukan',
            ),

            _InfoCard(
              icon: Icons.calendar_today_outlined,
              title: 'Tanggal',
              value: _formatDate(date),
            ),

            _InfoCard(
              icon: Icons.class_outlined,
              title: 'Kelas',
              value: className,
            ),

            const SizedBox(height: 18),

            const Text(
              'Deskripsi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.grey.shade300,
                ),
              ),
              child: Text(
                description,
                style: const TextStyle(
                  height: 1.5,
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (_questionCount == 0)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ujian belum memiliki soal sehingga belum dapat dikerjakan.',
                      ),
                    ),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _startExam,
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                  ),
                  label: const Text(
                    'Mulai Ujian',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.35),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}