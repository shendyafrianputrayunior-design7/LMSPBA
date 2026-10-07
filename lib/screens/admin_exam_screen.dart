import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class AdminExamScreen extends StatefulWidget {
  const AdminExamScreen({super.key});

  @override
  State<AdminExamScreen> createState() => _AdminExamScreenState();
}

class _AdminExamScreenState extends State<AdminExamScreen> {
  final FirestoreService _firestore = FirestoreService.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Cache data guru agar nama guru bisa ditampilkan
  Map<String, String> _teacherNames = {};

  // ============================================================
  // DAFTAR KELAS
  // ============================================================

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
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadTeacherNames();
  }

  // ============================================================
  // LOAD GURU
  // ============================================================

  Future<void> _loadTeacherNames() async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot;

      try {
        snapshot = await _db
            .collection('teachers')
            .orderBy('name')
            .get();
      } catch (_) {
        snapshot = await _db.collection('teachers').get();
      }

      final Map<String, String> names = {};

      for (final teacher in snapshot.docs) {
        final data = teacher.data();

        final name = data['name']?.toString().trim();
        final email = data['email']?.toString().trim();

        if (name != null && name.isNotEmpty) {
          names[teacher.id] = name;
        } else if (email != null && email.isNotEmpty) {
          names[teacher.id] = email;
        } else {
          names[teacher.id] = teacher.id;
        }
      }

      if (!mounted) return;

      setState(() {
        _teacherNames = names;
      });
    } catch (_) {
      // Tidak perlu menampilkan error di sini.
      // Dialog tambah/edit tetap akan mengambil data guru sendiri.
    }
  }

  // ============================================================
  // NAMA KELAS
  // ============================================================

  String _getClassName(String? classId) {
    if (classId == null || classId.trim().isEmpty) {
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
  // NAMA GURU
  // ============================================================

  String? _getTeacherName(String teacherId) {
    if (teacherId.trim().isEmpty) {
      return null;
    }

    final name = _teacherNames[teacherId];

    if (name != null && name.trim().isNotEmpty) {
      return name;
    }

    return null;
  }

  // ============================================================
  // AMBIL DATA GURU
  // ============================================================

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _getTeachers() async {
    try {
      try {
        final snapshot = await _db
            .collection('teachers')
            .orderBy('name')
            .get();

        return snapshot.docs;
      } catch (_) {
        final snapshot =
        await _db.collection('teachers').get();

        return snapshot.docs;
      }
    } catch (e) {
      throw Exception('Gagal mengambil data guru: $e');
    }
  }

  // ============================================================
  // TAMBAH / EDIT UJIAN
  // ============================================================

  Future<void> _showExamDialog({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    if (!mounted) return;

    final data = document?.data();
    final isEdit = document != null;

    // ----------------------------------------------------------
    // KELAS AWAL
    // ----------------------------------------------------------

    final savedClass =
    data?['classId']?.toString().trim();

    String selectedClass = 'XI_RPL_1';

    if (savedClass != null && savedClass.isNotEmpty) {
      final exists = classOptions.any(
            (item) => item['id'] == savedClass,
      );

      if (exists) {
        selectedClass = savedClass;
      }
    }

    // ----------------------------------------------------------
    // TEACHER AWAL
    // ----------------------------------------------------------

    final savedTeacherId =
        data?['teacherId']?.toString().trim() ?? '';

    // ----------------------------------------------------------
    // AMBIL DAFTAR GURU
    // ----------------------------------------------------------

    List<QueryDocumentSnapshot<Map<String, dynamic>>> teachers;

    try {
      teachers = await _getTeachers();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengambil data guru: $e',
          ),
        ),
      );

      return;
    }

    if (!mounted) return;

    if (teachers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Belum ada data guru. Tambahkan guru terlebih dahulu.',
          ),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // UPDATE CACHE NAMA GURU
    // ----------------------------------------------------------

    final updatedTeacherNames = <String, String>{
      ..._teacherNames,
    };

    for (final teacher in teachers) {
      final teacherData = teacher.data();

      final name =
      teacherData['name']?.toString().trim();

      final email =
      teacherData['email']?.toString().trim();

      if (name != null && name.isNotEmpty) {
        updatedTeacherNames[teacher.id] = name;
      } else if (email != null && email.isNotEmpty) {
        updatedTeacherNames[teacher.id] = email;
      } else {
        updatedTeacherNames[teacher.id] = teacher.id;
      }
    }

    setState(() {
      _teacherNames = updatedTeacherNames;
    });

    // ----------------------------------------------------------
    // GURU TERPILIH
    // ----------------------------------------------------------

    String? selectedTeacherId;

    if (savedTeacherId.isNotEmpty) {
      final teacherExists = teachers.any(
            (teacher) => teacher.id == savedTeacherId,
      );

      if (teacherExists) {
        selectedTeacherId = savedTeacherId;
      }
    }

    // Tambah baru → pilih guru pertama
    selectedTeacherId ??= teachers.first.id;

    // ----------------------------------------------------------
    // DIALOG
    // ----------------------------------------------------------

    final result = await showDialog<_ExamFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _ExamFormDialog(
          isEdit: isEdit,
          initialTitle:
          data?['title']?.toString() ?? '',
          initialSubject:
          data?['subject']?.toString() ?? '',
          initialDuration:
          data?['duration']?.toString() ?? '30',
          initialDescription:
          data?['description']?.toString() ?? '',
          initialDate:
          data?['date']?.toString() ?? '',
          initialClass: selectedClass,
          initialTeacherId: selectedTeacherId!,
          classOptions: classOptions,
          teachers: teachers,
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    try {
      // --------------------------------------------------------
      // EDIT
      // --------------------------------------------------------

      if (isEdit) {
        await _firestore.updateExam(
          id: document!.id,
          classId: result.classId,

          // PENTING:
          // ID dokumen teachers, bukan Firebase Auth UID
          teacherId: result.teacherId,

          subject: result.subject,
          title: result.title,
          duration: result.duration,
          date: result.date,
          description: result.description,
        );
      }

      // --------------------------------------------------------
      // TAMBAH
      // --------------------------------------------------------

      else {
        await _firestore.addExam(
          classId: result.classId,

          // PENTING:
          // ID dokumen teachers, bukan Firebase Auth UID
          teacherId: result.teacherId,

          subject: result.subject,
          title: result.title,
          duration: result.duration,
          date: result.date,
          description: result.description,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Ujian berhasil diperbarui'
                : 'Ujian berhasil ditambahkan',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan ujian: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // HAPUS UJIAN
  // ============================================================

  Future<void> _deleteExam(
      String id,
      String title,
      ) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Hapus Ujian',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Apakah kamu yakin ingin menghapus ujian "$title"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _firestore.deleteExam(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ujian berhasil dihapus',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus ujian: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUKA KELOLA SOAL
  // ============================================================

  void _openQuestions(
      DocumentSnapshot<Map<String, dynamic>> document,
      ) {
    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          return AdminExamQuestionsScreen(
            examId: document.id,
            examTitle:
            document.data()?['title']?.toString() ??
                'Ujian',
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
      backgroundColor: theme.scaffoldBackgroundColor,

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        title: const Text(
          'Kelola Ujian',
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
      // TAMBAH UJIAN
      // ==========================================================

      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: _showExamDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Ujian'),
      ),

      // ==========================================================
      // DATA UJIAN
      // ==========================================================

      body:
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.getExams(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat data ujian.\n\n'
                      '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada data ujian.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              100,
            ),
            itemCount: docs.length,
            separatorBuilder: (_, __) {
              return const SizedBox(height: 12);
            },
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final title =
                  data['title']?.toString() ?? '-';

              final subject =
                  data['subject']?.toString() ?? '-';

              final classId =
                  data['classId']?.toString() ?? '';

              final duration =
                  data['duration']?.toString() ?? '-';

              final date =
                  data['date']?.toString() ?? '-';

              final teacherId =
                  data['teacherId']?.toString() ?? '';

              final teacherName =
              _getTeacherName(teacherId);

              final className =
              _getClassName(classId);

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius:
                  BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.outline
                        .withOpacity(0.35),
                  ),
                ),
                child: Row(
                  children: [
                    // ------------------------------------------------
                    // ICON
                    // ------------------------------------------------

                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: colorScheme.primary
                            .withOpacity(0.12),
                        borderRadius:
                        BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.assignment_rounded,
                        color:
                        colorScheme.primary,
                        size: 30,
                      ),
                    ),

                    const SizedBox(width: 14),

                    // ------------------------------------------------
                    // DATA
                    // ------------------------------------------------

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow:
                            TextOverflow.ellipsis,
                            style: theme.textTheme
                                .titleMedium
                                ?.copyWith(
                              fontWeight:
                              FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            subject,
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                            style: theme.textTheme
                                .bodyMedium
                                ?.copyWith(
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            '$className • '
                                '$duration menit • '
                                '$date',
                            maxLines: 2,
                            overflow:
                            TextOverflow.ellipsis,
                            style: theme.textTheme
                                .bodySmall
                                ?.copyWith(
                              color: colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),

                          if (teacherName != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              teacherName,
                              maxLines: 1,
                              overflow:
                              TextOverflow.ellipsis,
                              style: theme.textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color:
                                colorScheme.primary,
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // ------------------------------------------------
                    // MENU
                    // ------------------------------------------------

                    PopupMenuButton<String>(
                      onSelected: (value) {
                        switch (value) {
                          case 'edit':
                            _showExamDialog(
                              document: doc,
                            );
                            break;

                          case 'questions':
                            _openQuestions(doc);
                            break;

                          case 'delete':
                            _deleteExam(
                              doc.id,
                              title,
                            );
                            break;
                        }
                      },
                      itemBuilder: (_) {
                        return const [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          PopupMenuItem<String>(
                            value: 'questions',
                            child: Text(
                              'Kelola Soal',
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text('Hapus'),
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
// MODEL HASIL FORM UJIAN
// ==================================================================

class _ExamFormResult {
  final String title;
  final String subject;
  final String classId;
  final String teacherId;
  final int duration;
  final String date;
  final String description;

  const _ExamFormResult({
    required this.title,
    required this.subject,
    required this.classId,
    required this.teacherId,
    required this.duration,
    required this.date,
    required this.description,
  });
}

// ==================================================================
// DIALOG FORM UJIAN
// ==================================================================

class _ExamFormDialog extends StatefulWidget {
  final bool isEdit;
  final String initialTitle;
  final String initialSubject;
  final String initialDuration;
  final String initialDescription;
  final String initialDate;
  final String initialClass;
  final String initialTeacherId;

  final List<Map<String, String>> classOptions;

  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
  teachers;

  const _ExamFormDialog({
    required this.isEdit,
    required this.initialTitle,
    required this.initialSubject,
    required this.initialDuration,
    required this.initialDescription,
    required this.initialDate,
    required this.initialClass,
    required this.initialTeacherId,
    required this.classOptions,
    required this.teachers,
  });

  @override
  State<_ExamFormDialog> createState() =>
      _ExamFormDialogState();
}

class _ExamFormDialogState
    extends State<_ExamFormDialog> {
  late final TextEditingController titleController;
  late final TextEditingController subjectController;
  late final TextEditingController durationController;
  late final TextEditingController descriptionController;
  late final TextEditingController dateController;

  late String selectedClass;
  late String selectedTeacherId;

  final formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    titleController = TextEditingController(
      text: widget.initialTitle,
    );

    subjectController = TextEditingController(
      text: widget.initialSubject,
    );

    durationController = TextEditingController(
      text: widget.initialDuration,
    );

    descriptionController =
        TextEditingController(
          text: widget.initialDescription,
        );

    dateController = TextEditingController(
      text: widget.initialDate,
    );

    final validClass =
    widget.classOptions.any(
          (item) =>
      item['id'] == widget.initialClass,
    );

    selectedClass = validClass
        ? widget.initialClass
        : widget.classOptions.first['id']!;

    final validTeacher =
    widget.teachers.any(
          (teacher) =>
      teacher.id == widget.initialTeacherId,
    );

    selectedTeacherId = validTeacher
        ? widget.initialTeacherId
        : widget.teachers.first.id;
  }

  @override
  void dispose() {
    titleController.dispose();
    subjectController.dispose();
    durationController.dispose();
    descriptionController.dispose();
    dateController.dispose();

    super.dispose();
  }

  // ============================================================
  // NAMA GURU
  // ============================================================

  String _getTeacherName(
      QueryDocumentSnapshot<Map<String, dynamic>>
      teacher,
      ) {
    final data = teacher.data();

    final name =
    data['name']?.toString().trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    final email =
    data['email']?.toString().trim();

    if (email != null && email.isNotEmpty) {
      return email;
    }

    return teacher.id;
  }

  // ============================================================
  // SIMPAN
  // ============================================================

  void _submit() {
    if (!formKey.currentState!.validate()) {
      return;
    }

    final duration = int.tryParse(
      durationController.text.trim(),
    );

    if (duration == null || duration <= 0) {
      return;
    }

    Navigator.of(context).pop(
      _ExamFormResult(
        title: titleController.text.trim(),
        subject: subjectController.text.trim(),
        classId: selectedClass,
        teacherId: selectedTeacherId,
        duration: duration,
        date: dateController.text.trim(),
        description:
        descriptionController.text.trim(),
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
            ? 'Edit Ujian'
            : 'Tambah Ujian',
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
              mainAxisSize: MainAxisSize.min,
              children: [
                // ==================================================
                // GURU
                // ==================================================

                DropdownButtonFormField<String>(
                  initialValue: selectedTeacherId,
                  isExpanded: true,
                  decoration:
                  const InputDecoration(
                    labelText: 'Guru',
                    prefixIcon: Icon(
                      Icons.person_outline,
                    ),
                  ),
                  items: widget.teachers.map(
                        (teacher) {
                      return DropdownMenuItem<String>(
                        value: teacher.id,
                        child: Text(
                          _getTeacherName(
                            teacher,
                          ),
                          overflow:
                          TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ).toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      selectedTeacherId = value;
                    });
                  },
                ),

                const SizedBox(height: 12),

                // ==================================================
                // JUDUL
                // ==================================================

                TextFormField(
                  controller: titleController,
                  textInputAction:
                  TextInputAction.next,
                  decoration:
                  const InputDecoration(
                    labelText: 'Judul Ujian',
                    prefixIcon: Icon(
                      Icons.assignment_outlined,
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Judul ujian wajib diisi';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // ==================================================
                // MATA PELAJARAN
                // ==================================================

                TextFormField(
                  controller: subjectController,
                  textInputAction:
                  TextInputAction.next,
                  decoration:
                  const InputDecoration(
                    labelText: 'Mata Pelajaran',
                    prefixIcon: Icon(
                      Icons.menu_book_outlined,
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

                const SizedBox(height: 12),

                // ==================================================
                // KELAS
                // ==================================================

                DropdownButtonFormField<String>(
                  initialValue: selectedClass,
                  isExpanded: true,
                  decoration:
                  const InputDecoration(
                    labelText: 'Kelas',
                    prefixIcon: Icon(
                      Icons.class_outlined,
                    ),
                  ),
                  items: widget.classOptions.map(
                        (item) {
                      return DropdownMenuItem<String>(
                        value: item['id'],
                        child: Text(
                          item['name'] ?? '',
                        ),
                      );
                    },
                  ).toList(),
                  onChanged: (value) {
                    if (value == null) return;

                    setState(() {
                      selectedClass = value;
                    });
                  },
                ),

                const SizedBox(height: 12),

                // ==================================================
                // TANGGAL
                // ==================================================

                TextFormField(
                  controller: dateController,
                  textInputAction:
                  TextInputAction.next,
                  decoration:
                  const InputDecoration(
                    labelText: 'Tanggal Ujian',
                    hintText:
                    'Contoh: 15 Oktober 2026',
                    prefixIcon: Icon(
                      Icons.calendar_today_outlined,
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return 'Tanggal ujian wajib diisi';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // ==================================================
                // DURASI
                // ==================================================

                TextFormField(
                  controller: durationController,
                  keyboardType:
                  TextInputType.number,
                  textInputAction:
                  TextInputAction.next,
                  decoration:
                  const InputDecoration(
                    labelText: 'Durasi (menit)',
                    prefixIcon: Icon(
                      Icons.timer_outlined,
                    ),
                  ),
                  validator: (value) {
                    final duration =
                    int.tryParse(
                      value?.trim() ?? '',
                    );

                    if (duration == null ||
                        duration <= 0) {
                      return 'Durasi harus berupa angka lebih dari 0';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 12),

                // ==================================================
                // DESKRIPSI
                // ==================================================

                TextFormField(
                  controller:
                  descriptionController,
                  maxLines: 3,
                  decoration:
                  const InputDecoration(
                    labelText: 'Deskripsi',
                    prefixIcon: Icon(
                      Icons.description_outlined,
                    ),
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
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Batal'),
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
// ADMIN EXAM QUESTIONS SCREEN
// ==================================================================

class AdminExamQuestionsScreen
    extends StatefulWidget {
  final String examId;
  final String examTitle;

  const AdminExamQuestionsScreen({
    super.key,
    required this.examId,
    required this.examTitle,
  });

  @override
  State<AdminExamQuestionsScreen> createState() =>
      _AdminExamQuestionsScreenState();
}

class _AdminExamQuestionsScreenState
    extends State<AdminExamQuestionsScreen> {
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

    if (index < 0 || index >= options.length) {
      return '';
    }

    return options[index]?.toString() ?? '';
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

    final optionsData = data?['options'];

    final result =
    await showDialog<_QuestionFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _QuestionFormDialog(
          isEdit: isEdit,
          initialQuestion:
          data?['question']?.toString() ??
              '',
          initialOptions: List.generate(
            4,
                (index) {
              return _getOption(
                optionsData,
                index,
              );
            },
          ),
          initialAnswer:
          data?['answer']?.toString() ??
              'A',
        );
      },
    );

    if (result == null || !mounted) {
      return;
    }

    try {
      // ----------------------------------------------------------
      // EDIT
      // ----------------------------------------------------------

      if (isEdit) {
        await _firestore.updateExamQuestion(
          examId: widget.examId,
          questionId: document!.id,
          question: result.question,
          options: result.options,
          answer: result.answer,
        );
      }

      // ----------------------------------------------------------
      // TAMBAH
      // ----------------------------------------------------------

      else {
        await _firestore.addExamQuestion(
          examId: widget.examId,
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
            'Apakah kamu yakin ingin menghapus '
                'soal "$question"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(true);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _firestore.deleteExamQuestion(
        examId: widget.examId,
        questionId: id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Soal berhasil dihapus',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor:
      theme.scaffoldBackgroundColor,

      appBar: AppBar(
        title: Text(
          widget.examTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
        theme.scaffoldBackgroundColor,
      ),

      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: _showQuestionDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Soal'),
      ),

      body:
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.getExamQuestions(
          widget.examId,
        ),
        builder: (context, snapshot) {
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
            separatorBuilder: (_, __) {
              return const SizedBox(
                height: 12,
              );
            },
            itemBuilder:
                (context, index) {
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
                        .withOpacity(0.12),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color:
                        colorScheme.primary,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text(
                    question,
                    maxLines: 3,
                    overflow:
                    TextOverflow.ellipsis,
                    style:
                    const TextStyle(
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                  subtitle: Padding(
                    padding:
                    const EdgeInsets.only(
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
                  PopupMenuButton<String>(
                    onSelected: (value) {
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

class _QuestionFormResult {
  final String question;
  final List<String> options;
  final String answer;

  const _QuestionFormResult({
    required this.question,
    required this.options,
    required this.answer,
  });
}

// ==================================================================
// DIALOG FORM SOAL
// ==================================================================

class _QuestionFormDialog
    extends StatefulWidget {
  final bool isEdit;
  final String initialQuestion;
  final List<String> initialOptions;
  final String initialAnswer;

  const _QuestionFormDialog({
    required this.isEdit,
    required this.initialQuestion,
    required this.initialOptions,
    required this.initialAnswer,
  });

  @override
  State<_QuestionFormDialog> createState() =>
      _QuestionFormDialogState();
}

class _QuestionFormDialogState
    extends State<_QuestionFormDialog> {
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

    questionController =
        TextEditingController(
          text: widget.initialQuestion,
        );

    optionControllers =
        List.generate(
          4,
              (index) {
            final value =
            index <
                widget.initialOptions
                    .length
                ? widget.initialOptions[index]
                : '';

            return TextEditingController(
              text: value,
            );
          },
        );

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
  // SIMPAN
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
      _QuestionFormResult(
        question:
        questionController.text.trim(),
        options: options,
        answer: selectedAnswer,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    return AlertDialog(
      title: Text(
        widget.isEdit
            ? 'Edit Soal'
            : 'Tambah Soal',
        style: const TextStyle(
          fontWeight:
          FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 550,
        child: Form(
          key: formKey,
          child:
          SingleChildScrollView(
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              children: [
                TextFormField(
                  controller:
                  questionController,
                  maxLines: 4,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Pertanyaan',
                    prefixIcon:
                    Icon(
                      Icons
                          .help_outline_rounded,
                    ),
                    alignLabelWithHint:
                    true,
                  ),
                  validator:
                      (value) {
                    if (value == null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'Pertanyaan wajib diisi';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 16,
                ),

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
                            child:
                            Text(
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

                DropdownButtonFormField<
                    String>(
                  initialValue:
                  selectedAnswer,
                  isExpanded: true,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Jawaban Benar',
                    prefixIcon:
                    Icon(
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
                  onChanged:
                      (value) {
                    if (value ==
                        null) {
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
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context)
                .pop();
          },
          child:
          const Text('Batal'),
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