
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/quiz.dart';

class StudentQuizzesScreen extends StatelessWidget {
  final String courseId;
  final String courseTitle;

  const StudentQuizzesScreen({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore
            .collection('quizzes')
            .where('courseId', isEqualTo: courseId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Gagal memuat quiz.\n${snapshot.error}'),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final quizzes = <Quiz>[];

          for (final doc in docs) {
            try {
              quizzes.add(Quiz.fromFirestore(doc.id, doc.data()));
            } catch (_) {
              // Abaikan data quiz yang tidak valid.
            }
          }

          if (quizzes.isEmpty) {
            return _emptyState(context);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: quizzes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final quiz = quizzes[index];

              return _QuizCard(
                quiz: quiz,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StudentQuizDetailScreen(
                        quiz: quiz,
                        courseTitle: courseTitle,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 72,
              color: colors.primary.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum Ada Quiz',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada quiz untuk course ini.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// KARTU QUIZ
// ============================================================

class _QuizCard extends StatelessWidget {
  final Quiz quiz;
  final VoidCallback onTap;

  const _QuizCard({
    required this.quiz,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.quiz_outlined,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quiz.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (quiz.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        quiz.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _SmallInfo(
                          icon: Icons.timer_outlined,
                          text: '${quiz.duration} menit',
                        ),
                        _SmallInfo(
                          icon: Icons.check_circle_outline,
                          text: 'Lulus ${quiz.passingScore}%',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallInfo({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// ============================================================
// DETAIL QUIZ DAN PEMERIKSAAN HASIL SEBELUMNYA
// ============================================================

class StudentQuizDetailScreen extends StatelessWidget {
  final Quiz quiz;
  final String courseTitle;

  const StudentQuizDetailScreen({
    super.key,
    required this.quiz,
    required this.courseTitle,
  });

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Quiz')),
        body: const Center(child: Text('Silakan login terlebih dahulu.')),
      );
    }

    final resultRef = firestore
        .collection('users')
        .doc(user.uid)
        .collection('quiz_results')
        .doc(quiz.id);

    return Scaffold(
      appBar: AppBar(title: const Text('Detail Quiz')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: resultRef.snapshots(),
        builder: (context, resultSnapshot) {
          if (resultSnapshot.hasError) {
            return Center(
              child: Text(
                'Gagal memeriksa hasil quiz.\n${resultSnapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          if (resultSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final resultDoc = resultSnapshot.data;
          final alreadyCompleted = resultDoc?.exists ?? false;
          final resultData = resultDoc?.data() ?? {};

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: firestore
                .collection('quiz_questions')
                .where('quizId', isEqualTo: quiz.id)
                .snapshots(),
            builder: (context, questionSnapshot) {
              if (questionSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Gagal memuat soal.\n${questionSnapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              if (questionSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final questionCount = questionSnapshot.data?.docs.length ?? 0;

              return _QuizDetailContent(
                quiz: quiz,
                courseTitle: courseTitle,
                questionCount: questionCount,
                alreadyCompleted: alreadyCompleted,
                previousScore: _toInt(resultData['score']),
                previousPassed: resultData['passed'] == true,
              );
            },
          );
        },
      ),
    );
  }

  static int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _QuizDetailContent extends StatelessWidget {
  final Quiz quiz;
  final String courseTitle;
  final int questionCount;
  final bool alreadyCompleted;
  final int previousScore;
  final bool previousPassed;

  const _QuizDetailContent({
    required this.quiz,
    required this.courseTitle,
    required this.questionCount,
    required this.alreadyCompleted,
    required this.previousScore,
    required this.previousPassed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.quiz,
            size: 64,
            color: colors.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          quiz.title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(courseTitle, style: TextStyle(color: colors.onSurfaceVariant)),
        if (quiz.description.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(quiz.description, style: const TextStyle(fontSize: 15)),
        ],
        const SizedBox(height: 24),
        _InfoRow(
          icon: Icons.quiz_outlined,
          title: 'Jumlah Soal',
          value: '$questionCount soal',
        ),
        _InfoRow(
          icon: Icons.timer_outlined,
          title: 'Durasi',
          value: '${quiz.duration} menit',
        ),
        _InfoRow(
          icon: Icons.flag_outlined,
          title: 'Nilai Kelulusan',
          value: '${quiz.passingScore}%',
        ),
        const SizedBox(height: 20),

        if (alreadyCompleted) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  previousPassed
                      ? Icons.emoji_events
                      : Icons.assignment_turned_in,
                  size: 44,
                  color: colors.onSecondaryContainer,
                ),
                const SizedBox(height: 8),
                Text(
                  'Quiz Sudah Dikerjakan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nilai kamu: $previousScore',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: colors.onSecondaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  previousPassed ? 'Status: Lulus' : 'Status: Belum Lulus',
                  style: TextStyle(color: colors.onSecondaryContainer),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quiz hanya dapat dikerjakan satu kali.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.onSecondaryContainer),
                ),
              ],
            ),
          ),
        ] else ...[
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: questionCount == 0
                  ? null
                  : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StudentTakeQuizScreen(quiz: quiz),
                  ),
                );
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Mulai Quiz'),
            ),
          ),
          if (questionCount == 0) ...[
            const SizedBox(height: 12),
            const Text(
              'Quiz belum memiliki soal.',
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 22, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(title)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ============================================================
// MENGERJAKAN QUIZ
// ============================================================

class StudentTakeQuizScreen extends StatefulWidget {
  final Quiz quiz;

  const StudentTakeQuizScreen({
    super.key,
    required this.quiz,
  });

  @override
  State<StudentTakeQuizScreen> createState() => _StudentTakeQuizScreenState();
}

class _StudentTakeQuizScreenState extends State<StudentTakeQuizScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _answers = {};

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _questions = [];

  int _currentIndex = 0;
  int _remainingSeconds = 0;

  bool _loading = true;
  bool _submitting = false;

  StreamSubscription<int>? _timerSubscription;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('User belum login.');
      }

      // Periksa apakah quiz sudah pernah dikirim.
      final resultRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_results')
          .doc(widget.quiz.id);

      final previousResult = await resultRef.get();

      if (previousResult.exists) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quiz ini sudah pernah kamu kerjakan.'),
          ),
        );

        Navigator.of(context).pop();
        return;
      }

      final snapshot = await _firestore
          .collection('quiz_questions')
          .where('quizId', isEqualTo: widget.quiz.id)
          .get();

      final questions = snapshot.docs.toList();

      questions.sort((a, b) {
        return _toInt(a.data()['order'])
            .compareTo(_toInt(b.data()['order']));
      });

      if (!mounted) return;

      setState(() {
        _questions = questions;
        _remainingSeconds = _safeDuration(widget.quiz.duration) * 60;
        _loading = false;
      });

      if (_questions.isNotEmpty) {
        _startTimer();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat soal: $e')),
      );
    }
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _safeDuration(int value) => value <= 0 ? 1 : value;

  void _startTimer() {
    _timerSubscription?.cancel();

    _timerSubscription = Stream.periodic(
      const Duration(seconds: 1),
          (count) => count,
    ).listen((_) {
      if (!mounted || _submitting) return;

      if (_remainingSeconds <= 1) {
        setState(() => _remainingSeconds = 0);
        _timerSubscription?.cancel();
        _submitQuiz(autoSubmit: true);
        return;
      }

      setState(() => _remainingSeconds--);
    });
  }

  String _formatTime(int seconds) {
    final safe = seconds < 0 ? 0 : seconds;
    final minutes = safe ~/ 60;
    final remaining = safe % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remaining.toString().padLeft(2, '0')}';
  }

  void _selectAnswer(String answer) {
    if (_submitting ||
        _currentIndex < 0 ||
        _currentIndex >= _questions.length) {
      return;
    }

    setState(() => _answers[_questions[_currentIndex].id] = answer);
  }

  void _nextQuestion() {
    if (_submitting || _questions.isEmpty) return;

    if (_currentIndex >= _questions.length - 1) {
      _showSubmitConfirmation();
      return;
    }

    setState(() => _currentIndex++);
  }

  void _previousQuestion() {
    if (_submitting || _currentIndex <= 0) return;
    setState(() => _currentIndex--);
  }

  Future<void> _showSubmitConfirmation() async {
    if (_submitting) return;

    final unanswered = _questions.length - _answers.length;

    final shouldSubmit = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _SubmitQuizPage(
          unanswered: unanswered,
          total: _questions.length,
        ),
      ),
    );

    if (!mounted) return;

    if (shouldSubmit == true) {
      await _submitQuiz();
    }
  }

  Future<void> _submitQuiz({bool autoSubmit = false}) async {
    if (_submitting || !mounted) return;

    if (_questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada soal untuk dikirim.')),
      );
      return;
    }

    setState(() => _submitting = true);
    _timerSubscription?.cancel();

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('User belum login.');
      }

      int correctAnswers = 0;
      int totalPoints = 0;
      int earnedPoints = 0;

      final Map<String, String> savedAnswers = {};

      for (final doc in _questions) {
        final data = doc.data();

        // Mendukung dua nama field kunci jawaban.
        final correctAnswer =
        (data['correctAnswer'] ?? data['answer'] ?? '')
            .toString()
            .trim()
            .toUpperCase();

        final points = _readPoints(data['points']);
        final answer = (_answers[doc.id] ?? '').trim().toUpperCase();

        totalPoints += points;
        savedAnswers[doc.id] = answer;

        if (answer.isNotEmpty && answer == correctAnswer) {
          correctAnswers++;
          earnedPoints += points;
        }
      }

      final score = totalPoints <= 0
          ? 0
          : ((earnedPoints / totalPoints) * 100).round();

      final passed = score >= widget.quiz.passingScore;

      final resultRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_results')
          .doc(widget.quiz.id);

      // Kunci utama fitur sekali mengerjakan:
      // jika dokumen hasil sudah ada, hasil tidak ditimpa.
      await _firestore.runTransaction((transaction) async {
        final existingResult = await transaction.get(resultRef);

        if (existingResult.exists) {
          throw Exception(
            'Quiz ini sudah pernah dikerjakan. Hasil sebelumnya tidak dapat diubah.',
          );
        }

        transaction.set(resultRef, {
          'quizId': widget.quiz.id,
          'courseId': widget.quiz.courseId,
          'score': score,
          'totalQuestions': _questions.length,
          'correctAnswers': correctAnswers,
          'passed': passed,
          'answers': savedAnswers,
          'submittedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
            quiz: widget.quiz,
            score: score,
            correctAnswers: correctAnswers,
            totalQuestions: _questions.length,
            passed: passed,
            autoSubmitted: autoSubmit,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _submitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim quiz: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  int _readPoints(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 10;
  }

  Map<String, String> _readOptions(dynamic rawOptions) {
    final result = <String, String>{};

    if (rawOptions is Map) {
      rawOptions.forEach((key, value) {
        if (key != null) {
          result[key.toString().trim().toUpperCase()] =
              value?.toString() ?? '';
        }
      });
    } else if (rawOptions is List) {
      for (var i = 0; i < rawOptions.length && i < 4; i++) {
        result['ABCD'[i]] = rawOptions[i]?.toString() ?? '';
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.quiz.title)),
        body: const Center(child: Text('Tidak ada soal.')),
      );
    }

    if (_currentIndex < 0 || _currentIndex >= _questions.length) {
      return const Scaffold(
        body: Center(child: Text('Terjadi kesalahan pada soal.')),
      );
    }

    final question = _questions[_currentIndex];
    final data = question.data();
    final questionText = (data['question'] ?? '').toString();
    final options = _readOptions(data['options']);
    final selectedAnswer = _answers[question.id];
    final progress = (_currentIndex + 1) / _questions.length;
    final colors = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz.title),
          automaticallyImplyLeading: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  _formatTime(_remainingSeconds),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _remainingSeconds <= 60 ? Colors.red : null,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            LinearProgressIndicator(value: progress),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Soal ${_currentIndex + 1} dari ${_questions.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${_answers.length}/${_questions.length} terjawab',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          questionText.isEmpty
                              ? 'Pertanyaan tidak tersedia.'
                              : questionText,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._buildOptionWidgets(
                      context,
                      options,
                      selectedAnswer,
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_currentIndex > 0) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _submitting ? null : _previousQuestion,
                          child: const Text('Sebelumnya'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _nextQuestion,
                        child: Text(
                          _currentIndex == _questions.length - 1
                              ? 'Selesai'
                              : 'Berikutnya',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildOptionWidgets(
      BuildContext context,
      Map<String, String> options,
      String? selectedAnswer,
      ) {
    final colors = Theme.of(context).colorScheme;

    return ['A', 'B', 'C', 'D'].map((letter) {
      final optionText = options[letter] ?? '';
      final selected = selectedAnswer == letter;

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: _submitting ? null : () => _selectAnswer(letter),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? colors.primary : colors.outline,
                width: selected ? 2 : 1,
              ),
              color: selected ? colors.primaryContainer : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                  ),
                  child: Text(
                    letter,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: selected ? colors.onPrimary : null,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    optionText.isEmpty
                        ? 'Pilihan tidak tersedia'
                        : optionText,
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: colors.primary),
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    _timerSubscription?.cancel();
    super.dispose();
  }
}

// ============================================================
// KONFIRMASI PENGIRIMAN
// ============================================================

class _SubmitQuizPage extends StatelessWidget {
  final int unanswered;
  final int total;

  const _SubmitQuizPage({
    required this.unanswered,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kirim Quiz')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.assignment_turned_in_outlined, size: 72),
            const SizedBox(height: 24),
            const Text(
              'Kirim jawaban?',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              unanswered > 0
                  ? 'Masih ada $unanswered dari $total soal yang belum dijawab.'
                  : 'Semua soal sudah dijawab.',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Kirim Jawaban'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Kembali'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HASIL QUIZ
// ============================================================

class QuizResultScreen extends StatelessWidget {
  final Quiz quiz;
  final int score;
  final int correctAnswers;
  final int totalQuestions;
  final bool passed;
  final bool autoSubmitted;

  const QuizResultScreen({
    super.key,
    required this.quiz,
    required this.score,
    required this.correctAnswers,
    required this.totalQuestions,
    required this.passed,
    required this.autoSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Quiz'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 30),
            Icon(
              passed
                  ? Icons.emoji_events
                  : Icons.sentiment_dissatisfied,
              size: 90,
              color: passed ? Colors.amber : Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              passed ? 'Selamat! Kamu Lulus' : 'Kamu Belum Lulus',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (autoSubmitted) ...[
              const SizedBox(height: 8),
              const Text(
                'Quiz dikirim otomatis karena waktu habis.',
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 32),
            Text(
              '$score',
              style: TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.bold,
                color: passed ? colors.primary : Colors.red,
              ),
            ),
            const Text('Nilai', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ResultItem(title: 'Benar', value: '$correctAnswers'),
                _ResultItem(title: 'Total', value: '$totalQuestions'),
                _ResultItem(title: 'Minimal', value: '${quiz.passingScore}'),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  // Kembali ke detail quiz; halaman tersebut menampilkan
                  // status sudah dikerjakan dan nilai sebelumnya.
                  Navigator.of(context).pop();
                },
                child: const Text('Kembali'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultItem extends StatelessWidget {
  final String title;
  final String value;

  const _ResultItem({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
