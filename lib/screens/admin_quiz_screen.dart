import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class AdminQuizScreen extends StatefulWidget {
  const AdminQuizScreen({super.key});

  @override
  State<AdminQuizScreen> createState() => _AdminQuizScreenState();
}

class _AdminQuizScreenState extends State<AdminQuizScreen> {
  final FirestoreService _firestore =
      FirestoreService.instance;

  static const List<Map<String, String>> classOptions = [
    {
      'id': 'X_RPL_1',
      'name': 'X RPL 1',
    },
    {
      'id': 'XI_RPL_1',
      'name': 'XI RPL 1',
    },
    {
      'id': 'XI_RPL_2',
      'name': 'XI RPL 2',
    },
    {
      'id': 'XII_RPL_1',
      'name': 'XII RPL 1',
    },
  ];

  // ============================================================
  // NAMA KELAS
  // ============================================================

  String _getClassName(String? classId) {
    if (classId == null ||
        classId.trim().isEmpty) {
      return '-';
    }

    for (final item in classOptions) {
      if (item['id'] == classId) {
        return item['name'] ?? classId;
      }
    }

    return classId;
  }

  // ============================================================
  // TAMBAH / EDIT QUIZ
  // ============================================================

  Future<void> _showQuizDialog({
    DocumentSnapshot<Map<String, dynamic>>?
    document,
  }) async {
    if (!mounted) return;

    final data = document?.data();
    final isEdit = document != null;

    final savedClass =
    data?['classId']?.toString().trim();

    String selectedClass = 'XI_RPL_1';

    if (savedClass != null &&
        classOptions.any(
              (item) => item['id'] == savedClass,
        )) {
      selectedClass = savedClass;
    }

    // ==========================================================
    // DIALOG
    // ==========================================================

    final result =
    await showDialog<_QuizFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _QuizFormDialog(
          isEdit: isEdit,
          initialTitle:
          data?['title']?.toString() ?? '',
          initialSubject:
          data?['subject']?.toString() ?? '',
          initialDuration:
          data?['duration']?.toString() ??
              '30',
          initialDescription:
          data?['description']?.toString() ??
              '',
          initialClass: selectedClass,
          classOptions: classOptions,
        );
      },
    );

    // ==========================================================
    // DIALOG SUDAH DITUTUP
    // ==========================================================

    if (result == null) return;
    if (!mounted) return;

    try {
      if (isEdit) {
        await _firestore.updateQuiz(
          id: document!.id,
          classId: result.classId,
          teacherId:
          data?['teacherId']?.toString() ??
              'teacher_001',
          subject: result.subject,
          title: result.title,
          duration: result.duration,
          description: result.description,
        );
      } else {
        await _firestore.addQuiz(
          classId: result.classId,
          teacherId: 'teacher_001',
          subject: result.subject,
          title: result.title,
          duration: result.duration,
          description: result.description,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Quiz berhasil diperbarui'
                : 'Quiz berhasil ditambahkan',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan quiz: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // HAPUS QUIZ
  // ============================================================

  Future<void> _deleteQuiz(
      String id,
      String title,
      ) async {
    if (!mounted) return;

    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Hapus Quiz',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Apakah kamu yakin ingin '
                'menghapus quiz "$title"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Batal',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'Hapus',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await _firestore.deleteQuiz(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Quiz berhasil dihapus',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus quiz: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUKA KELOLA SOAL
  // ============================================================

  void _openQuestions(
      DocumentSnapshot<Map<String, dynamic>>
      document,
      ) {
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          return AdminQuizQuestionsScreen(
            quizId: document.id,
            quizTitle:
            document.data()?['title']
                ?.toString() ??
                'Quiz',
          );
        },
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
      backgroundColor:
      theme.scaffoldBackgroundColor,

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        title: const Text(
          'Kelola Quiz',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
        theme.scaffoldBackgroundColor,
      ),

      // ==========================================================
      // TAMBAH QUIZ
      // ==========================================================

      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: () {
          _showQuizDialog();
        },
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Tambah Quiz',
        ),
      ),

      // ==========================================================
      // DATA QUIZ
      // ==========================================================

      body:
      StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.getQuizzes(),
        builder: (
            context,
            snapshot,
            ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
              CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat quiz.\n\n'
                      '${snapshot.error}',
                  textAlign:
                  TextAlign.center,
                ),
              ),
            );
          }

          final docs =
              snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada data quiz.',
              ),
            );
          }

          return ListView.separated(
            padding:
            const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              100,
            ),
            itemCount: docs.length,
            separatorBuilder: (
                _,
                __,
                ) {
              return const SizedBox(
                height: 12,
              );
            },
            itemBuilder: (
                context,
                index,
                ) {
              final doc = docs[index];
              final data = doc.data();

              final title =
                  data['title']
                      ?.toString() ??
                      '-';

              final subject =
                  data['subject']
                      ?.toString() ??
                      '-';

              final classId =
                  data['classId']
                      ?.toString() ??
                      '';

              final duration =
                  data['duration']
                      ?.toString() ??
                      '-';

              final className =
              _getClassName(classId);

              return Container(
                padding:
                const EdgeInsets.all(16),
                decoration:
                BoxDecoration(
                  color:
                  colorScheme.surface,
                  borderRadius:
                  BorderRadius.circular(
                    18,
                  ),
                  border: Border.all(
                    color: colorScheme
                        .outline
                        .withOpacity(
                      0.35,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // ==================================================
                    // ICON
                    // ==================================================

                    Container(
                      width: 52,
                      height: 52,
                      decoration:
                      BoxDecoration(
                        color: colorScheme
                            .primary
                            .withOpacity(
                          0.12,
                        ),
                        borderRadius:
                        BorderRadius
                            .circular(
                          14,
                        ),
                      ),
                      child: Icon(
                        Icons.quiz_rounded,
                        color:
                        colorScheme
                            .primary,
                        size: 30,
                      ),
                    ),

                    const SizedBox(
                      width: 14,
                    ),

                    // ==================================================
                    // DATA
                    // ==================================================

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style: theme
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              fontWeight:
                              FontWeight
                                  .w800,
                            ),
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            '$subject • '
                                '$className • '
                                '$duration menit',
                            maxLines: 2,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    // ==================================================
                    // MENU
                    // ==================================================

                    PopupMenuButton<String>(
                      onSelected: (
                          value,
                          ) {
                        if (value ==
                            'edit') {
                          _showQuizDialog(
                            document: doc,
                          );
                        } else if (value ==
                            'questions') {
                          _openQuestions(
                            doc,
                          );
                        } else if (value ==
                            'delete') {
                          _deleteQuiz(
                            doc.id,
                            title,
                          );
                        }
                      },
                      itemBuilder: (_) {
                        return const [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text(
                              'Edit',
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'questions',
                            child: Text(
                              'Kelola Soal',
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text(
                              'Hapus',
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ==================================================================
// MODEL HASIL FORM QUIZ
// ==================================================================

class _QuizFormResult {
  final String title;
  final String subject;
  final String classId;
  final int duration;
  final String description;

  const _QuizFormResult({
    required this.title,
    required this.subject,
    required this.classId,
    required this.duration,
    required this.description,
  });
}

// ==================================================================
// DIALOG FORM QUIZ
// ==================================================================

class _QuizFormDialog
    extends StatefulWidget {
  final bool isEdit;
  final String initialTitle;
  final String initialSubject;
  final String initialDuration;
  final String initialDescription;
  final String initialClass;
  final List<Map<String, String>>
  classOptions;

  const _QuizFormDialog({
    required this.isEdit,
    required this.initialTitle,
    required this.initialSubject,
    required this.initialDuration,
    required this.initialDescription,
    required this.initialClass,
    required this.classOptions,
  });

  @override
  State<_QuizFormDialog> createState() =>
      _QuizFormDialogState();
}

class _QuizFormDialogState
    extends State<_QuizFormDialog> {
  late final TextEditingController
  titleController;

  late final TextEditingController
  subjectController;

  late final TextEditingController
  durationController;

  late final TextEditingController
  descriptionController;

  late String selectedClass;

  final formKey =
  GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    titleController =
        TextEditingController(
          text: widget.initialTitle,
        );

    subjectController =
        TextEditingController(
          text: widget.initialSubject,
        );

    durationController =
        TextEditingController(
          text: widget.initialDuration,
        );

    descriptionController =
        TextEditingController(
          text: widget.initialDescription,
        );

    final validClass =
    widget.classOptions.any(
          (item) =>
      item['id'] ==
          widget.initialClass,
    );

    selectedClass = validClass
        ? widget.initialClass
        : 'XI_RPL_1';
  }

  @override
  void dispose() {
    titleController.dispose();
    subjectController.dispose();
    durationController.dispose();
    descriptionController.dispose();

    super.dispose();
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  void _submit() {
    if (!formKey.currentState!
        .validate()) {
      return;
    }

    final duration = int.tryParse(
      durationController.text.trim(),
    );

    if (duration == null ||
        duration <= 0) {
      return;
    }

    Navigator.of(context).pop(
      _QuizFormResult(
        title:
        titleController.text.trim(),
        subject:
        subjectController.text.trim(),
        classId: selectedClass,
        duration: duration,
        description:
        descriptionController.text
            .trim(),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isEdit
            ? 'Edit Quiz'
            : 'Tambah Quiz',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),

      content: SizedBox(
        width: 500,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                // ==================================================
                // JUDUL
                // ==================================================

                TextFormField(
                  controller:
                  titleController,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Judul Quiz',
                    prefixIcon: Icon(
                      Icons
                          .quiz_outlined,
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Judul quiz wajib diisi';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 12,
                ),

                // ==================================================
                // SUBJECT
                // ==================================================

                TextFormField(
                  controller:
                  subjectController,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Mata Pelajaran',
                    prefixIcon: Icon(
                      Icons
                          .menu_book_outlined,
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Mata pelajaran wajib diisi';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 12,
                ),

                // ==================================================
                // KELAS
                // ==================================================

                DropdownButtonFormField<
                    String>(
                  initialValue:
                  selectedClass,
                  isExpanded: true,
                  decoration:
                  const InputDecoration(
                    labelText: 'Kelas',
                    prefixIcon: Icon(
                      Icons
                          .class_outlined,
                    ),
                  ),
                  items: widget.classOptions
                      .map(
                        (item) {
                      return DropdownMenuItem<
                          String>(
                        value: item['id'],
                        child: Text(
                          item['name'] ??
                              '',
                        ),
                      );
                    },
                  ).toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      selectedClass =
                          value;
                    });
                  },
                ),

                const SizedBox(
                  height: 12,
                ),

                // ==================================================
                // DURASI
                // ==================================================

                TextFormField(
                  controller:
                  durationController,
                  keyboardType:
                  TextInputType.number,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Durasi (menit)',
                    prefixIcon: Icon(
                      Icons
                          .timer_outlined,
                    ),
                  ),
                  validator: (value) {
                    final duration =
                    int.tryParse(
                      value?.trim() ??
                          '',
                    );

                    if (duration ==
                        null ||
                        duration <= 0) {
                      return 'Durasi harus berupa angka lebih dari 0';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 12,
                ),

                // ==================================================
                // DESKRIPSI
                // ==================================================

                TextFormField(
                  controller:
                  descriptionController,
                  maxLines: 3,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Deskripsi',
                    prefixIcon: Icon(
                      Icons
                          .description_outlined,
                    ),
                    alignLabelWithHint:
                    true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ==========================================================
      // ACTION
      // ==========================================================

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Batal',
          ),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            widget.isEdit
                ? 'Simpan Perubahan'
                : 'Simpan',
          ),
        ),
      ],
    );
  }
}

// ==================================================================
// ADMIN QUIZ QUESTIONS SCREEN
// ==================================================================

class AdminQuizQuestionsScreen
    extends StatefulWidget {
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
  final FirestoreService _firestore =
      FirestoreService.instance;

  // ============================================================
  // AMBIL OPTION
  // ============================================================

  String _getOption(
      dynamic options,
      int index,
      ) {
    if (options is! List) {
      return '';
    }

    if (index < 0 ||
        index >= options.length) {
      return '';
    }

    return options[index]?.toString() ??
        '';
  }

  // ============================================================
  // TAMBAH / EDIT SOAL
  // ============================================================

  Future<void> _showQuestionDialog({
    DocumentSnapshot<Map<String, dynamic>>?
    document,
  }) async {
    if (!mounted) return;

    final data = document?.data();
    final isEdit = document != null;

    final optionsData =
    data?['options'];

    final result =
    await showDialog<_QuizQuestionFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _QuizQuestionFormDialog(
          isEdit: isEdit,
          initialQuestion:
          data?['question']
              ?.toString() ??
              '',
          initialOptions:
          List.generate(
            4,
                (index) {
              return _getOption(
                optionsData,
                index,
              );
            },
          ),
          initialAnswer:
          data?['answer']
              ?.toString() ??
              'A',
        );
      },
    );

    // ==========================================================
    // DIALOG SELESAI
    // ==========================================================

    if (result == null) return;
    if (!mounted) return;

    try {
      if (isEdit) {
        await _firestore
            .updateQuizQuestion(
          quizId: widget.quizId,
          questionId: document!.id,
          question:
          result.question,
          options:
          result.options,
          answer:
          result.answer,
        );
      } else {
        await _firestore
            .addQuizQuestion(
          quizId: widget.quizId,
          question:
          result.question,
          options:
          result.options,
          answer:
          result.answer,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
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

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan soal: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // HAPUS SOAL
  // ============================================================

  Future<void> _deleteQuestion(
      String id,
      String question,
      ) async {
    if (!mounted) return;

    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Hapus Soal',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Apakah kamu yakin ingin '
                'menghapus soal "$question"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Batal',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'Hapus',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await _firestore
          .deleteQuizQuestion(
        quizId: widget.quizId,
        questionId: id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Soal berhasil dihapus',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus soal: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    return Scaffold(
      backgroundColor:
      theme.scaffoldBackgroundColor,

      appBar: AppBar(
        title: Text(
          widget.quizTitle,
          maxLines: 1,
          overflow:
          TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight:
            FontWeight.w800,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
        theme.scaffoldBackgroundColor,
      ),

      // ==========================================================
      // TAMBAH SOAL
      // ==========================================================

      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: () {
          _showQuestionDialog();
        },
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          'Tambah Soal',
        ),
      ),

      // ==========================================================
      // DATA SOAL
      // ==========================================================

      body:
      StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream:
        _firestore.getQuizQuestions(
          widget.quizId,
        ),
        builder: (
            context,
            snapshot,
            ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
              CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat soal.\n\n'
                      '${snapshot.error}',
                  textAlign:
                  TextAlign.center,
                ),
              ),
            );
          }

          final docs =
              snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada soal.',
              ),
            );
          }

          return ListView.separated(
            padding:
            const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              100,
            ),
            itemCount: docs.length,
            separatorBuilder: (
                _,
                __,
                ) {
              return const SizedBox(
                height: 12,
              );
            },
            itemBuilder: (
                context,
                index,
                ) {
              final doc = docs[index];
              final data = doc.data();

              final question =
                  data['question']
                      ?.toString() ??
                      '-';

              final answer =
                  data['answer']
                      ?.toString() ??
                      '-';

              final options =
              data['options'];

              final optionCount =
              options is List
                  ? options.length
                  : 0;

              return Card(
                elevation: 0,
                clipBehavior:
                Clip.antiAlias,
                child: ListTile(
                  contentPadding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),

                  leading: CircleAvatar(
                    backgroundColor:
                    colorScheme.primary
                        .withOpacity(
                      0.12,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color:
                        colorScheme
                            .primary,
                        fontWeight:
                        FontWeight
                            .w800,
                      ),
                    ),
                  ),

                  title: Text(
                    question,
                    maxLines: 3,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),

                  subtitle: Padding(
                    padding:
                    const EdgeInsets
                        .only(
                      top: 4,
                    ),
                    child: Text(
                      'Jawaban benar: '
                          '$answer • '
                          '$optionCount pilihan',
                      style: TextStyle(
                        color: colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ),

                  trailing:
                  PopupMenuButton<
                      String>(
                    onSelected: (
                        value,
                        ) {
                      if (value ==
                          'edit') {
                        _showQuestionDialog(
                          document: doc,
                        );
                      } else if (value ==
                          'delete') {
                        _deleteQuestion(
                          doc.id,
                          question,
                        );
                      }
                    },
                    itemBuilder: (_) {
                      return const [
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text(
                            'Edit',
                          ),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text(
                            'Hapus',
                          ),
                        ),
                      ];
                    },
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

// ==================================================================
// MODEL HASIL FORM SOAL
// ==================================================================

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

// ==================================================================
// DIALOG FORM SOAL
// ==================================================================

class _QuizQuestionFormDialog
    extends StatefulWidget {
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
  State<_QuizQuestionFormDialog>
  createState() =>
      _QuizQuestionFormDialogState();
}

class _QuizQuestionFormDialogState
    extends State<_QuizQuestionFormDialog> {
  late final TextEditingController
  questionController;

  late final List<
      TextEditingController>
  optionControllers;

  late String selectedAnswer;

  final formKey =
  GlobalKey<FormState>();

  static const List<String>
  answerOptions = [
    'A',
    'B',
    'C',
    'D',
  ];

  @override
  void initState() {
    super.initState();

    // ==========================================================
    // PERTANYAAN
    // ==========================================================

    questionController =
        TextEditingController(
          text: widget.initialQuestion,
        );

    // ==========================================================
    // PILIHAN A-D
    // ==========================================================

    optionControllers =
        List.generate(
          4,
              (index) {
            final value =
            index <
                widget
                    .initialOptions
                    .length
                ? widget.initialOptions[
            index]
                : '';

            return TextEditingController(
              text: value,
            );
          },
        );

    // ==========================================================
    // JAWABAN
    // ==========================================================

    selectedAnswer =
    answerOptions.contains(
      widget.initialAnswer,
    )
        ? widget.initialAnswer
        : 'A';
  }

  @override
  void dispose() {
    questionController.dispose();

    for (final controller
    in optionControllers) {
      controller.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  void _submit() {
    if (!formKey.currentState!
        .validate()) {
      return;
    }

    final options =
    optionControllers
        .map(
          (controller) =>
          controller.text.trim(),
    )
        .toList();

    Navigator.of(context).pop(
      _QuizQuestionFormResult(
        question:
        questionController.text
            .trim(),
        options: options,
        answer: selectedAnswer,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isEdit
            ? 'Edit Soal'
            : 'Tambah Soal',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),

      content: SizedBox(
        width: 550,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                // ==================================================
                // PERTANYAAN
                // ==================================================

                TextFormField(
                  controller:
                  questionController,
                  maxLines: 4,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Pertanyaan',
                    prefixIcon: Icon(
                      Icons
                          .help_outline_rounded,
                    ),
                    alignLabelWithHint:
                    true,
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Pertanyaan wajib diisi';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 16,
                ),

                // ==================================================
                // PILIHAN A-D
                // ==================================================

                ...List.generate(
                  4,
                      (index) {
                    final label =
                    String.fromCharCode(
                      65 + index,
                    );

                    return Padding(
                      padding:
                      const EdgeInsets
                          .only(
                        bottom: 10,
                      ),
                      child:
                      TextFormField(
                        controller:
                        optionControllers[
                        index],
                        decoration:
                        InputDecoration(
                          labelText:
                          'Pilihan $label',
                          prefixIcon:
                          CircleAvatar(
                            radius: 12,
                            child: Text(
                              label,
                              style:
                              const TextStyle(
                                fontSize:
                                12,
                                fontWeight:
                                FontWeight
                                    .w700,
                              ),
                            ),
                          ),
                        ),
                        validator:
                            (value) {
                          if (value ==
                              null ||
                              value
                                  .trim()
                                  .isEmpty) {
                            return 'Pilihan $label wajib diisi';
                          }

                          return null;
                        },
                      ),
                    );
                  },
                ),

                const SizedBox(
                  height: 4,
                ),

                // ==================================================
                // JAWABAN BENAR
                // ==================================================

                DropdownButtonFormField<
                    String>(
                  initialValue:
                  selectedAnswer,
                  isExpanded: true,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Jawaban Benar',
                    prefixIcon: Icon(
                      Icons
                          .check_circle_outline,
                    ),
                  ),
                  items:
                  answerOptions.map(
                        (answer) {
                      return DropdownMenuItem<
                          String>(
                        value: answer,
                        child: Text(
                          'Pilihan $answer',
                        ),
                      );
                    },
                  ).toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      selectedAnswer =
                          value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),

      // ==========================================================
      // ACTION
      // ==========================================================

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Batal',
          ),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            widget.isEdit
                ? 'Simpan Perubahan'
                : 'Simpan',
          ),
        ),
      ],
    );
  }
}