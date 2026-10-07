import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/quiz.dart';

class TeacherQuizQuestionsScreen extends StatefulWidget {
  final Quiz quiz;

  const TeacherQuizQuestionsScreen({
    super.key,
    required this.quiz,
  });

  @override
  State<TeacherQuizQuestionsScreen> createState() =>
      _TeacherQuizQuestionsScreenState();
}

class _TeacherQuizQuestionsScreenState
    extends State<TeacherQuizQuestionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = false;

  Future<void> _addQuestion() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _AddQuestionPage(
          quiz: widget.quiz,
        ),
      ),
    );

    if (result == true && mounted) {
      _showMessage('Soal berhasil ditambahkan.');
    }
  }

  Future<void> _deleteQuestion(
      String questionId,
      String question,
      ) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _DeleteQuestionPage(
          question: question,
        ),
      ),
    );

    if (result != true) return;

    try {
      setState(() {
        _loading = true;
      });

      await _firestore
          .collection('quiz_questions')
          .doc(questionId)
          .delete();

      if (mounted) {
        _showMessage('Soal berhasil dihapus.');
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Gagal menghapus soal: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Soal - ${widget.quiz.title}'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addQuestion,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Soal'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('quiz_questions')
            .where(
          'quizId',
          isEqualTo: widget.quiz.id,
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

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          final questions = docs.toList();

          questions.sort((a, b) {
            final aOrder = a.data()['order'];
            final bOrder = b.data()['order'];

            final aValue = aOrder is int
                ? aOrder
                : int.tryParse(
              aOrder?.toString() ?? '0',
            ) ??
                0;

            final bValue = bOrder is int
                ? bOrder
                : int.tryParse(
              bOrder?.toString() ?? '0',
            ) ??
                0;

            return aValue.compareTo(bValue);
          });

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              100,
            ),
            itemCount: questions.length,
            separatorBuilder: (_, __) =>
            const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = questions[index];

              return _QuestionCard(
                number: index + 1,
                data: doc.data(),
                onDelete: () {
                  _deleteQuestion(
                    doc.id,
                    (doc.data()['question'] ?? 'Soal').toString(),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.help_outline,
              size: 72,
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.7),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum Ada Soal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambahkan soal untuk quiz ini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : _addQuestion,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Soal'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HALAMAN TAMBAH SOAL
// ============================================================

class _AddQuestionPage extends StatefulWidget {
  final Quiz quiz;

  const _AddQuestionPage({
    required this.quiz,
  });

  @override
  State<_AddQuestionPage> createState() => _AddQuestionPageState();
}

class _AddQuestionPageState extends State<_AddQuestionPage> {
  final _formKey = GlobalKey<FormState>();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _question = '';
  String _optionA = '';
  String _optionB = '';
  String _optionC = '';
  String _optionD = '';

  String _correctAnswer = 'A';

  int _points = 10;

  bool _saving = false;

  Future<void> _saveQuestion() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();

    if (_points <= 0) {
      _showMessage('Poin harus lebih dari 0.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final existingQuestions = await _firestore
          .collection('quiz_questions')
          .where(
        'quizId',
        isEqualTo: widget.quiz.id,
      )
          .get();

      int nextOrder = existingQuestions.docs.length;

      if (existingQuestions.docs.isNotEmpty) {
        final orders = existingQuestions.docs.map((doc) {
          final value = doc.data()['order'];

          if (value is int) {
            return value;
          }

          return int.tryParse(
            value?.toString() ?? '0',
          ) ??
              0;
        }).toList();

        nextOrder = orders.reduce(
              (a, b) => a > b ? a : b,
        ) +
            1;
      }

      await _firestore.collection('quiz_questions').add({
        'quizId': widget.quiz.id,
        'question': _question,
        'options': {
          'A': _optionA,
          'B': _optionB,
          'C': _optionC,
          'D': _optionD,
        },
        'correctAnswer': _correctAnswer,
        'points': _points,
        'order': nextOrder,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
        });

        _showMessage('Gagal menyimpan soal: $e');
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Soal'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            20,
            16,
            32,
          ),
          children: [
            Text(
              widget.quiz.title,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 20),

            TextFormField(
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Pertanyaan',
                hintText: 'Tulis pertanyaan...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Pertanyaan wajib diisi';
                }

                return null;
              },
              onSaved: (value) {
                _question = value!.trim();
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Pilihan A',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Pilihan A wajib diisi';
                }

                return null;
              },
              onSaved: (value) {
                _optionA = value!.trim();
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Pilihan B',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Pilihan B wajib diisi';
                }

                return null;
              },
              onSaved: (value) {
                _optionB = value!.trim();
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Pilihan C',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Pilihan C wajib diisi';
                }

                return null;
              },
              onSaved: (value) {
                _optionC = value!.trim();
              },
            ),

            const SizedBox(height: 12),

            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Pilihan D',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Pilihan D wajib diisi';
                }

                return null;
              },
              onSaved: (value) {
                _optionD = value!.trim();
              },
            ),

            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              initialValue: _correctAnswer,
              decoration: const InputDecoration(
                labelText: 'Jawaban Benar',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'A',
                  child: Text('A'),
                ),
                DropdownMenuItem(
                  value: 'B',
                  child: Text('B'),
                ),
                DropdownMenuItem(
                  value: 'C',
                  child: Text('C'),
                ),
                DropdownMenuItem(
                  value: 'D',
                  child: Text('D'),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                if (value == null) return;

                setState(() {
                  _correctAnswer = value;
                });
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              initialValue: '10',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Poin',
                suffixText: 'poin',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final points = int.tryParse(
                  value?.trim() ?? '',
                );

                if (points == null || points <= 0) {
                  return 'Poin harus lebih dari 0';
                }

                return null;
              },
              onSaved: (value) {
                _points = int.tryParse(
                  value?.trim() ?? '',
                ) ??
                    10;
              },
            ),

            const SizedBox(height: 28),

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveQuestion,
                icon: _saving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.save_outlined),
                label: Text(
                  _saving ? 'Menyimpan...' : 'Simpan Soal',
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
// HALAMAN KONFIRMASI HAPUS
// ============================================================

class _DeleteQuestionPage extends StatelessWidget {
  final String question;

  const _DeleteQuestionPage({
    required this.question,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hapus Soal'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: Colors.orange,
            ),

            const SizedBox(height: 20),

            const Text(
              'Hapus soal ini?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              question,
              style: const TextStyle(
                fontSize: 16,
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text('Hapus Soal'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('Batal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// QUESTION CARD
// ============================================================

class _QuestionCard extends StatelessWidget {
  final int number;
  final Map<String, dynamic> data;
  final VoidCallback onDelete;

  const _QuestionCard({
    required this.number,
    required this.data,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final question =
    (data['question'] ?? 'Soal').toString();

    final correctAnswer =
    (data['correctAnswer'] ?? '').toString();

    final points = data['points'] is int
        ? data['points'] as int
        : int.tryParse(
      (data['points'] ?? '10').toString(),
    ) ??
        10;

    final rawOptions = data['options'];

    final Map<String, String> options = {};

    if (rawOptions is Map) {
      rawOptions.forEach((key, value) {
        options[key.toString()] = value.toString();
      });
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    question,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
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

            ...['A', 'B', 'C', 'D'].map(
                  (letter) {
                final text = options[letter] ?? '';

                final isCorrect =
                    correctAnswer == letter;

                return Padding(
                  padding:
                  const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isCorrect
                          ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          : Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius:
                      BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$letter.',
                          style: TextStyle(
                            fontWeight:
                            FontWeight.bold,
                            color: isCorrect
                                ? Theme.of(context)
                                .colorScheme
                                .primary
                                : null,
                          ),
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: Text(
                            text,
                            maxLines: 2,
                            overflow:
                            TextOverflow.ellipsis,
                          ),
                        ),

                        if (isCorrect)
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: Theme.of(context)
                                .colorScheme
                                .primary,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 4),

            Text(
              '$points poin',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}