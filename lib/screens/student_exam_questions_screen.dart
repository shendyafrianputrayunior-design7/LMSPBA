import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'student_exam_result_screen.dart';

class StudentExamQuestionsScreen extends StatefulWidget {
  final String examId;
  final Map<String, dynamic> examData;

  const StudentExamQuestionsScreen({
    super.key,
    required this.examId,
    required this.examData,
  });

  @override
  State<StudentExamQuestionsScreen> createState() =>
      _StudentExamQuestionsScreenState();
}

class _StudentExamQuestionsScreenState
    extends State<StudentExamQuestionsScreen> {
  final PageController _pageController = PageController();

  List<Map<String, dynamic>> _questions = [];
  final Map<String, String> _answers = {};

  bool _loading = true;
  bool _submitting = false;

  int _currentIndex = 0;
  int _remainingSeconds = 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('exam_questions')
          .where(
        'examId',
        isEqualTo: widget.examId,
      )
          .get();

      final questions = snapshot.docs.map((doc) {
        final data = doc.data();

        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      questions.sort((a, b) {
        final aOrder = _toInt(a['order']);
        final bOrder = _toInt(b['order']);

        return aOrder.compareTo(bOrder);
      });

      final duration = _toInt(
        widget.examData['duration'],
      );

      if (!mounted) return;

      setState(() {
        _questions = questions;
        _remainingSeconds = duration > 0 ? duration * 60 : 0;
        _loading = false;
      });

      if (duration > 0) {
        _startTimer();
      }
    } catch (e) {
      if (!mounted) return;

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

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_remainingSeconds <= 0) {
          timer.cancel();
          _submitExam(autoSubmit: true);
          return;
        }

        setState(() {
          _remainingSeconds--;
        });
      },
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(
      (value ?? '0').toString(),
    ) ??
        0;
  }

  Map<String, dynamic> _getOptions(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return {};
  }

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${secs.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')}';
  }

  void _selectAnswer(
      String questionId,
      String answer,
      ) {
    setState(() {
      _answers[questionId] = answer;
    });
  }

  void _nextQuestion() {
    if (_currentIndex >= _questions.length - 1) {
      _showSubmitConfirmation();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _previousQuestion() {
    if (_currentIndex <= 0) {
      return;
    }

    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _showSubmitConfirmation() async {
    final unanswered = _questions.length - _answers.length;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Kumpulkan Ujian?'),
          content: Text(
            unanswered > 0
                ? 'Masih ada $unanswered soal yang belum dijawab. '
                'Apakah kamu yakin ingin mengumpulkan ujian?'
                : 'Semua soal sudah dijawab. '
                'Apakah kamu yakin ingin mengumpulkan ujian?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Kembali'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Kumpulkan'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      await _submitExam();
    }
  }

  Future<void> _submitExam({
    bool autoSubmit = false,
  }) async {
    if (_submitting) {
      return;
    }

    _submitting = true;
    _timer?.cancel();

    if (mounted) {
      setState(() {});
    }

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          'Pengguna belum login.',
        );
      }

      int correctAnswers = 0;
      int totalPoints = 0;
      int earnedPoints = 0;

      final answerData = <String, String>{};

      for (final question in _questions) {
        final questionId =
        (question['id'] ?? '').toString();

        final selectedAnswer =
            _answers[questionId] ?? '';

        final correctAnswer =
        (question['correctAnswer'] ?? '')
            .toString()
            .trim()
            .toUpperCase();

        final points = _toInt(
          question['points'],
        );

        totalPoints += points;

        if (selectedAnswer.isNotEmpty) {
          answerData[questionId] = selectedAnswer;
        }

        if (selectedAnswer.toUpperCase() ==
            correctAnswer) {
          correctAnswers++;
          earnedPoints += points;
        }
      }

      final score = totalPoints > 0
          ? (earnedPoints / totalPoints) * 100
          : 0.0;

      final passingScore = _toInt(
        widget.examData['passingScore'],
      );

      final passed = passingScore > 0
          ? score >= passingScore
          : true;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('exam_results')
          .doc(widget.examId)
          .set({
        'examId': widget.examId,
        'studentId': user.uid,
        'score': score,
        'earnedPoints': earnedPoints,
        'totalPoints': totalPoints,
        'correctAnswers': correctAnswers,
        'totalQuestions': _questions.length,
        'passingScore': passingScore,
        'passed': passed,
        'answers': answerData,
        'submittedAt': FieldValue.serverTimestamp(),
        'autoSubmitted': autoSubmit,
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StudentExamResultScreen(
            examId: widget.examId,
            examData: widget.examData,
            score: score,
            earnedPoints: earnedPoints,
            totalPoints: totalPoints,
            correctAnswers: correctAnswers,
            totalQuestions: _questions.length,
            passingScore: passingScore,
            passed: passed,
          ),
        ),
      );
    } catch (e) {
      _submitting = false;

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengumpulkan ujian: $e',
          ),
        ),
      );
    }
  }

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
          title: const Text('Ujian'),
        ),
        body: const Center(
          child: Text(
            'Tidak ada soal pada ujian ini.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.examData['title']?.toString() ?? 'Ujian',
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _questions.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return _buildQuestion(
                  _questions[index],
                  index,
                );
              },
            ),
          ),
          _buildBottomNavigation(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final progress = (_currentIndex + 1) /
        _questions.length;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        14,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Soal ${_currentIndex + 1} '
                    'dari ${_questions.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_remainingSeconds > 0)
                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 19,
                      color: _remainingSeconds <= 60
                          ? Colors.red
                          : null,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTime(_remainingSeconds),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _remainingSeconds <= 60
                            ? Colors.red
                            : null,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(
      Map<String, dynamic> question,
      int index,
      ) {
    final questionText =
    (question['question'] ?? '').toString();

    final options = _getOptions(
      question['options'],
    );

    final questionId =
    (question['id'] ?? '').toString();

    final selectedAnswer =
    _answers[questionId];

    final optionKeys = ['A', 'B', 'C', 'D'];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                questionText,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ...optionKeys.map(
              (key) {
            final optionText =
            (options[key] ?? '').toString();

            if (optionText.isEmpty) {
              return const SizedBox.shrink();
            }

            final selected = selectedAnswer == key;

            return Padding(
              padding: const EdgeInsets.only(
                bottom: 12,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _submitting
                    ? null
                    : () {
                  _selectAnswer(
                    questionId,
                    key,
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(
                    milliseconds: 180,
                  ),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? Theme.of(context)
                          .colorScheme
                          .primary
                          : Colors.grey.shade300,
                      width: selected ? 2 : 1,
                    ),
                    color: selected
                        ? Theme.of(context)
                        .colorScheme
                        .primary
                        .withOpacity(0.08)
                        : null,
                  ),
                  child: Row(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected
                              ? Theme.of(context)
                              .colorScheme
                              .primary
                              : Colors.grey.shade200,
                        ),
                        child: Text(
                          key,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selected
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Padding(
                          padding:
                          const EdgeInsets.only(top: 7),
                          child: Text(
                            optionText,
                            style: const TextStyle(
                              fontSize: 15,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    final isFirst = _currentIndex == 0;
    final isLast =
        _currentIndex == _questions.length - 1;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            if (!isFirst)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _submitting
                      ? null
                      : _previousQuestion,
                  icon: const Icon(
                    Icons.arrow_back,
                  ),
                  label: const Text('Sebelumnya'),
                ),
              ),
            if (!isFirst && !isLast)
              const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _submitting
                    ? null
                    : _nextQuestion,
                icon: Icon(
                  isLast
                      ? Icons.check_rounded
                      : Icons.arrow_forward,
                ),
                label: Text(
                  isLast
                      ? 'Kumpulkan'
                      : 'Berikutnya',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}