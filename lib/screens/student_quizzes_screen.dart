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
      appBar: AppBar(
        title: const Text('Quiz'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore
            .collection('quizzes')
            .where(
          'courseId',
          isEqualTo: courseId,
        )
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

          final docs =
              snapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          if (docs.isEmpty) {
            return _buildEmptyState(context);
          }

          final quizzes = <Quiz>[];

          for (final doc in docs) {
            try {
              quizzes.add(
                Quiz.fromFirestore(
                  doc.id,
                  doc.data(),
                ),
              );
            } catch (_) {
              // Lewati data quiz yang tidak valid
            }
          }

          if (quizzes.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: quizzes.length,
            separatorBuilder: (_, __) {
              return const SizedBox(height: 12);
            },
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

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 72,
              color: colorScheme.primary.withValues(
                alpha: 0.7,
              ),
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
              'Belum ada quiz untuk course ini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// QUIZ CARD
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
    final colorScheme = Theme.of(context).colorScheme;

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
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.quiz_outlined,
                  color: colorScheme.onPrimaryContainer,
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
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.timer_outlined,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${quiz.duration} menit',
                              style: const TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Lulus ${quiz.passingScore}%',
                              style: const TextStyle(
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// DETAIL QUIZ
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Quiz'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore
            .collection('quiz_questions')
            .where(
          'quizId',
          isEqualTo: quiz.id,
        )
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
                  'Gagal memuat soal.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final questions =
              snapshot.data?.docs ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          return _QuizDetailContent(
            quiz: quiz,
            courseTitle: courseTitle,
            questionCount: questions.length,
          );
        },
      ),
    );
  }
}

// ============================================================
// DETAIL CONTENT
// ============================================================

class _QuizDetailContent extends StatelessWidget {
  final Quiz quiz;
  final String courseTitle;
  final int questionCount;

  const _QuizDetailContent({
    required this.quiz,
    required this.courseTitle,
    required this.questionCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            Icons.quiz,
            size: 64,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          quiz.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          courseTitle,
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        if (quiz.description.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            quiz.description,
            style: const TextStyle(
              fontSize: 15,
            ),
          ),
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
        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: questionCount == 0
                ? null
                : () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      StudentTakeQuizScreen(
                        quiz: quiz,
                      ),
                ),
              );
            },
            icon: const Icon(
              Icons.play_arrow,
            ),
            label: const Text(
              'Mulai Quiz',
            ),
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
    );
  }
}

// ============================================================
// INFO ROW
// ============================================================

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
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 14,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(title),
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
  State<StudentTakeQuizScreen> createState() =>
      _StudentTakeQuizScreenState();
}

