
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/course.dart';
import '../models/quiz.dart';
import 'teacher_quiz_questions_screen.dart';
import 'teacher_quiz_scores_screen.dart';

class TeacherQuizzesScreen extends StatefulWidget {
  final Course course;

  const TeacherQuizzesScreen({
    super.key,
    required this.course,
  });

  @override
  State<TeacherQuizzesScreen> createState() =>
      _TeacherQuizzesScreenState();
}

class _TeacherQuizzesScreenState
    extends State<TeacherQuizzesScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = false;

  // ============================================================
  // TAMBAH QUIZ
  // ============================================================

  Future<void> _addQuiz() async {
    final result =
    await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => const _AddQuizPage(),
      ),
    );

    if (!mounted || result == null) return;

    final User? user = _auth.currentUser;

    if (user == null) {
      _showMessage('Akun guru tidak ditemukan.');
      return;
    }

    setState(() => _loading = true);

    try {
      await _firestore.collection('quizzes').add({
        'courseId': widget.course.id,
        'teacherId': user.uid,
        'title': result['title'],
        'description': result['description'],
        'duration': result['duration'],
        'passingScore': result['passingScore'],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showMessage('Quiz berhasil ditambahkan.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Gagal menyimpan quiz: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ============================================================
  // HAPUS QUIZ
  // ============================================================

  Future<void> _deleteQuiz(
      String quizId,
      String title,
      ) async {
    final confirm = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _DeleteQuizPage(title: title),
      ),
    );

    if (!mounted || confirm != true) return;

    try {
      await _firestore
          .collection('quizzes')
          .doc(quizId)
          .delete();

      if (!mounted) return;
      _showMessage('Quiz berhasil dihapus.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Gagal menghapus quiz: $e');
    }
  }

  // ============================================================
  // KELOLA SOAL
  // ============================================================

  void _openQuestions(
      String quizId,
      Map<String, dynamic> data,
      ) {
    final Quiz quiz = Quiz.fromFirestore(quizId, data);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherQuizQuestionsScreen(
          quiz: quiz,
        ),
      ),
    );
  }

  // ============================================================
  // LIHAT NILAI QUIZ
  // ============================================================

  void _openQuizScores(
      String quizId,
      Map<String, dynamic> data,
      ) {
    final title = (data['title'] ?? 'Quiz').toString();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherQuizScoresScreen(
          quizId: quizId,
          quizTitle: title,
        ),
      ),
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quiz - ${widget.course.title}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addQuiz,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Quiz'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('quizzes')
            .where('courseId', isEqualTo: widget.course.id)
            .snapshots(),
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
                  'Gagal memuat quiz.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final quizzes = snapshot.data?.docs.toList() ?? [];

          if (quizzes.isEmpty) {
            return _buildEmptyState();
          }

          quizzes.sort((a, b) {
            final aCreated = a.data()['createdAt'];
            final bCreated = b.data()['createdAt'];

            if (aCreated is Timestamp && bCreated is Timestamp) {
              return bCreated.compareTo(aCreated);
            }

            return 0;
          });

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: quizzes.length,
            separatorBuilder: (_, __) =>
            const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = quizzes[index];
              final data = doc.data();

              return _QuizCard(
                quizId: doc.id,
                data: data,
                onQuestions: () {
                  _openQuestions(doc.id, data);
                },
                onScores: () {
                  _openQuizScores(doc.id, data);
                },
                onDelete: () {
                  _deleteQuiz(
                    doc.id,
                    (data['title'] ?? 'Quiz').toString(),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 72,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.7),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum Ada Quiz',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambahkan quiz untuk course ini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : _addQuiz,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Quiz'),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// HALAMAN TAMBAH QUIZ
// ==================================================================

class _AddQuizPage extends StatefulWidget {
  const _AddQuizPage();

  @override
  State<_AddQuizPage> createState() => _AddQuizPageState();
}

class _AddQuizPageState extends State<_AddQuizPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  String _title = '';
  String _description = '';
  String _duration = '30';
  String _passingScore = '70';

  void _save() {
    final form = _formKey.currentState;

    if (form == null || !form.validate()) return;

    final duration = int.tryParse(_duration.trim());
    final passingScore = int.tryParse(_passingScore.trim());

    if (duration == null || passingScore == null) return;

    Navigator.of(context).pop({
      'title': _title.trim(),
      'description': _description.trim(),
      'duration': duration,
      'passingScore': passingScore,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Quiz'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.quiz_outlined,
                      size: 34,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Buat Quiz Baru',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Isi informasi quiz sebelum disimpan.',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              TextFormField(
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Judul Quiz',
                  hintText: 'Contoh: Quiz Bab 1',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.quiz_outlined),
                ),
                onChanged: (value) => _title = value,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Judul quiz wajib diisi.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              TextFormField(
                maxLines: 4,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi',
                  hintText: 'Deskripsi quiz',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 65),
                    child: Icon(Icons.description_outlined),
                  ),
                ),
                onChanged: (value) => _description = value,
              ),

              const SizedBox(height: 18),

              TextFormField(
                initialValue: '30',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Durasi',
                  hintText: 'Contoh: 30',
                  suffixText: 'menit',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                onChanged: (value) => _duration = value,
                validator: (value) {
                  final duration = int.tryParse(value?.trim() ?? '');
                  if (duration == null || duration <= 0) {
                    return 'Durasi harus lebih dari 0.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              TextFormField(
                initialValue: '70',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Nilai Kelulusan',
                  hintText: 'Contoh: 70',
                  suffixText: '%',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                onChanged: (value) => _passingScore = value,
                validator: (value) {
                  final score = int.tryParse(value?.trim() ?? '');
                  if (score == null || score < 0 || score > 100) {
                    return 'Nilai harus antara 0–100.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _save(),
              ),

              const SizedBox(height: 32),

              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text(
                    'Simpan Quiz',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Batal',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// HALAMAN KONFIRMASI HAPUS
// ==================================================================

class _DeleteQuizPage extends StatelessWidget {
  final String title;

  const _DeleteQuizPage({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hapus Quiz'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline,
                  size: 42,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Hapus Quiz?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Apakah kamu yakin ingin menghapus quiz "$title"?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus Quiz'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Batal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================================================================
// QUIZ CARD
// ==================================================================

class _QuizCard extends StatelessWidget {
  final String quizId;
  final Map<String, dynamic> data;
  final VoidCallback onQuestions;
  final VoidCallback onScores;
  final VoidCallback onDelete;

  const _QuizCard({
    required this.quizId,
    required this.data,
    required this.onQuestions,
    required this.onScores,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = (data['title'] ?? 'Quiz').toString();
    final description = (data['description'] ?? '').toString();

    final duration = data['duration'] is int
        ? data['duration'] as int
        : int.tryParse((data['duration'] ?? '0').toString()) ?? 0;

    final passingScore = data['passingScore'] is int
        ? data['passingScore'] as int
        : int.tryParse((data['passingScore'] ?? '70').toString()) ?? 70;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.quiz_outlined,
                color: Theme.of(context)
                    .colorScheme
                    .onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.timer_outlined,
                        label: '$duration menit',
                      ),
                      _InfoChip(
                        icon: Icons.flag_outlined,
                        label: 'Lulus $passingScore%',
                      ),
                    ],
                  ),
                ],
              ),
            ),

            PopupMenuButton<String>(
              tooltip: 'Menu Quiz',
              onSelected: (value) {
                if (value == 'questions') {
                  onQuestions();
                } else if (value == 'scores') {
                  onScores();
                } else if (value == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'questions',
                  child: Row(
                    children: [
                      Icon(Icons.help_outline),
                      SizedBox(width: 10),
                      Text('Kelola Soal'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'scores',
                  child: Row(
                    children: [
                      Icon(Icons.bar_chart_outlined),
                      SizedBox(width: 10),
                      Text('Lihat Nilai'),
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
      ),
    );
  }
}

// ==================================================================
// INFO CHIP
// ==================================================================

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
