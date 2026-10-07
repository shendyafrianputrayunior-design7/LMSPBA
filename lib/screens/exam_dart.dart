import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ExamScreen extends StatefulWidget {
  const ExamScreen({super.key});

  @override
  State<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<ExamScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _className = '';
  bool _loading = true;
  bool _error = false;
  String _errorMessage = '';

  List<Map<String, dynamic>> _exams = [];

  @override
  void initState() {
    super.initState();
    _loadExams();
  }

  Future<void> _loadExams() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = true;
        _errorMessage = 'Sesi pengguna tidak ditemukan.';
      });
      return;
    }

    try {
      // ============================
      // AMBIL DATA SISWA
      // ============================

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('Data siswa belum tersedia.');
      }

      final userData = userDoc.data() ?? {};
      final classId = userData['classId']?.toString() ?? '';

      if (classId.isEmpty) {
        if (!mounted) return;

        setState(() {
          _loading = false;
          _error = true;
          _errorMessage = 'Data kelas siswa belum tersedia.';
        });
        return;
      }

      // ============================
      // AMBIL NAMA KELAS
      // ============================

      String className = classId;

      final classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();

      if (classDoc.exists) {
        final classData = classDoc.data() ?? {};
        className = classData['name']?.toString() ?? classId;
      }

      // ============================
      // AMBIL DATA UJIAN
      // ============================

      final snapshot = await _firestore
          .collection('exams')
          .where('classId', isEqualTo: classId)
          .get();

      final exams = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _className = className;
        _exams = exams;
        _loading = false;
        _error = false;
      });
    } catch (e) {
      debugPrint('Gagal mengambil data ujian: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = true;
        _errorMessage = 'Gagal mengambil data ujian.';
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    await _loadExams();
  }

  Future<void> _openExam(Map<String, dynamic> exam) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamDetailScreen(
          exam: exam,
        ),
      ),
    );

    if (mounted) {
      _loadExams();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Ujian',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error) {
      return _buildError(context);
    }

    if (_exams.isEmpty) {
      return _buildEmpty(context);
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _buildHeader(context),
          const SizedBox(height: 20),
          _buildSummary(context),
          const SizedBox(height: 24),
          Text(
            'Ujian Tersedia',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          ..._exams.map(
                (exam) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildExamCard(context, exam),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: colorScheme.onPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.assignment_rounded,
              color: colorScheme.onPrimary,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ujian Sekolah',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _className,
                  style: TextStyle(
                    color: colorScheme.onPrimary.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: _summaryCard(
            context,
            Icons.assignment_outlined,
            '${_exams.length}',
            'Ujian',
            colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _summaryCard(
            context,
            Icons.school_outlined,
            _className,
            'Kelas',
            colorScheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(
      BuildContext context,
      IconData icon,
      String value,
      String label,
      Color color,
      ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EXAM CARD
  // ============================================================

  Widget _buildExamCard(
      BuildContext context,
      Map<String, dynamic> exam,
      ) {
    final colorScheme = Theme.of(context).colorScheme;

    final title = exam['title']?.toString() ?? 'Ujian Tanpa Judul';
    final subject = exam['subject']?.toString() ?? '-';
    final description = exam['description']?.toString() ?? '';
    final date = exam['date']?.toString() ?? '-';
    final duration = exam['duration']?.toString() ?? '0';

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openExam(exam),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.assignment_rounded,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subject,
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _infoItem(
                    context,
                    Icons.timer_outlined,
                    '$duration menit',
                  ),
                  _infoItem(
                    context,
                    Icons.calendar_today_outlined,
                    date,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoItem(
      BuildContext context,
      IconData icon,
      String text,
      ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.assignment_outlined,
            size: 72,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 20),
          Text(
            'Belum Ada Ujian',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Belum ada ujian yang tersedia untuk kelas $_className.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 18),
            Text(
              'Data Ujian Tidak Dapat Dimuat',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DETAIL UJIAN
// ============================================================================

class ExamDetailScreen extends StatefulWidget {
  final Map<String, dynamic> exam;

  const ExamDetailScreen({
    super.key,
    required this.exam,
  });

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  bool _starting = false;

  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final examId = widget.exam['id']?.toString() ?? '';

      final snapshot = await _firestore
          .collection('exam_questions')
          .where('examId', isEqualTo: examId)
          .get();

      final questions = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _questions = questions;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Gagal mengambil soal ujian: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _startExam() async {
    if (_questions.isEmpty) return;

    setState(() {
      _starting = true;
    });

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExamPlayScreen(
          exam: widget.exam,
          questions: _questions,
        ),
      ),
    );

    if (!mounted) return;

    setState(() {
      _starting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final title = widget.exam['title']?.toString() ?? 'Ujian';
    final subject = widget.exam['subject']?.toString() ?? '-';
    final description = widget.exam['description']?.toString() ?? '-';
    final duration = widget.exam['duration']?.toString() ?? '0';
    final date = widget.exam['date']?.toString() ?? '-';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Ujian'),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.assignment_rounded,
                  size: 42,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subject,
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _detailItem(
            context,
            Icons.description_outlined,
            'Deskripsi',
            description,
          ),
          _detailItem(
            context,
            Icons.timer_outlined,
            'Durasi',
            '$duration menit',
          ),
          _detailItem(
            context,
            Icons.calendar_today_outlined,
            'Tanggal',
            date,
          ),
          _detailItem(
            context,
            Icons.help_outline_rounded,
            'Jumlah Soal',
            '${_questions.length} soal',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _starting ? null : _startExam,
            icon: _starting
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(
              _questions.isEmpty
                  ? 'Soal Belum Tersedia'
                  : 'Mulai Ujian',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailItem(
      BuildContext context,
      IconData icon,
      String title,
      String value,
      ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// KERJAKAN UJIAN
// ============================================================================

class ExamPlayScreen extends StatefulWidget {
  final Map<String, dynamic> exam;
  final List<Map<String, dynamic>> questions;

  const ExamPlayScreen({
    super.key,
    required this.exam,
    required this.questions,
  });

  @override
  State<ExamPlayScreen> createState() => _ExamPlayScreenState();
}

class _ExamPlayScreenState extends State<ExamPlayScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _currentQuestion = 0;
  bool _submitting = false;

  final Map<int, String> _answers = {};

  @override
  Widget build(BuildContext context) {
    final question = widget.questions[_currentQuestion];

    final questionText =
        question['question']?.toString() ?? '';

    final options = List<String>.from(
      question['options'] ?? [],
    );

    final selectedAnswer = _answers[_currentQuestion];

    final progress =
        (_currentQuestion + 1) / widget.questions.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.exam['title']?.toString() ?? 'Ujian',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: 5,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Soal ${_currentQuestion + 1} dari ${widget.questions.length}',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    questionText,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ...options.asMap().entries.map(
                        (entry) {
                      final index = entry.key;
                      final option = entry.value;
                      final selected =
                          selectedAnswer == option;

                      return Padding(
                        padding:
                        const EdgeInsets.only(bottom: 12),
                        child: _buildOption(
                          context,
                          index,
                          option,
                          selected,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            _buildNavigation(context),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
      BuildContext context,
      int index,
      String option,
      bool selected,
      ) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        setState(() {
          _answers[_currentQuestion] = option;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected
                    ? colorScheme.primary
                    : colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Text(
                String.fromCharCode(65 + index),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                option,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle_rounded,
                color: colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation(BuildContext context) {
    final isLast =
        _currentQuestion == widget.questions.length - 1;

    final hasAnswer =
    _answers.containsKey(_currentQuestion);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          if (_currentQuestion > 0)
            OutlinedButton(
              onPressed: () {
                setState(() {
                  _currentQuestion--;
                });
              },
              child: const Icon(Icons.arrow_back_rounded),
            ),
          if (_currentQuestion > 0)
            const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: hasAnswer
                  ? () {
                if (isLast) {
                  _submitExam();
                } else {
                  setState(() {
                    _currentQuestion++;
                  });
                }
              }
                  : null,
              child: Text(
                isLast
                    ? 'Selesai & Kirim'
                    : 'Soal Berikutnya',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _submitExam() async {
    if (_submitting) return;

    setState(() {
      _submitting = true;
    });

    try {
      int correct = 0;

      for (int i = 0; i < widget.questions.length; i++) {
        final question = widget.questions[i];

        final correctAnswer =
            question['answer']?.toString() ?? '';

        final userAnswer =
            _answers[i] ?? '';

        if (userAnswer == correctAnswer) {
          correct++;
        }
      }

      final total = widget.questions.length;

      final score = total == 0
          ? 0
          : ((correct / total) * 100).round();

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await _firestore.collection('exam_results').add({
          'userId': user.uid,
          'examId': widget.exam['id'],
          'classId': widget.exam['classId'],
          'subject': widget.exam['subject'],
          'title': widget.exam['title'],
          'correct': correct,
          'total': total,
          'score': score,
          'submittedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            title: const Text('Ujian Selesai'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  '$score',
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Nilai kamu'),
                const SizedBox(height: 12),
                Text(
                  '$correct dari $total jawaban benar',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Selesai'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      debugPrint('Gagal menyimpan hasil ujian: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gagal menyimpan hasil ujian.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }
}