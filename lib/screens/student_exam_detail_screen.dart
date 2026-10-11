import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  bool _startingExam = false;

  int _questionCount = 0;
  int _totalPoints = 0;

  DocumentReference<Map<String, dynamic>>? get _resultRef {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('exam_results')
        .doc(widget.examId);
  }

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();

    return int.tryParse((value ?? '').toString()) ?? fallback;
  }

  String _getString(String key, [String fallback = '-']) {
    final value = widget.examData[key];

    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }

    return value.toString();
  }

  int _getInt(String key, [int fallback = 0]) {
    return _toInt(widget.examData[key], fallback: fallback);
  }

  DateTime? _getDate(String key) {
    final value = widget.examData[key];

    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Future<void> _loadQuestions() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('exam_questions')
          .where('examId', isEqualTo: widget.examId)
          .get();

      int totalPoints = 0;

      for (final doc in snapshot.docs) {
        totalPoints += _toInt(
          doc.data()['points'],
          fallback: 10,
        );
      }

      if (!mounted) return;

      setState(() {
        _questionCount = snapshot.docs.length;
        _totalPoints = totalPoints;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      _showMessage('Gagal memuat soal ujian. Periksa koneksi dan coba lagi.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _startExam() async {
    if (_startingExam) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('Silakan login terlebih dahulu.');
      return;
    }

    if (_questionCount <= 0) {
      _showMessage('Ujian ini belum memiliki soal.');
      return;
    }

    final resultRef = _resultRef;

    if (resultRef == null) {
      _showMessage('Tidak dapat memeriksa hasil ujian. Silakan login kembali.');
      return;
    }

    setState(() => _startingExam = true);

    try {
      // Periksa hasil sebelum menampilkan dialog mulai.
      final resultSnapshot = await resultRef.get();

      if (!mounted) return;

      if (resultSnapshot.exists) {
        _showMessage('Ujian ini sudah pernah dikerjakan.');
        setState(() => _startingExam = false);
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Mulai Ujian?'),
            content: const Text(
              'Pastikan kamu sudah siap sebelum memulai ujian. '
                  'Setelah dimulai, waktu pengerjaan akan berjalan.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Mulai'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      if (confirmed != true) {
        setState(() => _startingExam = false);
        return;
      }

      // Periksa kembali untuk mengurangi risiko masuk bersamaan
      // jika hasil telah tersimpan ketika dialog sedang terbuka.
      final latestResult = await resultRef.get();

      if (!mounted) return;

      if (latestResult.exists) {
        _showMessage('Ujian ini sudah pernah dikerjakan.');
        setState(() => _startingExam = false);
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentExamQuestionsScreen(
            examId: widget.examId,
            examData: widget.examData,
          ),
        ),
      );

      if (!mounted) return;

      setState(() => _startingExam = false);
    } catch (e) {
      if (!mounted) return;

      setState(() => _startingExam = false);
      _showMessage('Gagal memeriksa atau memulai ujian. Coba lagi.');
    }
  }

  Widget _buildResultStatus(Map<String, dynamic> result) {
    final score = _toInt(result['score']);
    final passed = result['passed'] == true;

    final passingScore = _toInt(
      result['passingScore'],
      fallback: _getInt('passingScore'),
    );

    final color = passed ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                passed
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: color,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ujian Sudah Dikerjakan',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Nilai kamu'),
          const SizedBox(height: 4),
          Text(
            '$score',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            passed
                ? 'Selamat, kamu dinyatakan lulus.'
                : 'Kamu belum mencapai nilai kelulusan.',
          ),
          if (passingScore > 0) ...[
            const SizedBox(height: 6),
            Text('Nilai kelulusan: $passingScore'),
          ],
          const SizedBox(height: 12),
          const Text(
            'Ujian ini sudah selesai dan tidak dapat dikerjakan kembali.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return _InfoCard(
      icon: icon,
      title: title,
      value: value,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _getString('title', 'Ujian');

    final subject = _getString(
      'subject',
      _getString(
        'courseName',
        _getString('courseTitle'),
      ),
    );

    final description = _getString(
      'description',
      'Tidak ada deskripsi ujian.',
    );

    final duration = _getInt('duration');
    final passingScore = _getInt('passingScore');
    final date = _getDate('date');

    final className = _getString(
      'className',
      _getString('classId'),
    );

    final resultRef = _resultRef;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Ujian'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadQuestions,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
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
                      color: Theme.of(context).colorScheme.primary,
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

            _buildInfoCard(
              icon: Icons.help_outline,
              title: 'Jumlah Soal',
              value: '$_questionCount soal',
            ),

            _buildInfoCard(
              icon: Icons.timer_outlined,
              title: 'Durasi',
              value: duration > 0
                  ? '$duration menit'
                  : 'Tidak ditentukan',
            ),

            _buildInfoCard(
              icon: Icons.stars_outlined,
              title: 'Total Poin',
              value: '$_totalPoints poin',
            ),

            _buildInfoCard(
              icon: Icons.emoji_events_outlined,
              title: 'Nilai Kelulusan',
              value: passingScore > 0
                  ? '$passingScore'
                  : 'Tidak ditentukan',
            ),

            _buildInfoCard(
              icon: Icons.calendar_today_outlined,
              title: 'Tanggal',
              value: _formatDate(date),
            ),

            _buildInfoCard(
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
                style: const TextStyle(height: 1.5),
              ),
            ),

            const SizedBox(height: 24),

            if (resultRef == null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Silakan login untuk memeriksa status ujian.',
                ),
              )
            else
              StreamBuilder<
                  DocumentSnapshot<Map<String, dynamic>>>(
                stream: resultRef.snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text(
                        'Gagal memuat status ujian. '
                            'Periksa koneksi dan coba lagi.',
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

                  if (snapshot.data?.exists == true) {
                    final result =
                        snapshot.data!.data() ??
                            <String, dynamic>{};

                    return _buildResultStatus(result);
                  }

                  if (_questionCount == 0) {
                    return Container(
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
                              'Ujian belum memiliki soal sehingga '
                                  'belum dapat dikerjakan.',
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed:
                      _startingExam ? null : _startExam,
                      icon: _startingExam
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        _startingExam
                            ? 'Memeriksa ujian...'
                            : 'Mulai Ujian',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                },
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
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}