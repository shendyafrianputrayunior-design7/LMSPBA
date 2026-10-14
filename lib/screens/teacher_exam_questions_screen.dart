import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherExamQuestionsScreen extends StatefulWidget {
  final String examId;
  final String examTitle;

  const TeacherExamQuestionsScreen({
    super.key,
    required this.examId,
    required this.examTitle,
  });

  @override
  State<TeacherExamQuestionsScreen> createState() =>
      _TeacherExamQuestionsScreenState();
}

class _TeacherExamQuestionsScreenState
    extends State<TeacherExamQuestionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? get _teacherId => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    final teacherId = _teacherId;

    if (teacherId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Soal Ujian'),
        ),
        body: const Center(
          child: Text(
            'Silakan login terlebih dahulu.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Soal Ujian'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('exam_questions')
            .where('examId', isEqualTo: widget.examId)
            .where('teacherId', isEqualTo: teacherId)
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
                  'Gagal mengambil soal ujian.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          final sortedDocs = [...docs];

          sortedDocs.sort((a, b) {
            final orderA = _parseInt(a.data()['order']);
            final orderB = _parseInt(b.data()['order']);
            return orderA.compareTo(orderB);
          });

          if (sortedDocs.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () async {
              await Future<void>.delayed(
                const Duration(milliseconds: 300),
              );
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: sortedDocs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final doc = sortedDocs[index];
                final data = doc.data();

                return _QuestionCard(
                  number: index + 1,
                  questionId: doc.id,
                  question: (data['question'] ?? '').toString(),
                  options: _readOptions(data),
                  correctAnswer:
                  (data['correctAnswer'] ?? '').toString(),
                  points: _parseInt(data['points']),
                  onEdit: () {
                    _showQuestionForm(
                      questionId: doc.id,
                      questionData: data,
                    );
                  },
                  onDelete: () {
                    _deleteQuestion(
                      doc.id,
                      (data['question'] ?? '').toString(),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: teacherId == null ? null : _showQuestionForm,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Soal'),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 76,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 18),
            Text(
              'Belum ada soal',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambahkan soal untuk ujian "${widget.examTitle}".',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: _showQuestionForm,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Soal'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FORM SOAL
  // ============================================================

  Future<void> _showQuestionForm({
    String? questionId,
    Map<String, dynamic>? questionData,
  }) async {
    final teacherId = _teacherId;

    if (teacherId == null) {
      _showMessage('Silakan login terlebih dahulu.');
      return;
    }

    if (!await _verifyExamOwnership(teacherId)) {
      if (mounted) {
        _showMessage('Ujian tidak ditemukan atau bukan milik Anda.');
      }
      return;
    }

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _QuestionFormDialog(
          questionId: questionId,
          questionData: questionData,
          examId: widget.examId,
          teacherId: teacherId,
          firestore: _firestore,
          getNextOrder: _getNextOrder,
        );
      },
    );

    if (!mounted) return;

    if (result == true) {
      _showMessage(
        questionId == null
            ? 'Soal berhasil ditambahkan.'
            : 'Soal berhasil diperbarui.',
      );
    }
  }

  // ============================================================
  // VERIFY EXAM OWNERSHIP
  // ============================================================

  Future<bool> _verifyExamOwnership(String teacherId) async {
    try {
      final exam = await _firestore
          .collection('exams')
          .doc(widget.examId)
          .get();

      if (!exam.exists) return false;

      final data = exam.data();
      if (data == null) return false;

      return data['teacherId']?.toString() == teacherId;
    } catch (e) {
      debugPrint('Gagal memeriksa kepemilikan ujian: $e');
      return false;
    }
  }

  // ============================================================
  // NEXT ORDER
  // ============================================================

  int _getNextOrder(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    int maxOrder = 0;

    for (final doc in docs) {
      final order = _parseInt(doc.data()['order']);
      if (order > maxOrder) maxOrder = order;
    }

    return maxOrder + 1;
  }

  // ============================================================
  // DELETE QUESTION
  // ============================================================

  Future<void> _deleteQuestion(
      String questionId,
      String question,
      ) async {
    final teacherId = _teacherId;

    if (teacherId == null) {
      _showMessage('Silakan login terlebih dahulu.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Soal?'),
          content: Text(
            'Soal berikut akan dihapus secara permanen:\n\n'
                '"${question.isEmpty ? 'Soal ini' : question}"\n\n'
                'Tindakan ini tidak dapat dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final questionRef =
      _firestore.collection('exam_questions').doc(questionId);

      final questionSnapshot = await questionRef.get();

      if (!questionSnapshot.exists) {
        _showMessage('Soal sudah tidak tersedia.');
        return;
      }

      final questionData = questionSnapshot.data();

      if (questionData == null ||
          questionData['examId']?.toString() != widget.examId ||
          questionData['teacherId']?.toString() != teacherId) {
        _showMessage('Anda tidak memiliki akses untuk menghapus soal ini.');
        return;
      }

      if (!await _verifyExamOwnership(teacherId)) {
        _showMessage('Anda tidak memiliki akses ke ujian ini.');
        return;
      }

      await questionRef.delete();

      if (!mounted) return;
      _showMessage('Soal berhasil dihapus.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Gagal menghapus soal:\n$e');
    }
  }

  // ============================================================
  // READ OPTIONS
  // ============================================================

  Map<String, String> _readOptions(Map<String, dynamic> data) {
    final raw = data['options'];

    if (raw is Map) {
      return {
        'A': (raw['A'] ?? '').toString(),
        'B': (raw['B'] ?? '').toString(),
        'C': (raw['C'] ?? '').toString(),
        'D': (raw['D'] ?? '').toString(),
      };
    }

    return {
      'A': '',
      'B': '',
      'C': '',
      'D': '',
    };
  }

  // ============================================================
  // PARSE INT
  // ============================================================

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// ==================================================================
// QUESTION FORM DIALOG
// ==================================================================

class _QuestionFormDialog extends StatefulWidget {
  final String? questionId;
  final Map<String, dynamic>? questionData;
  final String examId;
  final String teacherId;
  final FirebaseFirestore firestore;

  final int Function(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) getNextOrder;

  const _QuestionFormDialog({
    required this.questionId,
    required this.questionData,
    required this.examId,
    required this.teacherId,
    required this.firestore,
    required this.getNextOrder,
  });

  @override
  State<_QuestionFormDialog> createState() =>
      _QuestionFormDialogState();
}

class _QuestionFormDialogState extends State<_QuestionFormDialog> {
  late final TextEditingController _questionController;
  late final TextEditingController _optionAController;
  late final TextEditingController _optionBController;
  late final TextEditingController _optionCController;
  late final TextEditingController _optionDController;
  late final TextEditingController _pointsController;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late String _correctAnswer;
  bool _saving = false;

  bool get _isEdit => widget.questionId != null;

  @override
  void initState() {
    super.initState();

    _questionController = TextEditingController(
      text: (widget.questionData?['question'] ?? '').toString(),
    );

    _optionAController = TextEditingController(text: _getOption('A'));
    _optionBController = TextEditingController(text: _getOption('B'));
    _optionCController = TextEditingController(text: _getOption('C'));
    _optionDController = TextEditingController(text: _getOption('D'));

    final existingPoints = _parseInt(widget.questionData?['points']);

    _pointsController = TextEditingController(
      text: existingPoints > 0 ? existingPoints.toString() : '',
    );

    final answer =
    (widget.questionData?['correctAnswer'] ?? 'A').toString();

    _correctAnswer = ['A', 'B', 'C', 'D'].contains(answer) ? answer : 'A';
  }

  @override
  void dispose() {
    _questionController.dispose();
    _optionAController.dispose();
    _optionBController.dispose();
    _optionCController.dispose();
    _optionDController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Soal' : 'Tambah Soal'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _questionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Pertanyaan',
                    hintText: 'Masukkan pertanyaan ujian',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Icon(Icons.help_outline),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Pertanyaan wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildOptionField(
                  controller: _optionAController,
                  label: 'A',
                ),
                const SizedBox(height: 12),
                _buildOptionField(
                  controller: _optionBController,
                  label: 'B',
                ),
                const SizedBox(height: 12),
                _buildOptionField(
                  controller: _optionCController,
                  label: 'C',
                ),
                const SizedBox(height: 12),
                _buildOptionField(
                  controller: _optionDController,
                  label: 'D',
                ),
                const SizedBox(height: 18),
                DropdownButtonFormField<String>(
                  initialValue: _correctAnswer,
                  decoration: const InputDecoration(
                    labelText: 'Jawaban Benar',
                    prefixIcon: Icon(Icons.check_circle_outline),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'A', child: Text('Opsi A')),
                    DropdownMenuItem(value: 'B', child: Text('Opsi B')),
                    DropdownMenuItem(value: 'C', child: Text('Opsi C')),
                    DropdownMenuItem(value: 'D', child: Text('Opsi D')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) {
                    if (value == null) return;
                    setState(() => _correctAnswer = value);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pointsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Poin Soal',
                    hintText: 'Contoh: 10',
                    prefixIcon: Icon(Icons.stars_outlined),
                  ),
                  validator: (value) {
                    final points = int.tryParse(value?.trim() ?? '');
                    if (points == null || points <= 0) {
                      return 'Poin harus lebih dari 0';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _saveQuestion,
          child: _saving
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : Text(_isEdit ? 'Simpan' : 'Tambah'),
        ),
      ],
    );
  }

  // ============================================================
  // OPTION FIELD
  // ============================================================

  Widget _buildOptionField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Opsi $label',
        prefixIcon: Padding(
          padding: const EdgeInsets.all(8),
          child: CircleAvatar(
            radius: 12,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Opsi $label wajib diisi';
        }
        return null;
      },
    );
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) return;

    final points = int.tryParse(_pointsController.text.trim());
    if (points == null || points <= 0) return;

    setState(() => _saving = true);

    try {
      final examSnapshot = await widget.firestore
          .collection('exams')
          .doc(widget.examId)
          .get();

      if (!examSnapshot.exists) {
        throw Exception('Dokumen ujian tidak ditemukan.');
      }

      final examData = examSnapshot.data();

      if (examData == null ||
          examData['teacherId']?.toString() != widget.teacherId) {
        throw Exception('Anda tidak memiliki akses ke ujian ini.');
      }

      final questionCollection =
      widget.firestore.collection('exam_questions');

      final existingSnapshot = await questionCollection
          .where('examId', isEqualTo: widget.examId)
          .where('teacherId', isEqualTo: widget.teacherId)
          .get();

      int order;

      if (_isEdit) {
        final existingQuestion = await questionCollection
            .doc(widget.questionId)
            .get();

        if (!existingQuestion.exists) {
          throw Exception('Soal yang akan diedit tidak ditemukan.');
        }

        final existingData = existingQuestion.data();

        if (existingData == null ||
            existingData['examId']?.toString() != widget.examId ||
            existingData['teacherId']?.toString() != widget.teacherId) {
          throw Exception('Anda tidak memiliki akses ke soal ini.');
        }

        order = _parseInt(widget.questionData?['order']);

        if (order <= 0) {
          order = widget.getNextOrder(existingSnapshot.docs);
        }
      } else {
        order = widget.getNextOrder(existingSnapshot.docs);
      }

      final data = <String, dynamic>{
        'teacherId': widget.teacherId,
        'examId': widget.examId,
        'question': _questionController.text.trim(),
        'options': {
          'A': _optionAController.text.trim(),
          'B': _optionBController.text.trim(),
          'C': _optionCController.text.trim(),
          'D': _optionDController.text.trim(),
        },
        'correctAnswer': _correctAnswer,
        'points': points,
        'order': order,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!_isEdit) {
        data['createdAt'] = FieldValue.serverTimestamp();

        await questionCollection.add(data);
      } else {
        await questionCollection.doc(widget.questionId).update(data);
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, stackTrace) {
      debugPrint('ERROR SIMPAN SOAL: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() => _saving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan soal:\n$e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // ============================================================
  // GET OPTION
  // ============================================================

  String _getOption(String option) {
    final data = widget.questionData;
    if (data == null) return '';

    final raw = data['options'];

    if (raw is Map) {
      return (raw[option] ?? '').toString();
    }

    return '';
  }

  // ============================================================
  // PARSE INT
  // ============================================================

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

// ================================================================
// QUESTION CARD
// ================================================================

class _QuestionCard extends StatelessWidget {
  final int number;
  final String questionId;
  final String question;
  final Map<String, String> options;
  final String correctAnswer;
  final int points;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _QuestionCard({
    required this.number,
    required this.questionId,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.points,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$number',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    question.isEmpty ? 'Pertanyaan kosong' : question,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Menu Soal',
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
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
            const SizedBox(height: 16),
            _OptionRow(
              label: 'A',
              text: options['A'] ?? '',
              isCorrect: correctAnswer == 'A',
            ),
            const SizedBox(height: 8),
            _OptionRow(
              label: 'B',
              text: options['B'] ?? '',
              isCorrect: correctAnswer == 'B',
            ),
            const SizedBox(height: 8),
            _OptionRow(
              label: 'C',
              text: options['C'] ?? '',
              isCorrect: correctAnswer == 'C',
            ),
            const SizedBox(height: 8),
            _OptionRow(
              label: 'D',
              text: options['D'] ?? '',
              isCorrect: correctAnswer == 'D',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
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
                        Icons.stars_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$points poin',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (correctAnswer.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Jawaban: $correctAnswer',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
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
// OPTION ROW
// ================================================================

class _OptionRow extends StatelessWidget {
  final String label;
  final String text;
  final bool isCorrect;

  const _OptionRow({
    required this.label,
    required this.text,
    required this.isCorrect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final backgroundColor = isCorrect
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;

    final foregroundColor = isCorrect
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: isCorrect
            ? Border.all(color: theme.colorScheme.primary)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isCorrect
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isCorrect
                    ? theme.colorScheme.onPrimary
                    : foregroundColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                text.isEmpty ? 'Belum diisi' : text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight:
                  isCorrect ? FontWeight.w600 : FontWeight.normal,
                  color: foregroundColor,
                ),
              ),
            ),
          ),
          if (isCorrect)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Icon(
                Icons.check_circle,
                size: 19,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}