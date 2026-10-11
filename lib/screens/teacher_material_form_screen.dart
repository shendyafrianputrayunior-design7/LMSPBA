import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/cloudinary_service.dart';

class TeacherMaterialFormScreen extends StatefulWidget {
  final String? materialId;
  final Map<String, dynamic>? materialData;

  const TeacherMaterialFormScreen({
    super.key,
    this.materialId,
    this.materialData,
  });

  @override
  State<TeacherMaterialFormScreen> createState() =>
      _TeacherMaterialFormScreenState();
}

class _TeacherMaterialFormScreenState
    extends State<TeacherMaterialFormScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  static const String _fixedTeacherId = 'teacher_001';

  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();
  final _attachmentUrlController = TextEditingController();

  String _teacherName = 'Guru';
  String _teacherId = _fixedTeacherId;

  bool _loading = false;
  bool _loadingData = true;

  bool get _isEdit => widget.materialId != null;

  // ============================================================
  // COURSE
  // ============================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _courses = [];

  String? _selectedCourseId;
  String? _selectedCourseName;

  // ============================================================
  // CLASS
  // ============================================================

  String? _selectedClassId;
  String? _selectedClassName;

  // ============================================================
  // ORIGINAL DATA
  // ============================================================

  String? _originalCourseId;
  String? _originalCourseLessonId;
  String? _originalTitle;

  // ============================================================
  // VIDEO
  // ============================================================

  PlatformFile? _selectedVideo;

  String? _existingVideoUrl;
  String? _existingVideoFileName;
  int? _existingVideoSize;

  int? _selectedVideoSize;

  static const int _maxVideoSize =
      100 * 1024 * 1024;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _attachmentUrlController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD INITIAL DATA
  // ============================================================

  Future<void> _loadInitialData() async {
    final data = widget.materialData;

    if (data != null) {
      _titleController.text =
          (data['title'] ?? '').toString();

      _subjectController.text =
          (data['subject'] ?? '').toString();

      _descriptionController.text =
          (data['description'] ?? '').toString();

      _contentController.text =
          (data['content'] ?? '').toString();

      _attachmentUrlController.text =
          (data['attachmentUrl'] ??
              data['fileUrl'] ??
              '')
              .toString();

      // ----------------------------------------------------------
      // ORIGINAL TITLE
      // ----------------------------------------------------------

      final oldTitle =
      (data['title'] ?? '')
          .toString()
          .trim();

      _originalTitle =
      oldTitle.isEmpty ? null : oldTitle;

      // ----------------------------------------------------------
      // COURSE
      // ----------------------------------------------------------

      final oldCourseId =
      (data['courseId'] ?? '')
          .toString()
          .trim();

      final oldCourseName =
      (data['courseName'] ??
          data['courseTitle'] ??
          '')
          .toString();

      _originalCourseId =
      oldCourseId.isEmpty
          ? null
          : oldCourseId;

      if (oldCourseId.isNotEmpty) {
        _selectedCourseId = oldCourseId;
      }

      if (oldCourseName.isNotEmpty) {
        _selectedCourseName = oldCourseName;
      }

      // ----------------------------------------------------------
      // CLASS
      // ----------------------------------------------------------

      final oldClassId =
      (data['classId'] ?? '')
          .toString()
          .trim();

      final oldClassName =
      (data['className'] ?? '')
          .toString();

      if (oldClassId.isNotEmpty) {
        _selectedClassId = oldClassId;
      }

      if (oldClassName.isNotEmpty) {
        _selectedClassName = oldClassName;
      }

      // ----------------------------------------------------------
      // COURSE LESSON ID
      // ----------------------------------------------------------

      final oldCourseLessonId =
      (data['courseLessonId'] ?? '')
          .toString()
          .trim();

      _originalCourseLessonId =
      oldCourseLessonId.isEmpty
          ? null
          : oldCourseLessonId;

      // ----------------------------------------------------------
      // VIDEO DARI MATERIAL
      // ----------------------------------------------------------

      final oldVideoUrl =
      (data['videoUrl'] ?? '')
          .toString()
          .trim();

      final oldVideoFileName =
      (data['videoFileName'] ?? '')
          .toString();

      final oldVideoSize =
      data['videoSize'];

      if (oldVideoUrl.isNotEmpty) {
        _existingVideoUrl = oldVideoUrl;
      }

      if (oldVideoFileName.isNotEmpty) {
        _existingVideoFileName =
            oldVideoFileName;
      }

      if (oldVideoSize is int) {
        _existingVideoSize = oldVideoSize;
      } else if (oldVideoSize is num) {
        _existingVideoSize =
            oldVideoSize.toInt();
      }
    }

    await Future.wait([
      _loadTeacherProfile(),
      _loadCourses(),
    ]);

    // ============================================================
    // PENTING:
    //
    // Kalau material tidak punya video tetapi sebenarnya video
    // masih berada di course_lessons, cari dan hubungkan otomatis.
    // ============================================================

    if (_isEdit &&
        _existingVideoUrl == null &&
        _selectedCourseId != null &&
        _selectedCourseId!.isNotEmpty) {
      await _loadLegacyVideo();
    }
  }

  // ============================================================
  // LOAD LEGACY VIDEO
  //
  // Mencari video yang sebenarnya sudah ada di course_lessons.
  // Ini yang memperbaiki kasus:
  //
  // materials:
  //   URL ada
  //   videoUrl kosong
  //
  // course_lessons:
  //   videoUrl ada
  //
  // Keduanya akan dianggap satu materi.
  // ============================================================

  Future<void> _loadLegacyVideo() async {
    try {
      final courseId =
      (_selectedCourseId ?? '').trim();

      if (courseId.isEmpty) {
        return;
      }

      final snapshot = await _firestore
          .collection('course_lessons')
          .where(
        'courseId',
        isEqualTo: courseId,
      )
          .get();

      QueryDocumentSnapshot<
          Map<String, dynamic>>? matchedLesson;

      // ==========================================================
      // 1. CARI BERDASARKAN courseLessonId
      // ==========================================================

      final linkedId =
      (_originalCourseLessonId ?? '')
          .trim();

      if (linkedId.isNotEmpty) {
        for (final doc in snapshot.docs) {
          if (doc.id == linkedId) {
            final data = doc.data();

            final videoUrl =
            (data['videoUrl'] ?? '')
                .toString()
                .trim();

            if (videoUrl.isNotEmpty) {
              matchedLesson = doc;
              break;
            }
          }
        }
      }

      // ==========================================================
      // 2. CARI BERDASARKAN JUDUL
      // ==========================================================

      if (matchedLesson == null) {
        final oldTitle =
        (_originalTitle ?? '')
            .trim()
            .toLowerCase();

        if (oldTitle.isNotEmpty) {
          for (final doc in snapshot.docs) {
            final data = doc.data();

            final lessonTitle =
            (data['title'] ?? '')
                .toString()
                .trim()
                .toLowerCase();

            final videoUrl =
            (data['videoUrl'] ?? '')
                .toString()
                .trim();

            if (lessonTitle == oldTitle &&
                videoUrl.isNotEmpty) {
              matchedLesson = doc;
              break;
            }
          }
        }
      }

      // ==========================================================
      // 3. FALLBACK:
      // CARI VIDEO TERKAIT COURSE
      //
      // Digunakan untuk data lama yang judulnya sudah berubah.
      // ==========================================================

      if (matchedLesson == null) {
        for (final doc in snapshot.docs) {
          final data = doc.data();

          final videoUrl =
          (data['videoUrl'] ?? '')
              .toString()
              .trim();

          if (videoUrl.isNotEmpty) {
            matchedLesson = doc;
            break;
          }
        }
      }

      if (matchedLesson == null) {
        return;
      }

      final lessonData =
      matchedLesson.data();

      final videoUrl =
      (lessonData['videoUrl'] ?? '')
          .toString()
          .trim();

      if (videoUrl.isEmpty) {
        return;
      }

      final fileName =
      (lessonData['videoFileName'] ?? '')
          .toString();

      final rawSize =
      lessonData['videoSize'];

      int videoSize = 0;

      if (rawSize is int) {
        videoSize = rawSize;
      } else if (rawSize is num) {
        videoSize = rawSize.toInt();
      }

      if (!mounted) return;

      setState(() {
        _existingVideoUrl = videoUrl;

        _existingVideoFileName =
        fileName.isEmpty
            ? null
            : fileName;

        _existingVideoSize =
        videoSize > 0
            ? videoSize
            : null;

        _originalCourseLessonId =
            matchedLesson!.id;
      });

      debugPrint(
        'Legacy video ditemukan: ${matchedLesson.id}',
      );
    } catch (e) {
      debugPrint(
        'Gagal mencari legacy video: $e',
      );
    }
  }

  // ============================================================
  // LOAD TEACHER PROFILE
  // ============================================================

  Future<void> _loadTeacherProfile() async {
    try {
      String teacherName = 'Guru';

      try {
        final teacherQuery = await _firestore
            .collection('users')
            .where(
          'teacherId',
          isEqualTo: _fixedTeacherId,
        )
            .limit(1)
            .get();

        if (teacherQuery.docs.isNotEmpty) {
          final data =
          teacherQuery.docs.first.data();

          final name =
          (data['name'] ??
              data['username'] ??
              data['displayName'] ??
              'Guru')
              .toString();

          if (name.trim().isNotEmpty) {
            teacherName = name.trim();
          }
        }
      } catch (_) {
        teacherName = 'Guru';
      }

      if (!mounted) return;

      setState(() {
        _teacherName = teacherName;
        _teacherId = _fixedTeacherId;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _teacherName = 'Guru';
        _teacherId = _fixedTeacherId;
      });
    }
  }

  // ============================================================
  // LOAD COURSES
  // ============================================================

  Future<void> _loadCourses() async {
    try {
      final snapshot = await _firestore
          .collection('courses')
          .where(
        'teacherId',
        isEqualTo: _fixedTeacherId,
      )
          .get();

      final courses =
      snapshot.docs.toList();

      courses.sort((a, b) {
        final dataA = a.data();
        final dataB = b.data();

        final nameA =
        (dataA['title'] ??
            dataA['courseTitle'] ??
            dataA['name'] ??
            '')
            .toString()
            .toLowerCase();

        final nameB =
        (dataB['title'] ??
            dataB['courseTitle'] ??
            dataB['name'] ??
            '')
            .toString()
            .toLowerCase();

        return nameA.compareTo(nameB);
      });

      if (!mounted) return;

      setState(() {
        _courses = courses;
        _loadingData = false;
      });

      if (_selectedCourseId != null) {
        QueryDocumentSnapshot<
            Map<String, dynamic>>? selectedCourse;

        for (final course in courses) {
          if (course.id ==
              _selectedCourseId) {
            selectedCourse = course;
            break;
          }
        }

        if (selectedCourse != null) {
          _applyCourseData(selectedCourse);
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingData = false;
      });

      _showMessage(
        'Gagal mengambil data course:\n$e',
      );
    }
  }

  // ============================================================
  // APPLY COURSE DATA
  // ============================================================

  void _applyCourseData(
      QueryDocumentSnapshot<
          Map<String, dynamic>>
      course,
      ) {
    final data = course.data();

    final courseName =
    (data['title'] ??
        data['courseTitle'] ??
        data['name'] ??
        '')
        .toString();

    String? classId;
    String? className;

    final courseClassId =
    (data['classId'] ?? '')
        .toString()
        .trim();

    final courseClassName =
    (data['className'] ??
        data['class'] ??
        '')
        .toString();

    if (courseClassId.isNotEmpty) {
      classId = courseClassId;

      if (courseClassName.isNotEmpty) {
        className = courseClassName;
      }
    }

    if (classId != null &&
        className == null &&
        _selectedClassId == classId &&
        _selectedClassName != null &&
        _selectedClassName!.isNotEmpty) {
      className = _selectedClassName;
    }

    if (classId == null) {
      if (_isEdit &&
          _selectedCourseId == course.id &&
          _selectedClassId != null &&
          _selectedClassId!.isNotEmpty) {
        classId = _selectedClassId;
        className = _selectedClassName;
      }
    }

    if (!mounted) return;

    setState(() {
      _selectedCourseId = course.id;
      _selectedCourseName = courseName;

      if (classId != null &&
          classId.isNotEmpty) {
        _selectedClassId = classId;
        _selectedClassName =
            className ?? classId;
      } else {
        _selectedClassId = null;
        _selectedClassName = null;
      }
    });
  }

  // ============================================================
  // COURSE CHANGED
  // ============================================================

  void _onCourseChanged(
      String? courseId,
      ) {
    if (courseId == null) {
      setState(() {
        _selectedCourseId = null;
        _selectedCourseName = null;
        _selectedClassId = null;
        _selectedClassName = null;
      });

      return;
    }

    QueryDocumentSnapshot<
        Map<String, dynamic>>? selectedCourse;

    for (final course in _courses) {
      if (course.id == courseId) {
        selectedCourse = course;
        break;
      }
    }

    if (selectedCourse == null) {
      return;
    }

    _applyCourseData(selectedCourse);
  }

  // ============================================================
  // PICK VIDEO
  // ============================================================

  Future<void> _pickVideo() async {
    if (_loading) return;

    try {
      final file =
      await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: [
          'mp4',
          'mov',
          'm4v',
          'webm',
        ],
      );

      if (file == null) {
        return;
      }

      final path = file.path;

      if (path == null ||
          path.isEmpty) {
        _showMessage(
          'File video tidak dapat diakses.',
        );
        return;
      }

      final localFile = File(path);

      if (!await localFile.exists()) {
        _showMessage(
          'File video tidak ditemukan.',
        );
        return;
      }

      final fileSize =
      await localFile.length();

      if (fileSize > _maxVideoSize) {
        _showMessage(
          'Ukuran video maksimal 100 MB.',
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _selectedVideo = file;
        _selectedVideoSize = fileSize;
      });
    } catch (e) {
      _showMessage(
        'Gagal memilih video:\n$e',
      );
    }
  }

  // ============================================================
  // REMOVE SELECTED VIDEO
  // ============================================================

  void _removeSelectedVideo() {
    if (_loading) return;

    setState(() {
      _selectedVideo = null;
      _selectedVideoSize = null;
    });
  }

  // ============================================================
  // UPLOAD VIDEO
  // ============================================================

  Future<String?> _uploadVideo() async {
    if (_selectedVideo == null) {
      return _existingVideoUrl;
    }

    final path =
        _selectedVideo!.path;

    if (path == null ||
        path.isEmpty) {
      throw Exception(
        'Path video tidak ditemukan.',
      );
    }

    final file = File(path);

    if (!await file.exists()) {
      throw Exception(
        'File video tidak ditemukan.',
      );
    }

    final fileSize =
    await file.length();

    if (fileSize > _maxVideoSize) {
      throw Exception(
        'Ukuran video maksimal 100 MB.',
      );
    }

    final videoUrl =
    await CloudinaryService
        .uploadLessonVideo(file);

    if (videoUrl == null ||
        videoUrl.isEmpty) {
      throw Exception(
        'Upload video ke Cloudinary gagal.',
      );
    }

    return videoUrl;
  }

  // ============================================================
  // GET NEXT LESSON ORDER
  // ============================================================

  Future<int> _getNextLessonOrder() async {
    if (_selectedCourseId == null ||
        _selectedCourseId!.isEmpty) {
      return 1;
    }

    final snapshot = await _firestore
        .collection('course_lessons')
        .where(
      'courseId',
      isEqualTo: _selectedCourseId,
    )
        .get();

    int maxOrder = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final value = data['order'];

      if (value is int &&
          value > maxOrder) {
        maxOrder = value;
      } else if (value is num) {
        final order = value.toInt();

        if (order > maxOrder) {
          maxOrder = order;
        }
      }
    }

    return maxOrder + 1;
  }

  // ============================================================
  // FIND EXISTING COURSE LESSON
  //
  // PENTING:
  // Tidak lagi memblokir lesson hanya karena teacherId lama.
  //
  // Course sudah diverifikasi milik teacher_001.
  // Jadi lesson di dalam course tersebut boleh dipakai sebagai
  // lesson video milik materi ini.
  // ============================================================

  Future<QueryDocumentSnapshot<
      Map<String, dynamic>>?> _findExistingCourseLesson({
    String? courseId,
    String? courseLessonId,
  }) async {
    final targetCourseId =
    (courseId ??
        _selectedCourseId ??
        '')
        .toString()
        .trim();

    if (targetCourseId.isEmpty) {
      return null;
    }

    final snapshot = await _firestore
        .collection('course_lessons')
        .where(
      'courseId',
      isEqualTo: targetCourseId,
    )
        .get();

    // ==========================================================
    // 1. PRIORITAS ID
    // ==========================================================

    final targetLessonId =
    (courseLessonId ?? '')
        .toString()
        .trim();

    if (targetLessonId.isNotEmpty) {
      for (final doc in snapshot.docs) {
        if (doc.id ==
            targetLessonId) {
          final data = doc.data();

          final videoUrl =
          (data['videoUrl'] ?? '')
              .toString()
              .trim();

          if (videoUrl.isNotEmpty) {
            return doc;
          }
        }
      }
    }

    // ==========================================================
    // 2. CARI BERDASARKAN JUDUL
    // ==========================================================

    final oldTitle =
    (_originalTitle ?? '')
        .trim()
        .toLowerCase();

    if (oldTitle.isNotEmpty) {
      for (final doc in snapshot.docs) {
        final data = doc.data();

        final lessonTitle =
        (data['title'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        final videoUrl =
        (data['videoUrl'] ?? '')
            .toString()
            .trim();

        if (lessonTitle == oldTitle &&
            videoUrl.isNotEmpty) {
          return doc;
        }
      }
    }

    return null;
  }

  // ============================================================
  // DELETE COURSE LESSON
  // ============================================================

  Future<void> _deleteCourseLesson(
      String lessonId,
      ) async {
    final cleanId =
    lessonId.trim();

    if (cleanId.isEmpty) {
      return;
    }

    await _firestore
        .collection('course_lessons')
        .doc(cleanId)
        .delete();
  }

  // ============================================================
  // SAVE / UPDATE COURSE LESSON
  // ============================================================

  Future<String> _saveCourseLesson({
    required String videoUrl,
    required String videoFileName,
    required int videoSize,
    required Timestamp now,
  }) async {
    if (_selectedCourseId == null ||
        _selectedCourseId!.isEmpty) {
      throw Exception(
        'Course belum dipilih.',
      );
    }

    if (_selectedClassId == null ||
        _selectedClassId!.isEmpty) {
      throw Exception(
        'Class belum ditentukan dari course.',
      );
    }

    final lessonData =
    <String, dynamic>{
      'teacherId':
      _fixedTeacherId,

      'teacherName':
      _teacherName,

      'courseId':
      _selectedCourseId,

      'courseName':
      _selectedCourseName ?? '',

      'classId':
      _selectedClassId,

      'className':
      _selectedClassName ?? '',

      'title':
      _titleController.text.trim(),

      'content':
      _contentController.text.trim(),

      'description':
      _descriptionController.text.trim(),

      'videoUrl':
      videoUrl,

      'videoFileName':
      videoFileName,

      'videoSize':
      videoSize,

      'duration':
      0,

      'updatedAt':
      now,
    };

    final existingLesson =
    await _findExistingCourseLesson(
      courseId:
      _selectedCourseId,
      courseLessonId:
      _originalCourseLessonId,
    );

    // ==========================================================
    // UPDATE LESSON
    // ==========================================================

    if (existingLesson != null) {
      await _firestore
          .collection('course_lessons')
          .doc(existingLesson.id)
          .update(
        lessonData,
      );

      return existingLesson.id;
    }

    // ==========================================================
    // CREATE LESSON
    // ==========================================================

    final nextOrder =
    await _getNextLessonOrder();

    final reference =
    await _firestore
        .collection(
      'course_lessons',
    )
        .add({
      ...lessonData,
      'order': nextOrder,
      'createdAt': now,
    });

    return reference.id;
  }

  // ============================================================
  // MATERIAL TYPE
  // ============================================================

  String _getMaterialType({
    required bool hasVideo,
    required String attachmentUrl,
  }) {
    if (hasVideo) {
      return 'Video';
    }

    if (attachmentUrl
        .trim()
        .isNotEmpty) {
      return 'Link';
    }

    return 'Dokumen';
  }

  // ============================================================
  // SAVE MATERIAL
  // ============================================================

  Future<void> _saveMaterial() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (_selectedCourseId == null ||
        _selectedCourseId!.isEmpty) {
      _showMessage(
        'Silakan pilih course terlebih dahulu.',
      );
      return;
    }

    if (_selectedClassId == null ||
        _selectedClassId!.isEmpty) {
      _showMessage(
        'Course yang dipilih belum memiliki Class ID.',
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _loading = true;
      _teacherId = _fixedTeacherId;
    });

    try {
      final oldCourseId =
      (_originalCourseId ?? '')
          .trim();

      final oldLessonId =
      (_originalCourseLessonId ?? '')
          .trim();

      // ========================================================
      // VIDEO AWAL
      // ========================================================

      String? videoUrl =
          _existingVideoUrl;

      String? videoFileName =
          _existingVideoFileName;

      int? videoSize =
          _existingVideoSize;

      // ========================================================
      // VIDEO BARU
      // ========================================================

      if (_selectedVideo != null) {
        _showMessage(
          'Sedang mengupload video...',
        );

        videoUrl =
        await _uploadVideo();

        videoFileName =
            _selectedVideo!.name;

        videoSize =
            _selectedVideoSize;

        if (videoSize == null) {
          final path =
              _selectedVideo!.path;

          if (path != null &&
              path.isNotEmpty) {
            final file =
            File(path);

            if (await file.exists()) {
              videoSize =
              await file.length();
            }
          }
        }
      }

      final hasVideo =
          videoUrl != null &&
              videoUrl
                  .trim()
                  .isNotEmpty;

      final attachmentUrl =
      _attachmentUrlController
          .text
          .trim();

      final materialType =
      _getMaterialType(
        hasVideo: hasVideo,
        attachmentUrl:
        attachmentUrl,
      );

      final now =
      Timestamp.now();

      // ========================================================
      // MATERIAL REFERENCE
      // ========================================================

      final materialReference =
      _isEdit
          ? _firestore
          .collection(
        'materials',
      )
          .doc(
        widget.materialId,
      )
          : _firestore
          .collection(
        'materials',
      )
          .doc();

      String courseLessonId =
          oldLessonId;

      // ========================================================
      // ADA VIDEO
      // ========================================================

      if (hasVideo) {
        _showMessage(
          'Menyimpan video ke course...',
        );

        // Jika course berubah, lesson lama dihapus.
        if (_isEdit &&
            oldLessonId
                .isNotEmpty &&
            oldCourseId
                .isNotEmpty &&
            oldCourseId !=
                _selectedCourseId) {
          await _deleteCourseLesson(
            oldLessonId,
          );

          courseLessonId = '';
        }

        courseLessonId =
        await _saveCourseLesson(
          videoUrl:
          videoUrl!,
          videoFileName:
          videoFileName ?? '',
          videoSize:
          videoSize ?? 0,
          now: now,
        );
      }

      // ========================================================
      // TIDAK ADA VIDEO
      // ========================================================

      else {
        if (_isEdit &&
            oldLessonId.isNotEmpty) {
          await _deleteCourseLesson(
            oldLessonId,
          );
        }

        courseLessonId = '';

        videoUrl = '';
        videoFileName = '';
        videoSize = 0;
      }

      // ========================================================
      // MATERIAL DATA
      // ========================================================

      final materialData =
      <String, dynamic>{
        'teacherId':
        _fixedTeacherId,

        'teacherName':
        _teacherName,

        'title':
        _titleController
            .text
            .trim(),

        'subject':
        _subjectController
            .text
            .trim(),

        'description':
        _descriptionController
            .text
            .trim(),

        'content':
        _contentController
            .text
            .trim(),

        'type':
        materialType,

        'courseId':
        _selectedCourseId,

        'courseName':
        _selectedCourseName ?? '',

        'classId':
        _selectedClassId,

        'className':
        _selectedClassName ?? '',

        // ======================================================
        // URL TETAP DISIMPAN
        // ======================================================

        'attachmentUrl':
        attachmentUrl,

        // ======================================================
        // VIDEO SEKARANG JUGA DISIMPAN DI MATERIAL
        // ======================================================

        'videoUrl':
        videoUrl ?? '',

        'videoFileName':
        videoFileName ?? '',

        'videoSize':
        videoSize ?? 0,

        // ======================================================
        // RELASI KE COURSE LESSON
        // ======================================================

        'courseLessonId':
        courseLessonId,

        'updatedAt':
        now,
      };

      // ========================================================
      // SIMPAN
      // ========================================================

      if (_isEdit) {
        await materialReference.update(
          materialData,
        );
      } else {
        await materialReference.set({
          ...materialData,
          'createdAt': now,
        });
      }

      // ========================================================
      // SELESAI
      // ========================================================

      if (!mounted) return;

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        'Gagal menyimpan materi:\n$e',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // FILE SIZE
  // ============================================================

  String _formatFileSize(
      int? bytes,
      ) {
    if (bytes == null ||
        bytes <= 0) {
      return '0 B';
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

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon:
      Icon(icon),
      border:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          12,
        ),
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          12,
        ),
      ),
      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        borderSide:
        BorderSide(
          color: Theme.of(context)
              .colorScheme
              .primary,
          width: 2,
        ),
      ),
    );
  }

  // ============================================================
  // COURSE DROPDOWN
  // ============================================================

  Widget _buildCourseDropdown() {
    if (_loadingData) {
      return InputDecorator(
        decoration:
        _inputDecoration(
          label: 'Course',
          icon:
          Icons.book_outlined,
        ),
        child:
        const SizedBox(
          height: 24,
          child: Align(
            alignment:
            Alignment.centerLeft,
            child:
            SizedBox(
              width: 20,
              height: 20,
              child:
              CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ),
        ),
      );
    }

    if (_courses.isEmpty) {
      return InputDecorator(
        decoration:
        _inputDecoration(
          label: 'Course',
          icon:
          Icons.book_outlined,
        ),
        child:
        const Text(
          'Belum ada course yang ditugaskan kepada Anda.',
        ),
      );
    }

    return DropdownButtonFormField<
        String>(
      initialValue:
      _selectedCourseId,
      isExpanded: true,
      decoration:
      _inputDecoration(
        label: 'Course',
        icon:
        Icons.book_outlined,
      ),
      items:
      _courses.map(
            (course) {
          final data =
          course.data();

          final name =
          (data['title'] ??
              data[
              'courseTitle'] ??
              data['name'] ??
              'Tanpa Nama Course')
              .toString();

          return DropdownMenuItem<
              String>(
            value: course.id,
            child: Text(
              name,
              overflow:
              TextOverflow
                  .ellipsis,
            ),
          );
        },
      ).toList(),
      onChanged:
      _loading
          ? null
          : _onCourseChanged,
      validator: (value) {
        if (value == null ||
            value.isEmpty) {
          return 'Course wajib dipilih';
        }

        return null;
      },
    );
  }

  // ============================================================
  // CLASS INFO
  // ============================================================

  Widget _buildClassInfo() {
    final theme =
    Theme.of(context);

    if (_selectedCourseId ==
        null) {
      return Container(
        padding:
        const EdgeInsets.all(
          14,
        ),
        decoration:
        BoxDecoration(
          borderRadius:
          BorderRadius.circular(
            12,
          ),
          border:
          Border.all(
            color: theme
                .colorScheme
                .outline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.groups_outlined,
              color: theme
                  .colorScheme
                  .outline,
            ),
            const SizedBox(
                width: 12),
            Expanded(
              child: Text(
                'Pilih course terlebih dahulu.',
                style: TextStyle(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_selectedClassId ==
        null ||
        _selectedClassId!
            .isEmpty) {
      return Container(
        padding:
        const EdgeInsets.all(
          14,
        ),
        decoration:
        BoxDecoration(
          color: theme
              .colorScheme
              .errorContainer,
          borderRadius:
          BorderRadius.circular(
            12,
          ),
        ),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment
              .start,
          children: [
            Icon(
              Icons
                  .warning_amber_rounded,
              color: theme
                  .colorScheme
                  .error,
            ),
            const SizedBox(
                width: 12),
            Expanded(
              child: Text(
                'Course ini belum memiliki Class ID. '
                    'Silakan periksa data course terlebih dahulu.',
                style: TextStyle(
                  color: theme
                      .colorScheme
                      .onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding:
      const EdgeInsets.all(
        14,
      ),
      decoration:
      BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest,
        borderRadius:
        BorderRadius.circular(
          12,
        ),
        border:
        Border.all(
          color: theme
              .colorScheme
              .outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration:
            BoxDecoration(
              color: theme
                  .colorScheme
                  .primaryContainer,
              borderRadius:
              BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              Icons.groups_outlined,
              color: theme
                  .colorScheme
                  .primary,
            ),
          ),
          const SizedBox(
              width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  'Kelas',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(
                    height: 3),
                Text(
                  _selectedClassName ??
                      _selectedClassId!,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
                const SizedBox(
                    height: 2),
                Text(
                  'Class ID: $_selectedClassId',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle,
            color: theme
                .colorScheme
                .primary,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VIDEO SECTION
  // ============================================================

  Widget _buildVideoSection() {
    final theme =
    Theme.of(context);

    final hasNewVideo =
        _selectedVideo != null;

    final hasExistingVideo =
        _existingVideoUrl != null &&
            _existingVideoUrl!
                .isNotEmpty;

    return Container(
      padding:
      const EdgeInsets.all(
        16,
      ),
      decoration:
      BoxDecoration(
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border:
        Border.all(
          color: theme
              .colorScheme
              .outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,
        children: [
          Row(
            children: [
              Icon(
                Icons
                    .video_library_outlined,
                color: theme
                    .colorScheme
                    .primary,
              ),
              const SizedBox(
                  width: 10),
              const Expanded(
                child: Text(
                  'Video Materi',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
              height: 8),

          Text(
            'Tambahkan video pembelajaran untuk ditampilkan pada Lesson.',
            style: TextStyle(
              fontSize: 13,
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),

          const SizedBox(
              height: 14),

          if (hasNewVideo)
            Container(
              padding:
              const EdgeInsets.all(
                12,
              ),
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
              child: Row(
                children: [
                  Icon(
                    Icons
                        .video_file_outlined,
                    color: theme
                        .colorScheme
                        .primary,
                  ),
                  const SizedBox(
                      width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          _selectedVideo!
                              .name,
                          maxLines: 2,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style:
                          const TextStyle(
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),
                        const SizedBox(
                            height: 4),
                        Text(
                          _formatFileSize(
                            _selectedVideoSize,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed:
                    _removeSelectedVideo,
                    icon:
                    const Icon(
                      Icons.close,
                    ),
                    tooltip:
                    'Hapus pilihan',
                  ),
                ],
              ),
            )
          else if (hasExistingVideo)
            Container(
              padding:
              const EdgeInsets.all(
                12,
              ),
              decoration:
              BoxDecoration(
                color: theme
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius:
                BorderRadius.circular(
                  12,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons
                        .video_file_outlined,
                    color: theme
                        .colorScheme
                        .primary,
                  ),
                  const SizedBox(
                      width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          _existingVideoFileName
                              ?.isNotEmpty ==
                              true
                              ? _existingVideoFileName!
                              : 'Video materi tersedia',
                          maxLines: 2,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style:
                          const TextStyle(
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),
                        const SizedBox(
                            height: 4),
                        Text(
                          _formatFileSize(
                            _existingVideoSize,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(
                            height: 4),
                        Text(
                          'Video sudah terhubung dengan materi ini.',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.check_circle,
                    color:
                    Colors.green,
                  ),
                ],
              ),
            )
          else
            Container(
              padding:
              const EdgeInsets.all(
                14,
              ),
              decoration:
              BoxDecoration(
                color: theme
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius:
                BorderRadius.circular(
                  12,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons
                        .video_library_outlined,
                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                  const SizedBox(
                      width: 10),
                  Expanded(
                    child: Text(
                      'Belum ada video materi.',
                      style: TextStyle(
                        color: theme
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(
              height: 14),

          SizedBox(
            width:
            double.infinity,
            child:
            OutlinedButton.icon(
              onPressed:
              _loading
                  ? null
                  : _pickVideo,
              icon: Icon(
                hasNewVideo ||
                    hasExistingVideo
                    ? Icons.swap_horiz
                    : Icons.upload_file,
              ),
              label: Text(
                hasNewVideo ||
                    hasExistingVideo
                    ? 'Ganti Video'
                    : 'Pilih Video',
              ),
            ),
          ),

          const SizedBox(
              height: 8),

          Text(
            'Format: MP4, MOV, M4V, WEBM • Maksimal 100 MB',
            style: TextStyle(
              fontSize: 11,
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ],
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
    final theme =
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit
              ? 'Edit Materi'
              : 'Tambah Materi',
          style:
          const TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ),
      body: _loadingData
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : Form(
        key: _formKey,
        child: ListView(
          padding:
          const EdgeInsets.all(
            16,
          ),
          children: [
            // ==================================================
            // HEADER
            // ==================================================

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
                  CircleAvatar(
                    backgroundColor:
                    theme
                        .colorScheme
                        .primary,
                    child: Icon(
                      Icons.menu_book,
                      color: theme
                          .colorScheme
                          .onPrimary,
                    ),
                  ),
                  const SizedBox(
                      width: 12),
                  Expanded(
                    child: Text(
                      _isEdit
                          ? 'Perbarui materi pembelajaran'
                          : 'Buat materi pembelajaran baru',
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight
                            .w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
                height: 20),

            // ==================================================
            // JUDUL
            // ==================================================

            TextFormField(
              controller:
              _titleController,
              decoration:
              _inputDecoration(
                label:
                'Judul Materi',
                icon:
                Icons.title,
                hint:
                'Contoh: Dasar Pemrograman',
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
                height: 16),

            // ==================================================
            // SUBJECT
            // ==================================================

            TextFormField(
              controller:
              _subjectController,
              decoration:
              _inputDecoration(
                label:
                'Mata Pelajaran',
                icon: Icons
                    .subject_outlined,
                hint:
                'Contoh: Pemrograman',
              ),
              validator:
                  (value) {
                if (value ==
                    null ||
                    value
                        .trim()
                        .isEmpty) {
                  return 'Mata pelajaran wajib diisi';
                }

                return null;
              },
            ),

            const SizedBox(
                height: 16),

            // ==================================================
            // DESKRIPSI
            // ==================================================

            TextFormField(
              controller:
              _descriptionController,
              maxLines: 3,
              decoration:
              _inputDecoration(
                label:
                'Deskripsi',
                icon: Icons
                    .description_outlined,
                hint:
                'Deskripsi singkat materi',
              ),
            ),

            const SizedBox(
                height: 16),

            // ==================================================
            // ISI
            // ==================================================

            TextFormField(
              controller:
              _contentController,
              minLines: 6,
              maxLines: 12,
              decoration:
              _inputDecoration(
                label:
                'Isi Materi',
                icon: Icons
                    .article_outlined,
                hint:
                'Masukkan isi materi pembelajaran',
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
                height: 16),

            // ==================================================
            // COURSE
            // ==================================================

            _buildCourseDropdown(),

            const SizedBox(
                height: 16),

            // ==================================================
            // CLASS
            // ==================================================

            _buildClassInfo(),

            const SizedBox(
                height: 16),

            // ==================================================
            // VIDEO
            // ==================================================

            _buildVideoSection(),

            const SizedBox(
                height: 16),

            // ==================================================
            // URL LAMPIRAN
            // ==================================================

            TextFormField(
              controller:
              _attachmentUrlController,
              keyboardType:
              TextInputType.url,
              decoration:
              _inputDecoration(
                label:
                'URL Lampiran',
                icon: Icons
                    .attach_file,
                hint:
                'https://...',
              ),
            ),

            const SizedBox(
                height: 28),

            // ==================================================
            // SAVE
            // ==================================================

            SizedBox(
              height: 52,
              child:
              ElevatedButton.icon(
                onPressed:
                _loading
                    ? null
                    : _saveMaterial,
                icon: _loading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2,
                  ),
                )
                    : Icon(
                  _isEdit
                      ? Icons
                      .save
                      : Icons
                      .add,
                ),
                label: Text(
                  _loading
                      ? 'Menyimpan...'
                      : _isEdit
                      ? 'Simpan Perubahan'
                      : 'Tambah Materi',
                ),
              ),
            ),

            const SizedBox(
                height: 20),
          ],
        ),
      ),
    );
  }
}