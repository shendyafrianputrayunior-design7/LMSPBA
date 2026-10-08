import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
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
  // ===============================================================
  // CANONICAL TEACHER ID
  // ===============================================================

  static const String _fixedTeacherId = 'teacher_001';

  // ===============================================================
  // FORM
  // ===============================================================

  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _materialUrlController = TextEditingController();
  final _durationController = TextEditingController();
  final _orderController = TextEditingController();

  // ===============================================================
  // FIREBASE
  // ===============================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ===============================================================
  // VIDEO
  // ===============================================================

  File? _selectedVideo;

  String? _videoUrl;
  String? _videoFileName;
  int? _videoSize;

  // ===============================================================
  // LINKED MATERIAL
  // ===============================================================

  /// ID dokumen pada collection `materials`
  String? _linkedMaterialId;

  /// URL yang berhasil ditemukan dari collection `materials`
  String _linkedMaterialUrl = '';

  // ===============================================================
  // STATE
  // ===============================================================

  String _teacherId = _fixedTeacherId;

  bool _loading = false;
  bool _uploadingVideo = false;
  bool _loadingTeacher = true;
  bool _loadingExistingData = false;

  @override
  void initState() {
    super.initState();

    _loadTeacherProfile();

    if (widget.isEdit) {
      _loadExistingLesson();
    } else {
      _durationController.text = '0';
      _loadNextOrder();
    }
  }

  // ===============================================================
  // LOAD TEACHER
  // ===============================================================

  Future<void> _loadTeacherProfile() async {
    if (!mounted) return;

    setState(() {
      _teacherId = _fixedTeacherId;
      _loadingTeacher = false;
    });
  }

  // ===============================================================
  // LOAD EXISTING LESSON
  // ===============================================================

  Future<void> _loadExistingLesson() async {
    if (!mounted) return;

    setState(() {
      _loadingExistingData = true;
    });

    try {
      Map<String, dynamic> lessonData = {};

      // -----------------------------------------------------------
      // Data dari halaman sebelumnya
      // -----------------------------------------------------------

      if (widget.lessonData != null) {
        lessonData = Map<String, dynamic>.from(
          widget.lessonData!,
        );
      }

      // -----------------------------------------------------------
      // Ambil data lesson terbaru dari Firestore
      // -----------------------------------------------------------

      if (widget.lessonId != null &&
          widget.lessonId!.trim().isNotEmpty) {
        final lessonDoc = await _firestore
            .collection('course_lessons')
            .doc(widget.lessonId)
            .get();

        if (lessonDoc.exists) {
          lessonData = {
            ...lessonData,
            ...lessonDoc.data()!,
          };
        }
      }

      // -----------------------------------------------------------
      // CARI MATERIAL TERKAIT
      // -----------------------------------------------------------

      final materialResult =
      await _findLinkedMaterial(
        lessonData,
      );

      // -----------------------------------------------------------
      // Jika material ditemukan, gabungkan datanya
      // -----------------------------------------------------------

      if (materialResult != null) {
        _linkedMaterialId =
            materialResult['docId']?.toString();

        final materialData =
        Map<String, dynamic>.from(
          materialResult['data'] as Map,
        );

        // URL material dari collection materials
        final materialUrl =
        _firstNonEmptyString([
          materialData['attachmentUrl'],
          materialData['materialUrl'],
          materialData['fileUrl'],
          materialData['url'],
        ]);

        _linkedMaterialUrl = materialUrl;

        // ---------------------------------------------------------
        // URL dari materials menjadi prioritas jika ada.
        // ---------------------------------------------------------

        if (materialUrl.isNotEmpty) {
          lessonData = {
            ...lessonData,
            'attachmentUrl': materialUrl,
            'materialUrl': materialUrl,
            'fileUrl': materialUrl,
            'url': materialUrl,
          };
        }

        // ---------------------------------------------------------
        // Jika lesson belum punya video tetapi material punya,
        // gunakan video dari material.
        // ---------------------------------------------------------

        final materialVideoUrl =
        _firstNonEmptyString([
          materialData['videoUrl'],
        ]);

        if (_firstNonEmptyString([
          lessonData['videoUrl'],
        ]).isEmpty &&
            materialVideoUrl.isNotEmpty) {
          lessonData = {
            ...lessonData,
            'videoUrl': materialVideoUrl,
            'videoFileName':
            materialData['videoFileName'] ?? '',
            'videoSize':
            materialData['videoSize'] ?? 0,
          };
        }
      }

      if (!mounted) return;

      _fillExistingData(lessonData);
    } catch (e) {
      if (!mounted) return;

      // -----------------------------------------------------------
      // Fallback jika query materials gagal
      // -----------------------------------------------------------

      if (widget.lessonData != null) {
        _fillExistingData(
          Map<String, dynamic>.from(
            widget.lessonData!,
          ),
        );
      } else {
        _showMessage(
          'Gagal memuat data materi: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingExistingData = false;
        });
      }
    }
  }

  // ===============================================================
  // FIND LINKED MATERIAL
  // ===============================================================

  Future<Map<String, dynamic>?> _findLinkedMaterial(
      Map<String, dynamic> lessonData,
      ) async {
    final lessonId =
        widget.lessonId?.trim() ?? '';

    final courseId =
    _firstNonEmptyString([
      lessonData['courseId'],
      widget.course.id,
    ]);

    final lessonTitle =
    _firstNonEmptyString([
      lessonData['title'],
    ]).toLowerCase().trim();

    // =============================================================
    // 1. CARI BERDASARKAN courseLessonId
    // =============================================================

    if (lessonId.isNotEmpty) {
      try {
        final snapshot = await _firestore
            .collection('materials')
            .where(
          'courseLessonId',
          isEqualTo: lessonId,
        )
            .limit(10)
            .get();

        final result =
        _pickMaterialWithUrl(
          snapshot.docs,
        );

        if (result != null) {
          return result;
        }

        // ---------------------------------------------------------
        // Beberapa data lama mungkin memakai lessonId
        // ---------------------------------------------------------

        final snapshotLessonId =
        await _firestore
            .collection('materials')
            .where(
          'lessonId',
          isEqualTo: lessonId,
        )
            .limit(10)
            .get();

        final resultLessonId =
        _pickMaterialWithUrl(
          snapshotLessonId.docs,
        );

        if (resultLessonId != null) {
          return resultLessonId;
        }

        // ---------------------------------------------------------
        // Beberapa data lama mungkin memakai courseLesson
        // ---------------------------------------------------------

        final snapshotCourseLesson =
        await _firestore
            .collection('materials')
            .where(
          'courseLesson',
          isEqualTo: lessonId,
        )
            .limit(10)
            .get();

        final resultCourseLesson =
        _pickMaterialWithUrl(
          snapshotCourseLesson.docs,
        );

        if (resultCourseLesson != null) {
          return resultCourseLesson;
        }
      } catch (_) {
        // Lanjut ke fallback berikutnya.
      }
    }

    // =============================================================
    // 2. CARI BERDASARKAN COURSE ID
    // =============================================================

    if (courseId.isNotEmpty) {
      try {
        final snapshot = await _firestore
            .collection('materials')
            .where(
          'courseId',
          isEqualTo: courseId,
        )
            .get();

        final docs = snapshot.docs;

        if (docs.isNotEmpty) {
          // -------------------------------------------------------
          // Prioritas: title sama
          // -------------------------------------------------------

          if (lessonTitle.isNotEmpty) {
            for (final doc in docs) {
              final data = doc.data();

              final materialTitle =
              _firstNonEmptyString([
                data['title'],
              ]).toLowerCase().trim();

              final url =
              _firstNonEmptyString([
                data['attachmentUrl'],
                data['materialUrl'],
                data['fileUrl'],
                data['url'],
              ]);

              if (materialTitle == lessonTitle &&
                  url.isNotEmpty) {
                return {
                  'docId': doc.id,
                  'data': data,
                };
              }
            }
          }

          // -------------------------------------------------------
          // Fallback:
          // jika hanya ada SATU material yang memiliki URL,
          // gunakan material tersebut.
          // -------------------------------------------------------

          final withUrl = docs.where((doc) {
            final data = doc.data();

            final url =
            _firstNonEmptyString([
              data['attachmentUrl'],
              data['materialUrl'],
              data['fileUrl'],
              data['url'],
            ]);

            return url.isNotEmpty;
          }).toList();

          if (withUrl.length == 1) {
            return {
              'docId': withUrl.first.id,
              'data': withUrl.first.data(),
            };
          }
        }
      } catch (_) {
        // Tidak menghentikan proses edit lesson.
      }
    }

    return null;
  }

  // ===============================================================
  // PICK MATERIAL WITH URL
  // ===============================================================

  Map<String, dynamic>? _pickMaterialWithUrl(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    for (final doc in docs) {
      final data = doc.data();

      final url =
      _firstNonEmptyString([
        data['attachmentUrl'],
        data['materialUrl'],
        data['fileUrl'],
        data['url'],
      ]);

      if (url.isNotEmpty) {
        return {
          'docId': doc.id,
          'data': data,
        };
      }
    }

    // Jika tidak ada URL tetapi ada material,
    // tetap ambil material pertama agar video/material
    // tetap bisa disinkronkan.
    if (docs.isNotEmpty) {
      return {
        'docId': docs.first.id,
        'data': docs.first.data(),
      };
    }

    return null;
  }

  // ===============================================================
  // FILL EXISTING DATA
  // ===============================================================

  void _fillExistingData(
      Map<String, dynamic> data,
      ) {
    // =============================================================
    // TITLE
    // =============================================================

    _titleController.text =
        (data['title'] ?? '').toString();

    // =============================================================
    // CONTENT
    // =============================================================

    _contentController.text =
        (data['content'] ?? '').toString();

    // =============================================================
    // URL MATERI
    // =============================================================

    final materialUrl =
    _firstNonEmptyString([
      // Data yang baru ditemukan dari materials
      _linkedMaterialUrl,

      // Data lesson
      data['attachmentUrl'],
      data['materialUrl'],
      data['fileUrl'],
      data['url'],
    ]);

    _materialUrlController.text =
        materialUrl;

    // =============================================================
    // DURATION
    // =============================================================

    _durationController.text =
        (data['duration'] ?? 0).toString();

    // =============================================================
    // ORDER
    // =============================================================

    _orderController.text =
        (data['order'] ?? 1).toString();

    // =============================================================
    // VIDEO URL
    // =============================================================

    final existingVideoUrl =
    (data['videoUrl'] ?? '')
        .toString()
        .trim();

    if (existingVideoUrl.isNotEmpty) {
      _videoUrl = existingVideoUrl;
    } else {
      _videoUrl = null;
    }

    // =============================================================
    // VIDEO FILE NAME
    // =============================================================

    final existingVideoFileName =
    (data['videoFileName'] ?? '')
        .toString()
        .trim();

    if (existingVideoFileName.isNotEmpty) {
      _videoFileName =
          existingVideoFileName;
    } else {
      _videoFileName = null;
    }

    // =============================================================
    // VIDEO SIZE
    // =============================================================

    final existingVideoSize =
    data['videoSize'];

    if (existingVideoSize is int) {
      _videoSize =
          existingVideoSize;
    } else if (existingVideoSize != null) {
      _videoSize = int.tryParse(
        existingVideoSize.toString(),
      );
    } else {
      _videoSize = null;
    }
  }

  // ===============================================================
  // GET FIRST NON EMPTY STRING
  // ===============================================================

  String _firstNonEmptyString(
      List<dynamic> values,
      ) {
    for (final value in values) {
      if (value == null) continue;

      final text =
      value.toString().trim();

      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
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
          .where(
        'teacherId',
        isEqualTo: _fixedTeacherId,
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
          nextOrder =
              order + 1;
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
        _uploadingVideo ||
        _loadingExistingData) {
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
        _videoFileName =
            result.name;
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
        _videoUrl =
            uploadedUrl.trim();

        _videoFileName =
            video.path
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
        _uploadingVideo ||
        _loadingExistingData) {
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
  // SYNC MATERIAL
  // ===============================================================

  Future<void> _syncLinkedMaterial({
    required String materialUrl,
    required String videoUrl,
    required String videoFileName,
    required int videoSize,
  }) async {
    final materialId =
        _linkedMaterialId;

    if (materialId == null ||
        materialId.trim().isEmpty) {
      return;
    }

    final materialRef =
    _firestore
        .collection('materials')
        .doc(materialId);

    await materialRef.update({
      // -----------------------------------------------------------
      // URL
      // -----------------------------------------------------------

      'attachmentUrl':
      materialUrl,

      'materialUrl':
      materialUrl,

      'fileUrl':
      materialUrl,

      'url':
      materialUrl,

      // -----------------------------------------------------------
      // VIDEO
      // -----------------------------------------------------------

      'videoUrl':
      videoUrl,

      'videoFileName':
      videoFileName,

      'videoSize':
      videoSize,

      // -----------------------------------------------------------
      // RELATION
      // -----------------------------------------------------------

      'courseLessonId':
      widget.lessonId ?? '',

      'courseId':
      widget.course.id,

      'courseName':
      widget.course.title,

      'teacherId':
      _fixedTeacherId,

      'updatedAt':
      FieldValue.serverTimestamp(),
    });
  }

  // ===============================================================
  // SAVE LESSON
  // ===============================================================

  Future<void> _saveLesson() async {
    if (_loading ||
        _uploadingVideo ||
        _loadingExistingData) {
      return;
    }

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _loading = true;
      _teacherId =
          _fixedTeacherId;
    });

    try {
      // -----------------------------------------------------------
      // Upload video baru
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

      // -----------------------------------------------------------
      // Duration
      // -----------------------------------------------------------

      final duration =
          int.tryParse(
            _durationController
                .text
                .trim(),
          ) ??
              0;

      // -----------------------------------------------------------
      // Order
      // -----------------------------------------------------------

      final order =
          int.tryParse(
            _orderController
                .text
                .trim(),
          ) ??
              1;

      // -----------------------------------------------------------
      // URL MATERIAL
      // -----------------------------------------------------------

      final materialUrl =
      _materialUrlController
          .text
          .trim();

      // ===========================================================
      // DATA LESSON
      // ===========================================================

      final lessonData =
      <String, dynamic>{
        // ---------------------------------------------------------
        // COURSE
        // ---------------------------------------------------------

        'courseId':
        widget.course.id,

        'courseName':
        widget.course.title,

        // ---------------------------------------------------------
        // TEACHER
        // ---------------------------------------------------------

        'teacherId':
        _fixedTeacherId,

        // ---------------------------------------------------------
        // MATERI
        // ---------------------------------------------------------

        'title':
        _titleController
            .text
            .trim(),

        'content':
        _contentController
            .text
            .trim(),

        // ---------------------------------------------------------
        // URL MATERI
        // ---------------------------------------------------------

        'attachmentUrl':
        materialUrl,

        'materialUrl':
        materialUrl,

        'fileUrl':
        materialUrl,

        'url':
        materialUrl,

        // ---------------------------------------------------------
        // VIDEO
        // ---------------------------------------------------------

        'videoUrl':
        _videoUrl ?? '',

        'videoFileName':
        _videoFileName ?? '',

        'videoSize':
        _videoSize ?? 0,

        // ---------------------------------------------------------
        // LESSON
        // ---------------------------------------------------------

        'duration':
        duration,

        'order':
        order,

        'updatedAt':
        FieldValue.serverTimestamp(),
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
        final newLessonRef =
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

        // ---------------------------------------------------------
        // Jika ada material yang sedang dihubungkan,
        // simpan courseLessonId.
        // ---------------------------------------------------------

        if (_linkedMaterialId != null &&
            _linkedMaterialId!
                .trim()
                .isNotEmpty) {
          await _firestore
              .collection(
            'materials',
          )
              .doc(
            _linkedMaterialId,
          )
              .update({
            'courseLessonId':
            newLessonRef.id,
            'updatedAt':
            FieldValue
                .serverTimestamp(),
          });
        }
      }

      // ===========================================================
      // SINKRONKAN MATERIAL
      // ===========================================================

      if (_linkedMaterialId != null &&
          _linkedMaterialId!
              .trim()
              .isNotEmpty) {
        await _syncLinkedMaterial(
          materialUrl:
          materialUrl,
          videoUrl:
          _videoUrl ?? '',
          videoFileName:
          _videoFileName ?? '',
          videoSize:
          _videoSize ?? 0,
        );
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
        CrossAxisAlignment.start,
        children: [
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
                  BorderRadius.circular(
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
                        FontWeight.bold,
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
                BorderRadius.circular(
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
              child: Column(
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
                      FontWeight.w600,
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    'Format video seperti MP4 dapat digunakan.',
                    textAlign:
                    TextAlign.center,
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
                  OutlinedButton.icon(
                    onPressed:
                    _loading ||
                        _uploadingVideo ||
                        _loadingExistingData
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
          else
            Container(
              width:
              double.infinity,
              padding:
              const EdgeInsets.all(
                14,
              ),
              decoration:
              BoxDecoration(
                color: theme
                    .colorScheme
                    .primaryContainer
                    .withOpacity(
                  0.45,
                ),
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
              ),
              child: Row(
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
                    child: Column(
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
                            FontWeight.bold,
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
                  PopupMenuButton<String>(
                    enabled:
                    !_loading &&
                        !_uploadingVideo &&
                        !_loadingExistingData,
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
                FontWeight.w600,
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
    _materialUrlController.dispose();
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
            const EdgeInsets.all(20),
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
                            widget.course.title,
                            maxLines: 2,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style: theme
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              fontWeight:
                              FontWeight.bold,
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
                enabled:
                !_loadingExistingData,
                textInputAction:
                TextInputAction.next,
                decoration:
                _inputDecoration(
                  label:
                  'Judul Materi',
                  hint:
                  'Contoh: Pengenalan Flutter',
                  icon:
                  Icons.title_outlined,
                ),
                validator:
                    (value) {
                  if (value == null ||
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
                enabled:
                !_loadingExistingData,
                maxLines: 8,
                textInputAction:
                TextInputAction.newline,
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
                  if (value == null ||
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
              // URL MATERI
              // ===================================================

              TextFormField(
                controller:
                _materialUrlController,
                enabled:
                !_loadingExistingData,
                keyboardType:
                TextInputType.url,
                textInputAction:
                TextInputAction.next,
                decoration:
                _inputDecoration(
                  label:
                  'URL Materi',
                  hint:
                  'Contoh: https://drive.google.com/...',
                  icon:
                  Icons.link_outlined,
                ),
                validator:
                    (value) {
                  final url =
                      value?.trim() ??
                          '';

                  if (url.isEmpty) {
                    return null;
                  }

                  final uri =
                  Uri.tryParse(
                    url,
                  );

                  if (uri == null ||
                      !uri.hasScheme ||
                      (uri.scheme !=
                          'http' &&
                          uri.scheme !=
                              'https')) {
                    return 'URL tidak valid';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 24,
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
                      enabled:
                      !_loadingExistingData,
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
                      enabled:
                      !_loadingExistingData,
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
                      _uploadingVideo ||
                      _loadingExistingData
                      ? null
                      : _saveLesson,
                  icon:
                  _loading ||
                      _uploadingVideo ||
                      _loadingExistingData
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
                        : Icons.add,
                  ),
                  label: Text(
                    _loadingExistingData
                        ? 'Memuat Data...'
                        : _uploadingVideo
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
                      _uploadingVideo ||
                      _loadingExistingData
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