class _StudentTakeQuizScreenState
    extends State<StudentTakeQuizScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final Map<String, String> _answers = {};

  List<QueryDocumentSnapshot<Map<String, dynamic>>>
  _questions =
  <QueryDocumentSnapshot<Map<String, dynamic>>>[];

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

  // ============================================================
  // LOAD QUESTIONS
  // ============================================================

  Future<void> _loadQuestions() async {
    try {
      final snapshot = await _firestore
          .collection('quiz_questions')
          .where(
        'quizId',
        isEqualTo: widget.quiz.id,
      )
          .get();

      final questions = snapshot.docs.toList();

      questions.sort((a, b) {
        final aData = a.data();
        final bData = b.data();

        final dynamic aOrder =
        aData['order'];

        final dynamic bOrder =
        bData['order'];

        final int aValue =
        _toInt(aOrder);

        final int bValue =
        _toInt(bOrder);

        return aValue.compareTo(bValue);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _questions = questions;
        _remainingSeconds =
            _safeDuration(widget.quiz.duration);
        _loading = false;
      });

      if (_questions.isNotEmpty) {
        _startTimer();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memuat soal: $e',
          ),
        ),
      );
    }
  }

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }

  int _safeDuration(int value) {
    if (value <= 0) {
      return 1;
    }

    return value;
  }

  // ============================================================
  // TIMER
  // ============================================================

  void _startTimer() {
    _timerSubscription?.cancel();

    _timerSubscription = Stream.periodic(
      const Duration(seconds: 1),
          (count) => count,
    ).listen((_) {
      if (!mounted || _submitting) {
        return;
      }

      if (_remainingSeconds <= 1) {
        _timerSubscription?.cancel();
        _submitQuiz(
          autoSubmit: true,
        );
        return;
      }

      setState(() {
        _remainingSeconds--;
      });
    });
  }

  String _formatTime(int seconds) {
    final safeSeconds =
    seconds < 0 ? 0 : seconds;

    final minutes =
        safeSeconds ~/ 60;

    final remaining =
        safeSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remaining.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // ANSWER
  // ============================================================

  void _selectAnswer(String answer) {
    if (_submitting ||
        _questions.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= _questions.length) {
      return;
    }

    final questionId =
        _questions[_currentIndex].id;

    setState(() {
      _answers[questionId] = answer;
    });
  }

  // ============================================================
  // NAVIGATION QUESTION
  // ============================================================

  void _nextQuestion() {
    if (_submitting ||
        _questions.isEmpty) {
      return;
    }

    if (_currentIndex >=
        _questions.length - 1) {
      _showSubmitConfirmation();
      return;
    }

    setState(() {
      _currentIndex++;
    });
  }

  void _previousQuestion() {
    if (_submitting ||
        _currentIndex <= 0) {
      return;
    }

    setState(() {
      _currentIndex--;
    });
  }

  // ============================================================
  // SUBMIT CONFIRMATION
  // ============================================================

  Future<void> _showSubmitConfirmation() async {
    if (_submitting) {
      return;
    }

    final unanswered =
        _questions.length -
            _answers.length;

    final shouldSubmit =
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _SubmitQuizPage(
          unanswered: unanswered,
          total: _questions.length,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (shouldSubmit == true) {
      await _submitQuiz();
    }
  }

  // ============================================================
  // SUBMIT QUIZ
  // ============================================================

  Future<void> _submitQuiz({
    bool autoSubmit = false,
  }) async {
    if (_submitting) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = true;
    });

    _timerSubscription?.cancel();

    try {
      int correctAnswers = 0;
      int totalPoints = 0;
      int earnedPoints = 0;

      final Map<String, String> savedAnswers =
      <String, String>{};

      for (final doc in _questions) {
        final data = doc.data();

        final String correctAnswer =
        (data['correctAnswer'] ?? '')
            .toString()
            .trim();

        final int points =
        _readPoints(data['points']);

        totalPoints += points;

        final String answer =
            _answers[doc.id] ?? '';

        savedAnswers[doc.id] = answer;

        if (answer == correctAnswer) {
          correctAnswers++;
          earnedPoints += points;
        }
      }

      final int score;

      if (totalPoints <= 0) {
        score = 0;
      } else {
        score =
            ((earnedPoints /
                totalPoints) *
                100)
                .round();
      }

      final bool passed =
          score >= widget.quiz.passingScore;

      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          'User belum login.',
        );
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('quiz_results')
          .doc(widget.quiz.id)
          .set(
        {
          'quizId': widget.quiz.id,
          'courseId': widget.quiz.courseId,
          'score': score,
          'totalQuestions':
          _questions.length,
          'correctAnswers':
          correctAnswers,
          'passed': passed,
          'answers': savedAnswers,
          'submittedAt':
          FieldValue.serverTimestamp(),
          'updatedAt':
          FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => QuizResultScreen(
            quiz: widget.quiz,
            score: score,
            correctAnswers:
            correctAnswers,
            totalQuestions:
            _questions.length,
            passed: passed,
            autoSubmitted:
            autoSubmit,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _submitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengirim quiz: $e',
          ),
        ),
      );
    }
  }

  int _readPoints(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    final parsed =
    int.tryParse(
      value?.toString() ?? '',
    );

    return parsed ?? 10;
  }

  // ============================================================
  // OPTIONS
  // ============================================================

  Map<String, String> _readOptions(
      dynamic rawOptions,
      ) {
    final Map<String, String> result =
    <String, String>{};

    if (rawOptions is Map) {
      rawOptions.forEach(
            (key, value) {
          if (key == null) {
            return;
          }

          final String optionKey =
          key.toString();

          final String optionValue =
              value?.toString() ?? '';

          result[optionKey] =
              optionValue;
        },
      );
    }

    return result;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.quiz.title),
        ),
        body: const Center(
          child: Text(
            'Tidak ada soal.',
          ),
        ),
      );
    }

    if (_currentIndex < 0 ||
        _currentIndex >= _questions.length) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Terjadi kesalahan pada soal.',
          ),
        ),
      );
    }

    final question =
    _questions[_currentIndex];

    final data = question.data();

    final String questionText =
    (data['question'] ?? '')
        .toString();

    final Map<String, String> options =
    _readOptions(
      data['options'],
    );

    final String? selectedAnswer =
    _answers[question.id];

    final double progress =
        (_currentIndex + 1) /
            _questions.length;

    final colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz.title),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(
              right: 16,
            ),
            child: Center(
              child: Text(
                _formatTime(
                  _remainingSeconds,
                ),
                style: TextStyle(
                  fontWeight:
                  FontWeight.bold,
                  color:
                  _remainingSeconds <= 60
                      ? Colors.red
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Soal ${_currentIndex + 1} '
                      'dari ${_questions.length}',
                  style: const TextStyle(
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
                Text(
                  '${_answers.length}/${_questions.length} terjawab',
                  style: TextStyle(
                    color:
                    colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding:
              const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                20,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 0,
                    child: Padding(
                      padding:
                      const EdgeInsets.all(
                        18,
                      ),
                      child: Text(
                        questionText.isEmpty
                            ? 'Pertanyaan tidak tersedia.'
                            : questionText,
                        style:
                        const TextStyle(
                          fontSize: 18,
                          fontWeight:
                          FontWeight.w600,
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
              padding:
              const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (_currentIndex > 0)
                    Expanded(
                      child:
                      OutlinedButton(
                        onPressed:
                        _submitting
                            ? null
                            : _previousQuestion,
                        child:
                        const Text(
                          'Sebelumnya',
                        ),
                      ),
                    ),
                  if (_currentIndex > 0)
                    const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed:
                      _submitting
                          ? null
                          : _nextQuestion,
                      child: Text(
                        _currentIndex ==
                            _questions.length -
                                1
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
    );
  }

  List<Widget> _buildOptionWidgets(
      BuildContext context,
      Map<String, String> options,
      String? selectedAnswer,
      ) {
    final letters =
    <String>['A', 'B', 'C', 'D'];

    return letters.map(
          (letter) {
        final String optionText =
            options[letter] ?? '';

        final bool selected =
            selectedAnswer == letter;

        return Padding(
          padding:
          const EdgeInsets.only(
            bottom: 10,
          ),
          child: InkWell(
            onTap: _submitting
                ? null
                : () {
              _selectAnswer(
                letter,
              );
            },
            borderRadius:
            BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding:
              const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
                border: Border.all(
                  color: selected
                      ? Theme.of(context)
                      .colorScheme
                      .primary
                      : Theme.of(context)
                      .colorScheme
                      .outline,
                  width:
                  selected ? 2 : 1,
                ),
                color: selected
                    ? Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment:
                    Alignment.center,
                    decoration:
                    BoxDecoration(
                      shape:
                      BoxShape.circle,
                      color: selected
                          ? Theme.of(
                        context,
                      )
                          .colorScheme
                          .primary
                          : Theme.of(
                        context,
                      )
                          .colorScheme
                          .surfaceContainerHighest,
                    ),
                    child: Text(
                      letter,
                      style: TextStyle(
                        fontWeight:
                        FontWeight.bold,
                        color: selected
                            ? Theme.of(
                          context,
                        )
                            .colorScheme
                            .onPrimary
                            : null,
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
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(
                        context,
                      )
                          .colorScheme
                          .primary,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ).toList();
  }

  @override
  void dispose() {
    _timerSubscription?.cancel();
    super.dispose();
  }
}

// ============================================================
// KONFIRMASI SUBMIT
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
      appBar: AppBar(
        title: const Text(
          'Kirim Quiz',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.assignment_turned_in_outlined,
              size: 72,
            ),
            const SizedBox(height: 24),
            const Text(
              'Kirim jawaban?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
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
                onPressed: () {
                  Navigator.of(context).pop(
                    true,
                  );
                },
                child: const Text(
                  'Kirim Jawaban',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop(
                    false,
                  );
                },
                child: const Text(
                  'Kembali',
                ),
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
    final colorScheme =
        Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hasil Quiz',
        ),
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
              color: passed
                  ? Colors.amber
                  : Colors.grey,
            ),
            const SizedBox(height: 24),
            Text(
              passed
                  ? 'Selamat! Kamu Lulus'
                  : 'Kamu Belum Lulus',
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
                color: passed
                    ? colorScheme.primary
                    : Colors.red,
              ),
            ),
            const Text(
              'Nilai',
              style: TextStyle(
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment:
              MainAxisAlignment.spaceEvenly,
              children: [
                _ResultItem(
                  title: 'Benar',
                  value:
                  '$correctAnswers',
                ),
                _ResultItem(
                  title: 'Total',
                  value:
                  '$totalQuestions',
                ),
                _ResultItem(
                  title: 'Minimal',
                  value:
                  '${quiz.passingScore}',
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Kembali',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// RESULT ITEM
// ============================================================

class _ResultItem extends StatelessWidget {
  final String title;
  final String value;

  const _ResultItem({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color:
            colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}