import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/course.dart';
import '../services/cloudinary_service.dart';

class TeacherLessonFormScreen extends StatefulWidget {
  final Course course;
  final String? lessonId;
  final Map<String, dynamic>? lessonData;

  const TeacherLessonFormScreen({
    super.key,
    required this.course,
    this.lessonId,
    this.lessonData,
  });

  bool get isEdit => lessonId != null;

  @override
  State<TeacherLessonFormScreen> createState() =>
      _TeacherLessonFormScreenState();
}

class _TeacherLessonFormScreenState
    extends State<TeacherLessonFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _durationController = TextEditingController();
  final _orderController = TextEditingController();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  File? _selectedVideo;

  String? _videoUrl;
  String? _videoFileName;
  int? _videoSize;

  String? _teacherId;

  bool _loading = false;
  bool _uploadingVideo = false;
  bool _loadingTeacher = true;

  @override
  void initState() {
    super.initState();

    _loadTeacherProfile();

    if (widget.isEdit) {
      _fillExistingData();
    } else {
      _loadNextOrder();
    }
  }

  // ===============================================================
  // GET CANONICAL TEACHER DOCUMENT ID
  // ===============================================================

  Future<String?> _getTeacherDocumentId() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    // -------------------------------------------------------------
    // PRIORITAS 1:
    // users/{uid}.teacherId
    // -------------------------------------------------------------

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();

      final teacherId =
      userData?['teacherId']?.toString().trim();

      if (teacherId != null &&
          teacherId.isNotEmpty) {
        return teacherId;
      }
    } catch (_) {
      // Lanjut ke fallback email.
    }

    // -------------------------------------------------------------
    // PRIORITAS 2:
    // teachers.email == Firebase Auth email
    // -------------------------------------------------------------

    final email = user.email?.trim();

    if (email != null &&
        email.isNotEmpty) {
      try {
        final teacherQuery = await _firestore
            .collection('teachers')
            .where(
          'email',
          isEqualTo: email,
        )
            .limit(1)
            .get();

        if (teacherQuery.docs.isNotEmpty) {
          return teacherQuery.docs.first.id;
        }
      } catch (_) {
        // Teacher tidak ditemukan.
      }
    }

    return null;
  }

  // ===============================================================
  // LOAD TEACHER PROFILE
  // ===============================================================

  Future<void> _loadTeacherProfile() async {
    final teacherId =
    await _getTeacherDocumentId();

    if (!mounted) return;

    setState(() {
      _teacherId = teacherId;
      _loadingTeacher = false;
    });
  }

  // ===============================================================
  // LOAD DATA EDIT
  // ===============================================================

  void _fillExistingData() {
    final data =
        widget.lessonData ?? {};

    _titleController.text =
        (data['title'] ?? '').toString();

    _contentController.text =
        (data['content'] ?? '').toString();

    _durationController.text =
        (data['duration'] ?? '').toString();

    _orderController.text =
        (data['order'] ?? 1).toString();

    final existingVideoUrl =
    (data['videoUrl'] ?? '')
        .toString()
        .trim();

    final existingVideoFileName =
    (data['videoFileName'] ?? '')
        .toString()
        .trim();

    final existingVideoSize =
    data['videoSize'];

    if (existingVideoUrl.isNotEmpty) {
      _videoUrl = existingVideoUrl;
    }

    if (existingVideoFileName.isNotEmpty) {
      _videoFileName =
          existingVideoFileName;
    }

    if (existingVideoSize is int) {
      _videoSize = existingVideoSize;
    } else if (existingVideoSize != null) {
      _videoSize = int.tryParse(
        existingVideoSize.toString(),
      );
    }
  }

  // ===============================================================
  // LOAD NEXT ORDER
  // ===============================================================

  Future<void> _loadNextOrder() async {
    try {
      final snapshot = await _firestore
          .collection('course_lessons')
          .where(
        'courseId',
        isEqualTo: widget.course.id,
      )
          .get();

      if (!mounted) return;

      int nextOrder = 1;

      for (final doc in snapshot.docs) {
        final value =
        doc.data()['order'];

        final order = value is int
            ? value
            : int.tryParse(
          value?.toString() ?? '',
        );

        if (order != null &&
            order >= nextOrder) {
          nextOrder = order + 1;
        }
      }

      _orderController.text =
          nextOrder.toString();
    } catch (_) {
      _orderController.text = '1';
    }
  }

  // ===============================================================
  // PICK VIDEO
  // ===============================================================

  Future<void> _pickVideo() async {
    if (_loading ||
        _uploadingVideo) {
      return;
    }

    try {
      final result =
      await FilePicker.pickFile(
        type: FileType.video,
      );

      if (result == null) {
        return;
      }

      final filePath =
          result.path;

      if (filePath == null ||
          filePath.isEmpty) {
        _showMessage(
          'File video tidak dapat diakses.',
        );
        return;
      }

      final file =
      File(filePath);

      if (!await file.exists()) {
        _showMessage(
          'File video tidak ditemukan.',
        );
        return;
      }

      final size =
      await file.length();

      const maxSize =
          100 * 1024 * 1024;

      if (size > maxSize) {
        _showMessage(
          'Ukuran video maksimal 100 MB.',
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _selectedVideo = file;
        _videoFileName = result.name;
        _videoSize = size;
      });
    } catch (e) {
      _showMessage(
        'Gagal memilih video: $e',
      );
    }
  }

  // ===============================================================
  // UPLOAD VIDEO
  // ===============================================================

  Future<bool> _uploadVideo() async {
    final video =
        _selectedVideo;

    if (video == null) {
      return true;
    }

    if (!mounted) return false;

    setState(() {
      _uploadingVideo = true;
    });

    try {
      final uploadedUrl =
      await CloudinaryService
          .uploadLessonVideo(
        video,
      );

      if (uploadedUrl == null ||
          uploadedUrl.trim().isEmpty) {
        if (mounted) {
          _showMessage(
            'Upload video gagal.',
          );
        }

        return false;
      }

      final size =
      await video.length();

      if (!mounted) return false;

      setState(() {
        _videoUrl = uploadedUrl;

        _videoFileName = video.path
            .split(
          Platform.pathSeparator,
        )
            .last;

        _videoSize = size;
        _selectedVideo = null;
      });

      return true;
    } catch (e) {
      if (mounted) {
        _showMessage(
          'Gagal upload video: $e',
        );
      }

      return false;
    } finally {
      if (mounted) {
        setState(() {
          _uploadingVideo = false;
        });
      }
    }
  }

  // ===============================================================
  // REMOVE EXISTING VIDEO
  // ===============================================================

  void _removeExistingVideo() {
    if (_loading ||
        _uploadingVideo) {
      return;
    }

    setState(() {
      _videoUrl = null;
      _videoFileName = null;
      _videoSize = null;
      _selectedVideo = null;
    });
  }

  // ===============================================================
  // SAVE LESSON
  // ===============================================================

  Future<void> _saveLesson() async {
    if (_loading ||
        _uploadingVideo) {
      return;
    }

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final user =
        _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Akun guru tidak ditemukan.',
      );
      return;
    }

    // -------------------------------------------------------------
    // Pastikan teacherId sudah tersedia
    // -------------------------------------------------------------

    String? teacherId =
        _teacherId;

    if (teacherId == null ||
        teacherId.isEmpty) {
      teacherId =
      await _getTeacherDocumentId();
    }

    if (teacherId == null ||
        teacherId.isEmpty) {
      _showMessage(
        'Data guru tidak ditemukan. '
            'Pastikan akun Anda sudah terhubung '
            'dengan data guru.',
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _loading = true;
      _teacherId = teacherId;
    });

    try {
      // -----------------------------------------------------------
      // Upload video baru terlebih dahulu
      // -----------------------------------------------------------

      if (_selectedVideo != null) {
        final uploaded =
        await _uploadVideo();

        if (!uploaded) {
          if (mounted) {
            setState(() {
              _loading = false;
            });
          }

          return;
        }
      }

      final duration =
          int.tryParse(
            _durationController.text
                .trim(),
          ) ??
              0;

      final order =
          int.tryParse(
            _orderController.text
                .trim(),
          ) ??
              1;

      // ===========================================================
      // DATA LESSON
      // ===========================================================

      final lessonData =
      <String, dynamic>{
        'courseId':
        widget.course.id,

        'courseName':
        widget.course.title,

        // ========================================================
        // PENTING:
        // Gunakan document ID dari teachers,
        // bukan Firebase Auth UID.
        // ========================================================

        'teacherId':
        teacherId,

        'title':
        _titleController.text
            .trim(),

        'content':
        _contentController.text
            .trim(),

        'duration':
        duration,

        'order':
        order,

        'videoUrl':
        _videoUrl ?? '',

        'videoFileName':
        _videoFileName ?? '',

        'videoSize':
        _videoSize ?? 0,

        'updatedAt':
        FieldValue
            .serverTimestamp(),
      };

      // ===========================================================
      // EDIT
      // ===========================================================

      if (widget.isEdit) {
        await _firestore
            .collection(
          'course_lessons',
        )
            .doc(widget.lessonId)
            .update(
          lessonData,
        );
      }

      // ===========================================================
      // TAMBAH
      // ===========================================================

      else {
        await _firestore
            .collection(
          'course_lessons',
        )
            .add({
          ...lessonData,
          'createdAt':
          FieldValue
              .serverTimestamp(),
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdit
                ? 'Materi berhasil diperbarui.'
                : 'Materi berhasil ditambahkan.',
          ),
        ),
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        widget.isEdit
            ? 'Gagal memperbarui materi: $e'
            : 'Gagal menambahkan materi: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ===============================================================
  // MESSAGE
  // ===============================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content:
        Text(message),
        behavior:
        SnackBarBehavior.floating,
      ),
    );
  }

  // ===============================================================
  // INPUT DECORATION
  // ===============================================================

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    final theme =
    Theme.of(context);

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon:
      Icon(icon),
      filled: true,
      fillColor: theme
          .colorScheme
          .surfaceContainerHighest
          .withOpacity(0.35),
      border:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          14,
        ),
        borderSide:
        BorderSide.none,
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          14,
        ),
        borderSide:
        BorderSide.none,
      ),
      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          14,
        ),
        borderSide:
        BorderSide(
          color:
          theme.colorScheme.primary,
          width: 1.5,
        ),
      ),
    );
  }

  // ===============================================================
  // FORMAT FILE SIZE
  // ===============================================================

  String _formatFileSize(
      int? bytes,
      ) {
    if (bytes == null ||
        bytes <= 0) {
      return '';
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes <
        1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes <
        1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  // ===============================================================
  // VIDEO SECTION
  // ===============================================================

  Widget _buildVideoSection() {
    final theme =
    Theme.of(context);

    final hasExistingVideo =
        _videoUrl != null &&
            _videoUrl!
                .trim()
                .isNotEmpty;

    final hasSelectedVideo =
        _selectedVideo != null;

    final hasVideo =
        hasExistingVideo ||
            hasSelectedVideo;

    return Container(
      padding:
      const EdgeInsets.all(16),
      decoration:
      BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.35),
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        border:
        Border.all(
          color: theme
              .colorScheme
              .outline
              .withOpacity(0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,
        children: [
          // =====================================================
          // HEADER
          // =====================================================

          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                BoxDecoration(
                  color: theme
                      .colorScheme
                      .primaryContainer,
                  borderRadius:
                  BorderRadius
                      .circular(
                    12,
                  ),
                ),
                child: Icon(
                  Icons
                      .video_library_outlined,
                  color: theme
                      .colorScheme
                      .onPrimaryContainer,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      'Video Lesson',
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                        FontWeight
                            .bold,
                      ),
                    ),
                    const SizedBox(
                      height: 3,
                    ),
                    Text(
                      'Tambahkan video pembelajaran untuk lesson ini.',
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: theme
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 16,
          ),

          // =====================================================
          // BELUM ADA VIDEO
          // =====================================================

          if (!hasVideo)
            Container(
              width:
              double.infinity,
              padding:
              const EdgeInsets
                  .symmetric(
                vertical: 24,
                horizontal: 16,
              ),
              decoration:
              BoxDecoration(
                borderRadius:
                BorderRadius
                    .circular(
                  14,
                ),
                border:
                Border.all(
                  color: theme
                      .colorScheme
                      .outline
                      .withOpacity(
                    0.5,
                  ),
                ),
              ),
              child:
              Column(
                children: [
                  Icon(
                    Icons
                        .video_file_outlined,
                    size: 42,
                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Text(
                    'Belum ada video',
                    style: theme
                        .textTheme
                        .titleSmall
                        ?.copyWith(
                      fontWeight:
                      FontWeight
                          .w600,
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    'Format video seperti MP4 dapat digunakan.',
                    textAlign:
                    TextAlign
                        .center,
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: theme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(
                    height: 16,
                  ),
                  OutlinedButton
                      .icon(
                    onPressed:
                    _loading ||
                        _uploadingVideo
                        ? null
                        : _pickVideo,
                    icon:
                    const Icon(
                      Icons
                          .upload_file_rounded,
                    ),
                    label:
                    const Text(
                      'Pilih Video',
                    ),
                  ),
                ],
              ),
            )

          // =====================================================
          // ADA VIDEO
          // =====================================================

          else
            Container(
              width:
              double.infinity,
              padding:
              const EdgeInsets
                  .all(14),
              decoration:
              BoxDecoration(
                color: theme
                    .colorScheme
                    .primaryContainer
                    .withOpacity(
                  0.45,
                ),
                borderRadius:
                BorderRadius
                    .circular(
                  14,
                ),
              ),
              child:
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration:
                    BoxDecoration(
                      color: theme
                          .colorScheme
                          .primary,
                      borderRadius:
                      BorderRadius
                          .circular(
                        12,
                      ),
                    ),
                    child:
                    const Icon(
                      Icons
                          .play_arrow_rounded,
                      color:
                      Colors.white,
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child:
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          _videoFileName ??
                              'Video Lesson',
                          maxLines: 2,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style: theme
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                            fontWeight:
                            FontWeight
                                .bold,
                          ),
                        ),
                        if (_videoSize !=
                            null &&
                            _videoSize! >
                                0) ...[
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            _formatFileSize(
                              _videoSize,
                            ),
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: theme
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                        if (hasExistingVideo &&
                            !hasSelectedVideo) ...[
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            'Video tersimpan',
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color:
                              Colors.green,
                              fontWeight:
                              FontWeight
                                  .w600,
                            ),
                          ),
                        ],
                        if (hasSelectedVideo) ...[
                          const SizedBox(
                            height: 3,
                          ),
                          Text(
                            'Video baru dipilih',
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: theme
                                  .colorScheme
                                  .primary,
                              fontWeight:
                              FontWeight
                                  .w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<
                      String>(
                    enabled:
                    !_loading &&
                        !_uploadingVideo,
                    onSelected:
                        (value) {
                      if (value ==
                          'replace') {
                        _pickVideo();
                      } else if (value ==
                          'remove') {
                        _removeExistingVideo();
                      }
                    },
                    itemBuilder:
                        (context) =>
                    const [
                      PopupMenuItem(
                        value:
                        'replace',
                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .swap_horiz_rounded,
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Text(
                              'Ganti Video',
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value:
                        'remove',
                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .delete_outline,
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Text(
                              'Hapus Video',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // =====================================================
          // UPLOAD STATUS
          // =====================================================

          if (_uploadingVideo) ...[
            const SizedBox(
              height: 16,
            ),
            const LinearProgressIndicator(),
            const SizedBox(
              height: 8,
            ),
            Text(
              'Mengupload video ke Cloudinary...',
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: theme
                    .colorScheme
                    .primary,
                fontWeight:
                FontWeight
                    .w600,
              ),
            ),
          ],

          const SizedBox(
            height: 12,
          ),

          Text(
            'Maksimal ukuran video: 100 MB',
            style: theme
                .textTheme
                .bodySmall
                ?.copyWith(
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // DISPOSE
  // ===============================================================

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _durationController.dispose();
    _orderController.dispose();

    super.dispose();
  }

  // ===============================================================
  // BUILD
  // ===============================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEdit
              ? 'Edit Materi'
              : 'Tambah Materi',
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding:
            const EdgeInsets.all(
              20,
            ),
            children: [
              Text(
                widget.isEdit
                    ? 'Edit Materi'
                    : 'Buat Materi Baru',
                style: theme
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                widget.isEdit
                    ? 'Perbarui informasi materi pembelajaran.'
                    : 'Tambahkan materi pembelajaran untuk course ini.',
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              // ===================================================
              // COURSE
              // ===================================================

              Container(
                padding:
                const EdgeInsets.all(
                  16,
                ),
                decoration:
                BoxDecoration(
                  color: theme
                      .colorScheme
                      .primaryContainer,
                  borderRadius:
                  BorderRadius.circular(
                    16,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons
                          .menu_book_outlined,
                      color: theme
                          .colorScheme
                          .onPrimaryContainer,
                    ),
                    const SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(
                            'Course',
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: theme
                                  .colorScheme
                                  .onPrimaryContainer
                                  .withOpacity(
                                0.75,
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 2,
                          ),
                          Text(
                            widget
                                .course
                                .title,
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
                                  .bold,
                              color: theme
                                  .colorScheme
                                  .onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 20,
              ),

              // ===================================================
              // TITLE
              // ===================================================

              TextFormField(
                controller:
                _titleController,
                textInputAction:
                TextInputAction
                    .next,
                decoration:
                _inputDecoration(
                  label:
                  'Judul Materi',
                  hint:
                  'Contoh: Pengenalan Flutter',
                  icon: Icons
                      .title_outlined,
                ),
                validator:
                    (value) {
                  if (value ==
                      null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Judul materi wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 16,
              ),

              // ===================================================
              // CONTENT
              // ===================================================

              TextFormField(
                controller:
                _contentController,
                maxLines: 8,
                textInputAction:
                TextInputAction
                    .newline,
                decoration:
                _inputDecoration(
                  label:
                  'Isi Materi',
                  hint:
                  'Tulis materi pembelajaran di sini...',
                  icon: Icons
                      .description_outlined,
                ),
                validator:
                    (value) {
                  if (value ==
                      null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Isi materi wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 16,
              ),

              // ===================================================
              // DURATION + ORDER
              // ===================================================

              Row(
                children: [
                  Expanded(
                    child:
                    TextFormField(
                      controller:
                      _durationController,
                      keyboardType:
                      TextInputType
                          .number,
                      textInputAction:
                      TextInputAction
                          .next,
                      decoration:
                      _inputDecoration(
                        label:
                        'Durasi',
                        hint:
                        'Contoh: 30',
                        icon: Icons
                            .schedule_outlined,
                      ),
                      validator:
                          (value) {
                        final number =
                        int.tryParse(
                          value?.trim() ??
                              '',
                        );

                        if (number ==
                            null ||
                            number < 0) {
                          return 'Durasi tidak valid';
                        }

                        return null;
                      },
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child:
                    TextFormField(
                      controller:
                      _orderController,
                      keyboardType:
                      TextInputType
                          .number,
                      decoration:
                      _inputDecoration(
                        label:
                        'Urutan',
                        hint:
                        'Contoh: 1',
                        icon: Icons
                            .format_list_numbered,
                      ),
                      validator:
                          (value) {
                        final number =
                        int.tryParse(
                          value?.trim() ??
                              '',
                        );

                        if (number ==
                            null ||
                            number < 1) {
                          return 'Urutan minimal 1';
                        }

                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 24,
              ),

              // ===================================================
              // VIDEO
              // ===================================================

              _buildVideoSection(),

              const SizedBox(
                height: 28,
              ),

              // ===================================================
              // SAVE
              // ===================================================

              SizedBox(
                height: 52,
                child:
                FilledButton.icon(
                  onPressed:
                  _loading ||
                      _uploadingVideo
                      ? null
                      : _saveLesson,
                  icon:
                  _loading ||
                      _uploadingVideo
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2,
                      color:
                      Colors.white,
                    ),
                  )
                      : Icon(
                    widget.isEdit
                        ? Icons
                        .save_outlined
                        : Icons
                        .add,
                  ),
                  label: Text(
                    _uploadingVideo
                        ? 'Mengupload Video...'
                        : _loading
                        ? 'Menyimpan...'
                        : widget.isEdit
                        ? 'Simpan Perubahan'
                        : 'Tambah Materi',
                  ),
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              // ===================================================
              // CANCEL
              // ===================================================

              SizedBox(
                height: 52,
                child:
                OutlinedButton(
                  onPressed:
                  _loading ||
                      _uploadingVideo
                      ? null
                      : () {
                    Navigator.pop(
                      context,
                    );
                  },
                  child:
                  const Text(
                    'Batal',
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}