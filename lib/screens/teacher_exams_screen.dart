import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'teacher_exam_form_screen.dart';
import 'teacher_exam_delete_screen.dart';
import 'teacher_exam_questions_screen.dart';
import 'teacher_exam_results_screen.dart';

class TeacherExamsScreen extends StatefulWidget {
  const TeacherExamsScreen({super.key});

  @override
  State<TeacherExamsScreen> createState() =>
      _TeacherExamsScreenState();
}

class _TeacherExamsScreenState
    extends State<TeacherExamsScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  String? _teacherId;
  bool _loadingTeacher = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherId();
  }

  // ============================================================
  // GET TEACHER DOCUMENT ID
  // ============================================================

  Future<String?> _getTeacherDocumentId() async {
    final user = _auth.currentUser;

    if (user == null) return null;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final teacherId = userDoc
          .data()?['teacherId']
          ?.toString()
          .trim();

      if (teacherId != null && teacherId.isNotEmpty) {
        return teacherId;
      }
    } catch (_) {
      // Lanjut menggunakan email.
    }

    final email = user.email?.trim();

    if (email != null && email.isNotEmpty) {
      try {
        final teacherQuery = await _firestore
            .collection('teachers')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (teacherQuery.docs.isNotEmpty) {
          return teacherQuery.docs.first.id;
        }
      } catch (_) {
        // Data guru tidak ditemukan.
      }
    }

    return null;
  }

  Future<void> _loadTeacherId() async {
    final teacherId = await _getTeacherDocumentId();

    if (!mounted) return;

    setState(() {
      _teacherId = teacherId;
      _loadingTeacher = false;
    });
  }

  // ============================================================
  // OPEN EXAM FORM
  // ============================================================

  Future<void> _openExamForm({
    String? examId,
    Map<String, dynamic>? examData,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherExamFormScreen(
          examId: examId,
          examData: examData,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            examId == null
                ? 'Ujian berhasil ditambahkan.'
                : 'Ujian berhasil diperbarui.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DELETE EXAM
  // ============================================================

  Future<void> _openDeleteExam(
      String examId,
      String title,
      ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherExamDeleteScreen(
          examId: examId,
          title: title,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ujian berhasil dihapus.'),
        ),
      );
    }
  }

  // ============================================================
  // OPEN QUESTIONS
  // ============================================================

  void _openExamQuestions(
      String examId,
      String title,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherExamQuestionsScreen(
          examId: examId,
          examTitle: title,
        ),
      ),
    );
  }

  // ============================================================
  // OPEN EXAM RESULTS
  // ============================================================

  void _openExamResults(
      String examId,
      String title,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherExamResultsScreen(
          examId: examId,
          examTitle: title,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    final theme = Theme.of(context);

    if (user == null) {
      return const Scaffold(
        body: Center(
          child: Text('Akun guru tidak ditemukan.'),
        ),
      );
    }

    if (_loadingTeacher) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ujian'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_teacherId == null || _teacherId!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Ujian'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.person_off_outlined,
                  size: 64,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Data guru tidak ditemukan.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Pastikan akun Anda sudah terhubung '
                      'dengan data guru di Firestore.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _loadingTeacher = true;
                    });
                    _loadTeacherId();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ujian'),
        actions: [
          IconButton(
            tooltip: 'Tambah Ujian',
            onPressed: () => _openExamForm(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),

      // ========================================================
      // STREAM EXAMS
      // ========================================================

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('exams')
            .where('teacherId', isEqualTo: _teacherId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Gagal mengambil data ujian.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _buildEmptyState(theme);
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              100,
            ),
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
            const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final title =
              (data['title'] ?? 'Ujian').toString();

              return _ExamCard(
                examId: doc.id,
                data: data,
                onEdit: () {
                  _openExamForm(
                    examId: doc.id,
                    examData: data,
                  );
                },
                onDelete: () {
                  _openDeleteExam(doc.id, title);
                },
                onQuestions: () {
                  _openExamQuestions(doc.id, title);
                },
                onResults: () {
                  _openExamResults(doc.id, title);
                },
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openExamForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Ujian'),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.school_outlined,
                size: 52,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum ada ujian',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambahkan ujian pertama Anda.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _openExamForm(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Ujian'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// EXAM CARD
// ================================================================

class _ExamCard extends StatelessWidget {
  final String examId;
  final Map<String, dynamic> data;

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onQuestions;
  final VoidCallback onResults;

  const _ExamCard({
    required this.examId,
    required this.data,
    required this.onEdit,
    required this.onDelete,
    required this.onQuestions,
    required this.onResults,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title =
    (data['title'] ?? 'Tanpa Judul').toString();
    final description =
    (data['description'] ?? '').toString();
    final course =
    (data['courseName'] ?? '').toString();
    final classId =
    (data['classId'] ?? '-').toString();
    final date =
    (data['date'] ?? '-').toString();
    final start =
    (data['startTime'] ?? '-').toString();
    final end =
    (data['endTime'] ?? '-').toString();
    final room =
    (data['room'] ?? '-').toString();
    final duration =
    (data['duration'] ?? 60).toString();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.school_outlined,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (course.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          course,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // MENU
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'questions') {
                      onQuestions();
                    } else if (value == 'results') {
                      onResults();
                    } else if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'questions',
                      child: Row(
                        children: [
                          Icon(Icons.quiz_outlined),
                          SizedBox(width: 10),
                          Text('Kelola Soal'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'results',
                      child: Row(
                        children: [
                          Icon(Icons.assessment_outlined),
                          SizedBox(width: 10),
                          Text('Lihat Hasil'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 10),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline),
                          SizedBox(width: 10),
                          Text('Hapus'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // DESCRIPTION
            if (description.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],

            const SizedBox(height: 14),

            // INFORMATION
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ExamInfoChip(
                  icon: Icons.calendar_today_outlined,
                  text: date,
                ),
                _ExamInfoChip(
                  icon: Icons.access_time_outlined,
                  text: '$start - $end',
                ),
                _ExamInfoChip(
                  icon: Icons.groups_outlined,
                  text: classId,
                ),
                _ExamInfoChip(
                  icon: Icons.meeting_room_outlined,
                  text: room,
                ),
                _ExamInfoChip(
                  icon: Icons.timer_outlined,
                  text: '$duration menit',
                ),
              ],
            ),

            const SizedBox(height: 14),

            // ACTION BUTTONS
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onQuestions,
                    icon: const Icon(Icons.quiz_outlined),
                    label: const Text('Kelola Soal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onResults,
                    icon: const Icon(Icons.assessment_outlined),
                    label: const Text('Lihat Hasil'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// EXAM INFO CHIP
// ================================================================

class _ExamInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ExamInfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}