import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

// ============================================================
// ADMIN QUIZ SCREEN
// ============================================================

class AdminQuizScreen extends StatefulWidget {
  const AdminQuizScreen({super.key});

  @override
  State<AdminQuizScreen> createState() => _AdminQuizScreenState();
}

class _AdminQuizScreenState extends State<AdminQuizScreen> {
  final FirestoreService _firestore = FirestoreService.instance;

  // Cache judul course berdasarkan ID course.
  Map<String, String> _courseNames = {};

  String _getClassName(
      String? classId,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> classes,
      ) {
    if (classId == null || classId.trim().isEmpty) {
      return '-';
    }

    for (final doc in classes) {
      if (doc.id == classId) {
        return (doc.data()['name'] ?? doc.id).toString();
      }
    }

    return classId;
  }

  // Nama course diambil dari courses.title.
  // Tidak menggunakan subject sebagai tampilan.
  String _getCourseName(Map<String, dynamic> data) {
    final savedCourseName = data['courseName']?.toString().trim() ?? '';

    if (savedCourseName.isNotEmpty) {
      return savedCourseName;
    }

    final courseId = data['courseId']?.toString().trim() ?? '';

    if (courseId.isNotEmpty) {
      final courseName = _courseNames[courseId]?.trim() ?? '';

      if (courseName.isNotEmpty) {
        return courseName;
      }
    }

    return 'Course tidak ditemukan';
  }

  // ============================================================
  // TAMBAH / EDIT QUIZ
  // ============================================================

