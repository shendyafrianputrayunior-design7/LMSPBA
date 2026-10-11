import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class AdminMaterialsScreen extends StatefulWidget {
  const AdminMaterialsScreen({super.key});

  @override
  State<AdminMaterialsScreen> createState() =>
      _AdminMaterialsScreenState();
}

class _AdminMaterialsScreenState
    extends State<AdminMaterialsScreen> {
  final FirestoreService _firestore =
      FirestoreService.instance;

  // ============================================================
  // TAMBAH / EDIT MATERI
  // ============================================================

  Future<void> _showMaterialDialog({
    String? id,
    Map<String, dynamic>? material,
  }) async {
    final result = await showDialog<_MaterialFormResult>(
      context: context,
      builder: (dialogContext) {
        return _MaterialFormDialog(
          id: id,
          material: material,
        );
      },
    );

    if (result == null) return;
    if (!mounted) return;

    try {
      // ========================================================
      // EDIT
      // ========================================================

      if (result.id != null) {
        await _firestore.updateMaterial(
          id: result.id!,
          classId: result.classId,
          className: result.className,
          teacherId: 'teacher_001',
          teacherName: result.teacherName,
          courseId: result.courseId,
          courseName: result.courseName,
          subject: result.subject,
          title: result.title,
          description: result.description,
          content: result.content,
          type: result.type,
          fileUrl: result.fileUrl,
          attachmentUrl: result.attachmentUrl,
          videoUrl: result.videoUrl,
          videoFileName: result.videoFileName,
          videoSize: result.videoSize,
        );
      }

      // ========================================================
      // TAMBAH
      // ========================================================

      else {
        await _firestore.addMaterial(
          classId: result.classId,
          className: result.className,
          teacherId: 'teacher_001',
          teacherName: result.teacherName,
          courseId: result.courseId,
          courseName: result.courseName,
          subject: result.subject,
          title: result.title,
          description: result.description,
          content: result.content,
          type: result.type,
          fileUrl: result.fileUrl,
          attachmentUrl: result.attachmentUrl,
          videoUrl: result.videoUrl,
          videoFileName: result.videoFileName,
          videoSize: result.videoSize,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.id != null
                ? 'Materi berhasil diperbarui'
                : 'Materi berhasil ditambahkan',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan materi: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // HAPUS MATERI
  // ============================================================

  Future<void> _deleteMaterial(
      String id,
      String title,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Materi'),
          content: Text(
            'Apakah kamu yakin ingin menghapus "$title"?',
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

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await _firestore.deleteMaterial(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Materi berhasil dihapus',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus materi: $e',
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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: const Text(
          'Kelola Materi',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showMaterialDialog();
        },
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Tambah Materi',
        ),
      ),
      body: StreamBuilder(
        stream: _firestore.getMaterials(),
        builder: (
            context,
            snapshot,
            ) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState(
              context,
              snapshot.error.toString(),
            );
          }

          final materials =
              snapshot.data?.docs ?? [];

          if (materials.isEmpty) {
            return _buildEmptyState(
              context,
              colorScheme,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              100,
            ),
            itemCount: materials.length,
            separatorBuilder: (_, __) {
              return const SizedBox(
                height: 12,
              );
            },
            itemBuilder: (
                context,
                index,
                ) {
              final document =
              materials[index];

              final data =
              document.data();

              return _buildMaterialCard(
                context,
                document.id,
                data,
                colorScheme,
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // MATERIAL CARD
  // ============================================================

  Widget _buildMaterialCard(
      BuildContext context,
      String id,
      Map<String, dynamic> material,
      ColorScheme colorScheme,
      ) {
    final theme = Theme.of(context);

    final title =
        material['title']?.toString() ?? '-';

    final subject =
        material['subject']?.toString() ?? '-';

    final className =
    material['className']?.toString().trim().isNotEmpty ==
        true
        ? material['className'].toString()
        : _classNameFromId(
      material['classId']?.toString() ?? '',
    );

    final courseName =
        material['courseName']?.toString() ?? '';

    final type =
        material['type']?.toString() ?? '-';

    final description =
        material['description']?.toString() ?? '-';

    final fileUrl =
        material['fileUrl']?.toString() ?? '';

    IconData typeIcon;

    switch (type) {
      case 'Video':
        typeIcon =
            Icons.play_circle_outline_rounded;
        break;

      case 'Dokumen':
        typeIcon =
            Icons.description_outlined;
        break;

      case 'Link':
        typeIcon =
            Icons.link_rounded;
        break;

      default:
        typeIcon =
            Icons.picture_as_pdf_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline
              .withOpacity(0.35),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colorScheme.primary
                      .withOpacity(0.10),
                  borderRadius:
                  BorderRadius.circular(16),
                ),
                child: Icon(
                  typeIcon,
                  color:
                  colorScheme.primary,
                  size: 28,
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
                      overflow:
                      TextOverflow.ellipsis,
                      style: theme
                          .textTheme
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
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        color:
                        colorScheme.primary,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showMaterialDialog(
                      id: id,
                      material: material,
                    );
                  } else if (value == 'delete') {
                    _deleteMaterial(
                      id,
                      title,
                    );
                  }
                },
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                          ),
                          SizedBox(width: 10),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                          ),
                          SizedBox(width: 10),
                          Text('Hapus'),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          Divider(
            height: 1,
            color: colorScheme.outline
                .withOpacity(0.20),
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              _buildTag(
                context,
                Icons.class_outlined,
                className,
              ),

              const SizedBox(width: 8),

              _buildTag(
                context,
                Icons.attach_file_rounded,
                type,
              ),
            ],
          ),

          if (courseName.isNotEmpty) ...[
            const SizedBox(height: 10),

            Align(
              alignment:
              Alignment.centerLeft,
              child: Text(
                'Course: $courseName',
                maxLines: 1,
                overflow:
                TextOverflow.ellipsis,
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color:
                  colorScheme.primary,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          Align(
            alignment:
            Alignment.centerLeft,
            child: Text(
              description,
              maxLines: 3,
              overflow:
              TextOverflow.ellipsis,
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color:
                colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),

          if (fileUrl.isNotEmpty &&
              fileUrl != '-') ...[
            const SizedBox(height: 10),

            Align(
              alignment:
              Alignment.centerLeft,
              child: Text(
                fileUrl,
                maxLines: 2,
                overflow:
                TextOverflow.ellipsis,
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color:
                  colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // CLASS NAME
  // ============================================================

  String _classNameFromId(String classId) {
    switch (classId) {
      case 'X_RPL_1':
        return 'X RPL 1';

      case 'XI_RPL_1':
        return 'XI RPL 1';

      case 'XI_RPL_2':
        return 'XI RPL 2';

      case 'XII_RPL_1':
        return 'XII RPL 1';

      default:
        return classId.isEmpty ? '-' : classId;
    }
  }

  // ============================================================
  // TAG
  // ============================================================

  Widget _buildTag(
      BuildContext context,
      IconData icon,
      String text,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary
            .withOpacity(0.08),
        borderRadius:
        BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color:
            colorScheme.primary,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: theme
                .textTheme
                .labelSmall
                ?.copyWith(
              color:
              colorScheme.primary,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState(
      BuildContext context,
      ColorScheme colorScheme,
      ) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: colorScheme
                  .onSurfaceVariant,
            ),

            const SizedBox(height: 16),

            const Text(
              'Belum ada materi',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Tambahkan materi pembelajaran '
                  'menggunakan tombol di bawah.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color: colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState(
      BuildContext context,
      String error,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 60,
              color:
              colorScheme.error,
            ),

            const SizedBox(height: 16),

            Text(
              'Gagal memuat materi',
              style: theme
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight:
                FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              error,
              textAlign:
              TextAlign.center,
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: () {
                setState(() {});
              },
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label:
              const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// FORM RESULT
// ================================================================

class _MaterialFormResult {
  final String? id;

  final String title;
  final String subject;

  final String courseId;
  final String courseName;

  final String classId;
  final String className;

  final String teacherName;

  final String type;
  final String fileUrl;

  final String description;
  final String content;

  final String attachmentUrl;

  final String videoUrl;
  final String videoFileName;
  final int videoSize;

  const _MaterialFormResult({
    this.id,
    required this.title,
    required this.subject,
    required this.courseId,
    required this.courseName,
    required this.classId,
    required this.className,
    required this.teacherName,
    required this.type,
    required this.fileUrl,
    required this.description,
    required this.content,
    required this.attachmentUrl,
    required this.videoUrl,
    required this.videoFileName,
    required this.videoSize,
  });
}

// ================================================================
// MATERIAL FORM DIALOG
// ================================================================

class _MaterialFormDialog extends StatefulWidget {
  final String? id;
  final Map<String, dynamic>? material;

  const _MaterialFormDialog({
    this.id,
    this.material,
  });

  @override
  State<_MaterialFormDialog> createState() =>
      _MaterialFormDialogState();
}

class _MaterialFormDialogState
    extends State<_MaterialFormDialog> {
  final _formKey =
  GlobalKey<FormState>();

  final FirebaseFirestore _db =
      FirebaseFirestore.instance;

  late final TextEditingController
  _titleController;

  late final TextEditingController
  _subjectController;

  late final TextEditingController
  _descriptionController;

  late final TextEditingController
  _contentController;

  late final TextEditingController
  _fileUrlController;

  List<Map<String, dynamic>> _courses = [];

  String? _selectedCourseId;

  bool _loadingCourses = true;
  bool _saving = false;

  bool get isEdit =>
      widget.id != null;

  String _teacherName = 'Bapak Andi';

  String _selectedClassId = '';
  String _selectedClassName = '';

  static const materialTypes = [
    'PDF',
    'Video',
    'Dokumen',
    'Link',
  ];

  String selectedType = 'PDF';

  @override
  void initState() {
    super.initState();

    final material =
        widget.material;

    _titleController =
        TextEditingController(
          text:
          material?['title']
              ?.toString() ??
              '',
        );

    _subjectController =
        TextEditingController(
          text:
          material?['subject']
              ?.toString() ??
              '',
        );

    _descriptionController =
        TextEditingController(
          text:
          material?['description']
              ?.toString() ??
              '',
        );

    _contentController =
        TextEditingController(
          text:
          material?['content']
              ?.toString() ??
              '',
        );

    _fileUrlController =
        TextEditingController(
          text:
          material?['fileUrl']
              ?.toString() ??
              '',
        );

    final savedType =
    material?['type']
        ?.toString()
        .trim();

    if (materialTypes.contains(savedType)) {
      selectedType = savedType!;
    }

    _teacherName =
    material?['teacherName']
        ?.toString()
        .trim()
        .isNotEmpty ==
        true
        ? material!['teacherName']
        .toString()
        : 'Bapak Andi';

    _selectedCourseId =
        material?['courseId']
            ?.toString()
            .trim();

    _selectedClassId =
        material?['classId']
            ?.toString() ??
            '';

    _selectedClassName =
        material?['className']
            ?.toString() ??
            '';

    _loadCourses();
  }

  // ============================================================
  // LOAD COURSES
  // ============================================================

  Future<void> _loadCourses() async {
    try {
      final snapshot = await _db
          .collection('courses')
          .orderBy('title')
          .get();

      final loaded = snapshot.docs.map((doc) {
        final data = doc.data();

        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _courses = loaded;
        _loadingCourses = false;
      });

      if (_selectedCourseId != null) {
        final exists = _courses.any(
              (course) =>
          course['id'] ==
              _selectedCourseId,
        );

        if (!exists) {
          setState(() {
            _selectedCourseId = null;
          });
        } else {
          _applyCourse(
            _courses.firstWhere(
                  (course) =>
              course['id'] ==
                  _selectedCourseId,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingCourses = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memuat course: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // APPLY COURSE
  // ============================================================

  void _applyCourse(
      Map<String, dynamic> course,
      ) {
    final courseId =
        course['id']?.toString() ?? '';

    final courseName =
        course['title']?.toString() ??
            course['name']?.toString() ??
            '';

    final classId =
        course['classId']?.toString() ??
            '';

    final className =
        course['className']?.toString() ??
            '';

    setState(() {
      _selectedCourseId =
          courseId;

      _selectedClassId =
          classId;

      _selectedClassName =
          className;

      if (_subjectController.text
          .trim()
          .isEmpty) {
        _subjectController.text =
            courseName;
      }
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _fileUrlController.dispose();

    super.dispose();
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  void _submit() {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCourseId == null ||
        _selectedCourseId!.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Course wajib dipilih',
          ),
        ),
      );
      return;
    }

    if (_selectedClassId.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Course belum memiliki classId',
          ),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    final selectedCourse =
    _courses.firstWhere(
          (course) =>
      course['id'] ==
          _selectedCourseId,
      orElse: () => {},
    );

    final courseName =
        selectedCourse['title']
            ?.toString() ??
            selectedCourse['name']
                ?.toString() ??
            '';

    final result =
    _MaterialFormResult(
      id: widget.id,

      title:
      _titleController.text.trim(),

      subject:
      _subjectController.text.trim(),

      courseId:
      _selectedCourseId!,

      courseName:
      courseName,

      classId:
      _selectedClassId,

      className:
      _selectedClassName,

      teacherName:
      _teacherName,

      type:
      selectedType,

      fileUrl:
      _fileUrlController.text.trim(),

      description:
      _descriptionController.text.trim(),

      content:
      _contentController.text.trim(),

      attachmentUrl:
      _fileUrlController.text.trim(),

      videoUrl:
      selectedType == 'Video'
          ? _fileUrlController.text.trim()
          : '',

      videoFileName:
      '',

      videoSize:
      0,
    );

    Navigator.of(context)
        .pop(result);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        isEdit
            ? 'Edit Materi'
            : 'Tambah Materi',
      ),
      content: Form(
        key: _formKey,
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
                _titleController,
                decoration:
                const InputDecoration(
                  labelText:
                  'Judul Materi',
                  hintText:
                  'Contoh: Pengenalan Flutter',
                  prefixIcon: Icon(
                    Icons.title_rounded,
                  ),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Judul materi wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              // ==================================================
              // MATA PELAJARAN
              // ==================================================

              TextFormField(
                controller:
                _subjectController,
                decoration:
                const InputDecoration(
                  labelText:
                  'Mata Pelajaran',
                  hintText:
                  'Contoh: Pemrograman Mobile',
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

              const SizedBox(height: 14),

              // ==================================================
              // COURSE
              // ==================================================

              if (_loadingCourses)
                const Padding(
                  padding:
                  EdgeInsets.symmetric(
                    vertical: 12,
                  ),
                  child:
                  CircularProgressIndicator(),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue:
                  _courses.any(
                        (course) =>
                    course['id'] ==
                        _selectedCourseId,
                  )
                      ? _selectedCourseId
                      : null,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Course',
                    prefixIcon: Icon(
                      Icons.school_outlined,
                    ),
                  ),
                  items: _courses.map(
                        (course) {
                      final id =
                      course['id']
                          .toString();

                      final name =
                          course['title']
                              ?.toString() ??
                              course['name']
                                  ?.toString() ??
                              id;

                      return DropdownMenuItem<
                          String>(
                        value: id,
                        child: Text(
                          name,
                          overflow:
                          TextOverflow.ellipsis,
                        ),
                      );
                    },
                  ).toList(),
                  onChanged: _saving
                      ? null
                      : (value) {
                    if (value ==
                        null) {
                      return;
                    }

                    final course =
                    _courses.firstWhere(
                          (item) =>
                      item['id'] ==
                          value,
                    );

                    _applyCourse(
                      course,
                    );
                  },
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'Course wajib dipilih';
                    }

                    return null;
                  },
                ),

              const SizedBox(height: 14),

              // ==================================================
              // KELAS
              // ==================================================

              TextFormField(
                readOnly: true,
                controller:
                TextEditingController(
                  text:
                  _selectedClassName.isNotEmpty
                      ? _selectedClassName
                      : _selectedClassId,
                ),
                decoration:
                const InputDecoration(
                  labelText: 'Kelas',
                  prefixIcon: Icon(
                    Icons.class_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ==================================================
              // JENIS MATERI
              // ==================================================

              DropdownButtonFormField<String>(
                initialValue:
                selectedType,
                decoration:
                const InputDecoration(
                  labelText:
                  'Jenis Materi',
                  prefixIcon: Icon(
                    Icons.attach_file_rounded,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'PDF',
                    child:
                    Text('PDF'),
                  ),
                  DropdownMenuItem(
                    value: 'Video',
                    child:
                    Text('Video'),
                  ),
                  DropdownMenuItem(
                    value: 'Dokumen',
                    child:
                    Text('Dokumen'),
                  ),
                  DropdownMenuItem(
                    value: 'Link',
                    child:
                    Text('Link'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                  if (value ==
                      null) {
                    return;
                  }

                  setState(() {
                    selectedType =
                        value;
                  });
                },
              ),

              const SizedBox(height: 14),

              // ==================================================
              // URL
              // ==================================================

              TextFormField(
                controller:
                _fileUrlController,
                keyboardType:
                TextInputType.url,
                decoration:
                const InputDecoration(
                  labelText:
                  'URL Materi',
                  hintText:
                  'Masukkan link file / video / dokumen',
                  prefixIcon: Icon(
                    Icons.link_rounded,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ==================================================
              // DESKRIPSI
              // ==================================================

              TextFormField(
                controller:
                _descriptionController,
                maxLines: 3,
                decoration:
                const InputDecoration(
                  labelText:
                  'Deskripsi',
                  hintText:
                  'Deskripsi singkat materi',
                  prefixIcon: Icon(
                    Icons.description_outlined,
                  ),
                  alignLabelWithHint:
                  true,
                ),
              ),

              const SizedBox(height: 14),

              // ==================================================
              // CONTENT
              // ==================================================

              TextFormField(
                controller:
                _contentController,
                maxLines: 2,
                decoration:
                const InputDecoration(
                  labelText:
                  'Content',
                  hintText:
                  'Isi/topik materi',
                  prefixIcon: Icon(
                    Icons.notes_rounded,
                  ),
                  alignLabelWithHint:
                  true,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving
              ? null
              : () {
            Navigator.of(
              context,
            ).pop();
          },
          child:
          const Text('Batal'),
        ),

        FilledButton(
          onPressed:
          _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
            width: 18,
            height: 18,
            child:
            CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
              : Text(
            isEdit
                ? 'Simpan Perubahan'
                : 'Simpan',
          ),
        ),
      ],
    );
  }
}