  Future<void> _showQuizDialog({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    if (!mounted) return;

    final data = document?.data();

    final result = await showDialog<_QuizFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuizFormDialog(
        firestore: _firestore,
        isEdit: document != null,
        initialTitle: data?['title']?.toString() ?? '',
        initialCourseId: data?['courseId']?.toString() ?? '',
        initialCourseName: _getCourseName(data ?? {}),
        initialDuration: data?['duration']?.toString() ?? '30',
        initialDescription: data?['description']?.toString() ?? '',
        initialClass: data?['classId']?.toString() ?? '',
      ),
    );

    if (result == null || !mounted) return;

    try {
      if (document != null) {
        await _firestore.updateQuiz(
          id: document.id,
          classId: result.classId,
          teacherId: data?['teacherId']?.toString() ?? 'teacher_001',

          // Kompatibilitas dengan FirestoreService yang sekarang.
          // Tidak digunakan untuk menampilkan nama course.
          subject: result.courseName,

          courseId: result.courseId,
          courseName: result.courseName,
          title: result.title,
          duration: result.duration,
          description: result.description,
          passingScore: data?['passingScore'] is num
              ? (data!['passingScore'] as num).toInt()
              : 70,
        );
      } else {
        await _firestore.addQuiz(
          classId: result.classId,
          teacherId: 'teacher_001',

          // Kompatibilitas dengan FirestoreService yang sekarang.
          subject: result.courseName,

          courseId: result.courseId,
          courseName: result.courseName,
          title: result.title,
          duration: result.duration,
          description: result.description,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            document != null
                ? 'Quiz berhasil diperbarui'
                : 'Quiz berhasil ditambahkan',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan quiz: $e')),
      );
    }
  }

  // ============================================================
  // HAPUS QUIZ
  // ============================================================

  Future<void> _deleteQuiz(String id, String title) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Hapus Quiz',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Apakah kamu yakin ingin menghapus quiz "$title"?',
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
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _firestore.deleteQuiz(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz berhasil dihapus')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus quiz: $e')),
      );
    }
  }

  // ============================================================
  // KELOLA SOAL
  // ============================================================

  void _openQuestions(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdminQuizQuestionsScreen(
          quizId: document.id,
          quizTitle: document.data()?['title']?.toString() ?? 'Quiz',
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Kelola Quiz',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showQuizDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Quiz'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.getCourses(),
        builder: (context, courseSnapshot) {
          if (courseSnapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat course.\n\n${courseSnapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (courseSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final courseDocs = courseSnapshot.data?.docs ?? [];

          _courseNames = {
            for (final doc in courseDocs)
              doc.id: (doc.data()['title'] ?? '').toString().trim(),
          };

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _firestore.getQuizzes(),
            builder: (context, quizSnapshot) {
              if (quizSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              if (quizSnapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Gagal memuat quiz.\n\n${quizSnapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final docs = quizSnapshot.data?.docs ?? [];

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore.getClasses(),
                builder: (context, classSnapshot) {
                  if (classSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (classSnapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Gagal memuat data kelas.\n\n'
                              '${classSnapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final classes = classSnapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text('Belum ada data quiz.'),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) =>
                    const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data();

                      final title =
                          data['title']?.toString() ?? '-';
                      final courseName = _getCourseName(data);
                      final classId =
                          data['classId']?.toString() ?? '';
                      final duration =
                          data['duration']?.toString() ?? '-';

                      final className = _getClassName(
                        classId,
                        classes,
                      );

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: colorScheme.outline.withOpacity(0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color:
                                colorScheme.primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.quiz_rounded,
                                color: colorScheme.primary,
                                size: 30,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '$courseName • $className • '
                                        '$duration menit',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(
                                      color:
                                      colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showQuizDialog(document: doc);
                                } else if (value == 'questions') {
                                  _openQuestions(doc);
                                } else if (value == 'delete') {
                                  _deleteQuiz(doc.id, title);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'questions',
                                  child: Text('Kelola Soal'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Hapus'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// MODEL DAN DIALOG FORM QUIZ
// ============================================================

class _QuizFormResult {
  final String title;
  final String courseId;
  final String courseName;
  final String classId;
  final int duration;
  final String description;

  const _QuizFormResult({
    required this.title,
    required this.courseId,
    required this.courseName,
    required this.classId,
    required this.duration,
    required this.description,
  });
}

class _QuizFormDialog extends StatefulWidget {
  final FirestoreService firestore;
  final bool isEdit;
  final String initialTitle;
  final String initialCourseId;
  final String initialCourseName;
  final String initialDuration;
  final String initialDescription;
  final String initialClass;

  const _QuizFormDialog({
    required this.firestore,
    required this.isEdit,
    required this.initialTitle,
    required this.initialCourseId,
    required this.initialCourseName,
    required this.initialDuration,
    required this.initialDescription,
    required this.initialClass,
  });

  @override
  State<_QuizFormDialog> createState() => _QuizFormDialogState();
}

class _QuizFormDialogState extends State<_QuizFormDialog> {
  late final TextEditingController titleController;
  late final TextEditingController durationController;
  late final TextEditingController descriptionController;

  String? selectedCourse;
  String? selectedClass;

  Map<String, String> _courseNames = {};

  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.initialTitle,
    );

    durationController = TextEditingController(
      text: widget.initialDuration,
    );

    descriptionController = TextEditingController(
      text: widget.initialDescription,
    );

    selectedCourse = widget.initialCourseId.trim().isEmpty
        ? null
        : widget.initialCourseId.trim();

    selectedClass = widget.initialClass.trim().isEmpty
        ? null
        : widget.initialClass.trim();
  }

  @override
  void dispose() {
    titleController.dispose();
    durationController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!formKey.currentState!.validate()) return;

    if (selectedClass == null || selectedClass!.isEmpty) {
      return;
    }

    final duration = int.tryParse(
      durationController.text.trim(),
    );

    if (duration == null || duration <= 0) return;

    String? resolvedCourseId = selectedCourse;

    // Mendukung quiz lama yang courseId-nya belum cocok.
    if (resolvedCourseId == null ||
        !_courseNames.containsKey(resolvedCourseId)) {
      final oldCourseName =
      widget.initialCourseName.trim().toLowerCase();

      for (final entry in _courseNames.entries) {
        if (entry.value.trim().toLowerCase() == oldCourseName &&
            oldCourseName.isNotEmpty) {
          resolvedCourseId = entry.key;
          break;
        }
      }
    }

    if (resolvedCourseId == null ||
        !_courseNames.containsKey(resolvedCourseId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih course terlebih dahulu.'),
        ),
      );
      return;
    }

    final courseName =
        _courseNames[resolvedCourseId]?.trim() ?? '';

    if (courseName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Judul course tidak ditemukan.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop(
      _QuizFormResult(
        title: titleController.text.trim(),
        courseId: resolvedCourseId,
        courseName: courseName,
        classId: selectedClass!,
        duration: duration,
        description: descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isEdit ? 'Edit Quiz' : 'Tambah Quiz',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Judul Quiz',
                    prefixIcon: Icon(Icons.quiz_outlined),
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Judul quiz wajib diisi'
                      : null,
                ),
                const SizedBox(height: 12),

                // Dropdown course memakai courses.title.
                StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: widget.firestore.getCourses(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Gagal memuat course.\n${snapshot.error}',
                        ),
                      );
                    }

                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }

                    final courses = snapshot.data?.docs ?? [];

                    _courseNames = {
                      for (final doc in courses)
                        doc.id: (doc.data()['title'] ?? '')
                            .toString()
                            .trim(),
                    };

                    if (courses.isEmpty) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Belum ada course. Tambahkan course terlebih dahulu.',
                        ),
                      );
                    }

                    String? effectiveValue = selectedCourse;

                    if (effectiveValue == null ||
                        !_courseNames.containsKey(effectiveValue)) {
                      final oldCourseName =
                      widget.initialCourseName.trim().toLowerCase();

                      for (final doc in courses) {
                        final title =
                        (doc.data()['title'] ?? '')
                            .toString()
                            .trim();

                        if (title.toLowerCase() == oldCourseName &&
                            oldCourseName.isNotEmpty) {
                          effectiveValue = doc.id;
                          break;
                        }
                      }
                    }

                    final currentValue = courses.any(
                          (doc) => doc.id == effectiveValue,
                    )
                        ? effectiveValue
                        : null;

                    return DropdownButtonFormField<String>(
                      key: ValueKey(currentValue),
                      initialValue: currentValue,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Judul Course',
                        prefixIcon: Icon(Icons.menu_book_outlined),
                      ),
                      items: courses.map((doc) {
                        final title =
                        (doc.data()['title'] ?? '')
                            .toString()
                            .trim();

                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(
                            title.isEmpty ? '(Tanpa judul)' : title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCourse = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Silakan pilih course';
                        }
                        return null;
                      },
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Dropdown kelas.
                StreamBuilder<
                    QuerySnapshot<Map<String, dynamic>>>(
                  stream: widget.firestore.getClasses(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Gagal memuat daftar kelas.'),
                      );
                    }

                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const LinearProgressIndicator();
                    }

                    final classes = snapshot.data?.docs ?? [];

                    if (classes.isEmpty) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Belum ada kelas. Tambahkan kelas terlebih dahulu.',
                        ),
                      );
                    }

                    final currentValue = classes.any(
                          (doc) => doc.id == selectedClass,
                    )
                        ? selectedClass
                        : null;

                    return DropdownButtonFormField<String>(
                      key: ValueKey(currentValue),
                      initialValue: currentValue,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Kelas',
                        prefixIcon: Icon(Icons.class_outlined),
                      ),
                      items: classes.map((doc) {
                        final classData = doc.data();

                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(
                            (classData['name'] ?? doc.id).toString(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedClass = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Silakan pilih kelas';
                        }
                        return null;
                      },
                    );
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Durasi (menit)',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  validator: (value) {
                    final duration =
                    int.tryParse(value?.trim() ?? '');

                    if (duration == null || duration <= 0) {
                      return 'Durasi harus berupa angka lebih dari 0';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi',
                    prefixIcon: Icon(Icons.description_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            widget.isEdit ? 'Simpan Perubahan' : 'Simpan',
          ),
        ),
      ],
    );
  }
}

// ============================================================
// ADMIN QUIZ QUESTIONS SCREEN
// ============================================================

class AdminQuizQuestionsScreen extends StatefulWidget {
  final String quizId;
  final String quizTitle;

  const AdminQuizQuestionsScreen({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<AdminQuizQuestionsScreen> createState() =>
      _AdminQuizQuestionsScreenState();
}

class _AdminQuizQuestionsScreenState
    extends State<AdminQuizQuestionsScreen> {
  final FirestoreService _firestore = FirestoreService.instance;

  String _getOption(dynamic options, int index) {
    const keys = ['A', 'B', 'C', 'D'];

    if (index < 0 || index >= keys.length) return '';

    if (options is Map) {
      return (options[keys[index]] ?? '').toString();
    }

    if (options is List && index < options.length) {
      return options[index]?.toString() ?? '';
    }

    return '';
  }

  String _getCorrectAnswer(Map<String, dynamic>? data) {
    final answer = data?['correctAnswer'] ?? data?['answer'];
    return answer?.toString().toUpperCase() ?? 'A';
  }

  Future<void> _showQuestionDialog({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    if (!mounted) return;

    final data = document?.data();
    final isEdit = document != null;
    final optionsData = data?['options'];

    final result = await showDialog<_QuizQuestionFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QuizQuestionFormDialog(
        isEdit: isEdit,
        initialQuestion: data?['question']?.toString() ?? '',
        initialOptions: List.generate(
          4,
              (index) => _getOption(optionsData, index),
        ),
        initialAnswer: _getCorrectAnswer(data),
      ),
    );

    if (result == null || !mounted) return;

    try {
      if (isEdit) {
        await _firestore.updateQuizQuestion(
          quizId: widget.quizId,
          questionId: document.id,
          question: result.question,
          options: result.options,
          answer: result.answer,
        );
      } else {
        await _firestore.addQuizQuestion(
          quizId: widget.quizId,
          question: result.question,
          options: result.options,
          answer: result.answer,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Soal berhasil diperbarui'
                : 'Soal berhasil ditambahkan',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menyimpan soal: $e')),
      );
    }
  }

  Future<void> _deleteQuestion(String id, String question) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Hapus Soal',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Apakah kamu yakin ingin menghapus soal "$question"?',
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
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _firestore.deleteQuizQuestion(
        quizId: widget.quizId,
        questionId: id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Soal berhasil dihapus')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal menghapus soal: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.quizTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showQuestionDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Soal'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.getQuizQuestions(widget.quizId),
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
            return const Center(
              child: Text('Belum ada soal.'),
            );
          }

          final sortedDocs = [...docs];

          sortedDocs.sort((a, b) {
            final orderA = a.data()['order'];
            final orderB = b.data()['order'];

            final valueA = orderA is num ? orderA.toInt() : 999999;
            final valueB = orderB is num ? orderB.toInt() : 999999;

            return valueA.compareTo(valueB);
          });

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: sortedDocs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = sortedDocs[index];
              final data = doc.data();

              final question = data['question']?.toString() ?? '-';
              final answer = _getCorrectAnswer(data);
              final options = data['options'];

              final optionCount = options is Map
                  ? ['A', 'B', 'C', 'D']
                  .where(
                    (key) => (options[key] ?? '')
                    .toString()
                    .trim()
                    .isNotEmpty,
              )
                  .length
                  : options is List
                  ? options
                  .where(
                    (value) =>
                value.toString().trim().isNotEmpty,
              )
                  .length
                  : 0;

              return Card(
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor:
                    colorScheme.primary.withOpacity(0.12),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    question,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Jawaban benar: $answer • $optionCount pilihan',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showQuestionDialog(document: doc);
                      } else if (value == 'delete') {
                        _deleteQuestion(doc.id, question);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Edit'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Hapus'),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================
// MODEL DAN DIALOG FORM SOAL
// ============================================================

class _QuizQuestionFormResult {
  final String question;
  final List<String> options;
  final String answer;

  const _QuizQuestionFormResult({
    required this.question,
    required this.options,
    required this.answer,
  });
}

class _QuizQuestionFormDialog extends StatefulWidget {
  final bool isEdit;
  final String initialQuestion;
  final List<String> initialOptions;
  final String initialAnswer;

  const _QuizQuestionFormDialog({
    required this.isEdit,
    required this.initialQuestion,
    required this.initialOptions,
    required this.initialAnswer,
  });

  @override
  State<_QuizQuestionFormDialog> createState() =>
      _QuizQuestionFormDialogState();
}

class _QuizQuestionFormDialogState
    extends State<_QuizQuestionFormDialog> {
  late final TextEditingController questionController;
  late final List<TextEditingController> optionControllers;
  late String selectedAnswer;

  final formKey = GlobalKey<FormState>();

  static const List<String> answerOptions = ['A', 'B', 'C', 'D'];

  @override
  void initState() {
    super.initState();

    questionController = TextEditingController(
      text: widget.initialQuestion,
    );

    optionControllers = List.generate(4, (index) {
      final value = index < widget.initialOptions.length
          ? widget.initialOptions[index]
          : '';

      return TextEditingController(text: value);
    });

    final normalizedAnswer = widget.initialAnswer.toUpperCase();

    selectedAnswer = answerOptions.contains(normalizedAnswer)
        ? normalizedAnswer
        : 'A';
  }

  @override
  void dispose() {
    questionController.dispose();

    for (final controller in optionControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  void _submit() {
    if (!formKey.currentState!.validate()) return;

    final options = optionControllers
        .map((controller) => controller.text.trim())
        .toList();

    Navigator.of(context).pop(
      _QuizQuestionFormResult(
        question: questionController.text.trim(),
        options: options,
        answer: selectedAnswer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isEdit ? 'Edit Soal' : 'Tambah Soal',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SizedBox(
        width: 550,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: questionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Pertanyaan',
                    prefixIcon: Icon(Icons.help_outline_rounded),
                    alignLabelWithHint: true,
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Pertanyaan wajib diisi'
                      : null,
                ),
                const SizedBox(height: 16),
                ...List.generate(4, (index) {
                  final label = answerOptions[index];

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextFormField(
                      controller: optionControllers[index],
                      decoration: InputDecoration(
                        labelText: 'Pilihan $label',
                        prefixIcon: CircleAvatar(
                          radius: 12,
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      validator: (value) =>
                      value == null || value.trim().isEmpty
                          ? 'Pilihan $label wajib diisi'
                          : null,
                    ),
                  );
                }),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: selectedAnswer,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Jawaban Benar',
                    prefixIcon: Icon(Icons.check_circle_outline),
                  ),
                  items: answerOptions.map((answer) {
                    return DropdownMenuItem<String>(
                      value: answer,
                      child: Text('Pilihan $answer'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => selectedAnswer = value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            widget.isEdit ? 'Simpan Perubahan' : 'Simpan',
          ),
        ),
      ],
    );
  }
}