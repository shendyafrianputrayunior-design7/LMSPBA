import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();
  final _attachmentUrlController = TextEditingController();

  String _teacherName = 'Guru';
  String? _teacherId;

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
  // VIDEO
  // ============================================================

  PlatformFile? _selectedVideo;

  String? _existingVideoUrl;
  String? _existingVideoFileName;
  int? _existingVideoSize;

  // Ukuran video baru yang dipilih.
  int? _selectedVideoSize;

  static const int _maxVideoSize = 100 * 1024 * 1024;

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

      _descriptionController.text =
          (data['description'] ?? '').toString();

      _contentController.text =
          (data['content'] ?? '').toString();

      _attachmentUrlController.text =
          (
              data['attachmentUrl'] ??
                  data['fileUrl'] ??
                  ''
          ).toString();

      final oldCourseId =
      (data['courseId'] ?? '').toString();

      final oldCourseName =
      (
          data['courseName'] ??
              data['courseTitle'] ??
              ''
      ).toString();

      final oldClassId =
      (data['classId'] ?? '').toString();

      final oldClassName =
      (data['className'] ?? '').toString();

      final oldVideoUrl =
      (data['videoUrl'] ?? '').toString();

      final oldVideoFileName =
      (data['videoFileName'] ?? '').toString();

      final oldVideoSize =
      data['videoSize'];

      if (oldCourseId.isNotEmpty) {
        _selectedCourseId = oldCourseId;
      }

      if (oldCourseName.isNotEmpty) {
        _selectedCourseName = oldCourseName;
      }

      if (oldClassId.isNotEmpty) {
        _selectedClassId = oldClassId;
      }

      if (oldClassName.isNotEmpty) {
        _selectedClassName = oldClassName;
      }

      if (oldVideoUrl.isNotEmpty) {
        _existingVideoUrl = oldVideoUrl;
      }

      if (oldVideoFileName.isNotEmpty) {
        _existingVideoFileName = oldVideoFileName;
      }

      if (oldVideoSize is int) {
        _existingVideoSize = oldVideoSize;
      } else if (oldVideoSize is num) {
        _existingVideoSize = oldVideoSize.toInt();
      }
    }

    await Future.wait([
      _loadTeacherProfile(),
      _loadCourses(),
    ]);
  }

  // ============================================================
  // GET CANONICAL TEACHER DOCUMENT ID
  // ============================================================

  Future<String?> _getTeacherDocumentId() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    // ----------------------------------------------------------
    // PRIORITAS 1:
    // users/{uid}.teacherId
    // ----------------------------------------------------------

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();

      final teacherId =
      userData?['teacherId']?.toString().trim();

      if (teacherId != null && teacherId.isNotEmpty) {
        return teacherId;
      }
    } catch (_) {
      // Lanjut ke fallback email.
    }

    // ----------------------------------------------------------
    // PRIORITAS 2:
    // teachers.email == Firebase Auth email
    // ----------------------------------------------------------

    final email = user.email?.trim();

    if (email != null && email.isNotEmpty) {
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

  // ============================================================
  // LOAD TEACHER
  // ============================================================

  Future<void> _loadTeacherProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _teacherName = 'Guru';
          _teacherId = null;
        });
      }

      return;
    }

    try {
      String teacherName = 'Guru';

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (snapshot.exists) {
        final data = snapshot.data() ?? {};

        final name = (
            data['name'] ??
                data['username'] ??
                data['displayName'] ??
                user.displayName ??
                'Guru'
        ).toString();

        if (name.trim().isNotEmpty) {
          teacherName = name.trim();
        }
      } else if (user.displayName != null &&
          user.displayName!.trim().isNotEmpty) {
        teacherName = user.displayName!.trim();
      }

      final teacherId =
      await _getTeacherDocumentId();

      if (!mounted) return;

      setState(() {
        _teacherName = teacherName;
        _teacherId = teacherId;
      });
    } catch (_) {
      final teacherId =
      await _getTeacherDocumentId();

      if (!mounted) return;

      setState(() {
        _teacherName =
        user.displayName?.trim().isNotEmpty == true
            ? user.displayName!.trim()
            : 'Guru';

        _teacherId = teacherId;
      });
    }
  }

  // ============================================================
  // LOAD COURSE
  // ============================================================

  Future<void> _loadCourses() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingData = false;
        });
      }

      return;
    }

    try {
      // PENTING:
      // Courses tetap menggunakan Firebase Auth UID
      // karena struktur Courses saat ini sudah berjalan.
      final snapshot = await _firestore
          .collection('courses')
          .where(
        'teacherId',
        isEqualTo: user.uid,
      )
          .get();

      final courses = snapshot.docs.toList();

      // ========================================================
      // SORT COURSE
      // ========================================================

      courses.sort((a, b) {
        final dataA = a.data();
        final dataB = b.data();

        final nameA = (
            dataA['title'] ??
                dataA['courseTitle'] ??
                dataA['name'] ??
                ''
        ).toString().toLowerCase();

        final nameB = (
            dataB['title'] ??
                dataB['courseTitle'] ??
                dataB['name'] ??
                ''
        ).toString().toLowerCase();

        return nameA.compareTo(nameB);
      });

      if (!mounted) return;

      setState(() {
        _courses = courses;
        _loadingData = false;
      });

      // ========================================================
      // SINKRONISASI COURSE SAAT EDIT
      // ========================================================

      if (_selectedCourseId != null) {
        QueryDocumentSnapshot<Map<String, dynamic>>?
        selectedCourse;

        for (final course in courses) {
          if (course.id == _selectedCourseId) {
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
      QueryDocumentSnapshot<Map<String, dynamic>> course,
      ) {
    final data = course.data();

    final courseName = (
        data['title'] ??
            data['courseTitle'] ??
            data['name'] ??
            ''
    ).toString();

    String? classId;
    String? className;

    // ----------------------------------------------------------
    // CLASS DARI COURSE
    // ----------------------------------------------------------

    final courseClassId =
    (data['classId'] ?? '').toString();

    final courseClassName = (
        data['className'] ??
            data['class'] ??
            ''
    ).toString();

    if (courseClassId.isNotEmpty) {
      classId = courseClassId;

      if (courseClassName.isNotEmpty) {
        className = courseClassName;
      }
    }

    // ----------------------------------------------------------
    // GUNAKAN CLASS LAMA JIKA ID SAMA
    // ----------------------------------------------------------

    if (classId != null &&
        className == null &&
        _selectedClassId == classId &&
        _selectedClassName != null &&
        _selectedClassName!.isNotEmpty) {
      className = _selectedClassName;
    }

    // ----------------------------------------------------------
    // PERTAHANKAN CLASS LAMA SAAT EDIT
    // ----------------------------------------------------------

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

      if (classId != null && classId.isNotEmpty) {
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

  void _onCourseChanged(String? courseId) {
    if (courseId == null) {
      setState(() {
        _selectedCourseId = null;
        _selectedCourseName = null;
        _selectedClassId = null;
        _selectedClassName = null;
      });

      return;
    }

    QueryDocumentSnapshot<Map<String, dynamic>>?
    selectedCourse;

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
      final file = await FilePicker.pickFile(
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

      if (path == null || path.isEmpty) {
        _showMessage(
          'File video tidak dapat diakses.',
        );

        return;
      }

      // ========================================================
      // AMBIL UKURAN DARI FILE SYSTEM
      // Tidak menggunakan PlatformFile.size
      // ========================================================

      final localFile = File(path);

      if (!await localFile.exists()) {
        _showMessage(
          'File video tidak ditemukan.',
        );

        return;
      }

      final int fileSize =
      await localFile.length();

      // ========================================================
      // VALIDASI MAKSIMAL 100 MB
      // ========================================================

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

    final path = _selectedVideo!.path;

    if (path == null || path.isEmpty) {
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

    final int fileSize =
    await file.length();

    if (fileSize > _maxVideoSize) {
      throw Exception(
        'Ukuran video maksimal 100 MB.',
      );
    }

    final videoUrl =
    await CloudinaryService.uploadLessonVideo(
      file,
    );

    if (videoUrl == null ||
        videoUrl.isEmpty) {
      throw Exception(
        'Upload video ke Cloudinary gagal.',
      );
    }

    return videoUrl;
  }

  // ============================================================
  // SAVE MATERIAL
  // ============================================================

  Future<void> _saveMaterial() async {
    if (!_formKey.currentState!.validate()) {
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

    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Anda belum login.',
      );

      return;
    }

    // ==========================================================
    // PASTIKAN TEACHER ID CANONICAL
    // ==========================================================

    String? teacherId = _teacherId;

    if (teacherId == null ||
        teacherId.isEmpty) {
      teacherId =
      await _getTeacherDocumentId();
    }

    if (teacherId == null ||
        teacherId.isEmpty) {
      _showMessage(
        'Data guru tidak ditemukan. '
            'Pastikan akun Anda sudah terhubung dengan data guru.',
      );

      return;
    }

    if (!mounted) return;

    setState(() {
      _loading = true;
      _teacherId = teacherId;
    });

    try {
      // ========================================================
      // VIDEO
      // ========================================================

      String? videoUrl =
          _existingVideoUrl;

      String? videoFileName =
          _existingVideoFileName;

      int? videoSize =
          _existingVideoSize;

      if (_selectedVideo != null) {
        _showMessage(
          'Sedang mengupload video...',
        );

        videoUrl =
        await _uploadVideo();

        videoFileName =
            _selectedVideo!.name;

        // Ambil ukuran dari state yang sudah
        // dihitung ketika memilih video.
        videoSize =
            _selectedVideoSize;

        // Fallback apabila ukuran belum tersedia.
        if (videoSize == null) {
          final path =
              _selectedVideo!.path;

          if (path != null &&
              path.isNotEmpty) {
            final file = File(path);

            if (await file.exists()) {
              videoSize =
              await file.length();
            }
          }
        }
      }

      final now =
      Timestamp.now();

      // ========================================================
      // DATA MATERIAL
      // ========================================================

      final materialData =
      <String, dynamic>{
        // ------------------------------------------------------
        // GURU
        // ------------------------------------------------------

        'teacherId': teacherId,
        'teacherName': _teacherName,

        // ------------------------------------------------------
        // MATERI
        // ------------------------------------------------------

        'title':
        _titleController.text.trim(),

        'description':
        _descriptionController.text.trim(),

        'content':
        _contentController.text.trim(),

        // ------------------------------------------------------
        // COURSE
        // ------------------------------------------------------

        'courseId':
        _selectedCourseId,

        'courseName':
        _selectedCourseName ?? '',

        // ------------------------------------------------------
        // KELAS
        // ------------------------------------------------------

        'classId':
        _selectedClassId,

        'className':
        _selectedClassName ?? '',

        // ------------------------------------------------------
        // VIDEO
        // ------------------------------------------------------

        'videoUrl':
        videoUrl ?? '',

        'videoFileName':
        videoFileName ?? '',

        'videoSize':
        videoSize ?? 0,

        // ------------------------------------------------------
        // LAMPIRAN
        // ------------------------------------------------------

        'attachmentUrl':
        _attachmentUrlController.text.trim(),

        // ------------------------------------------------------
        // UPDATED
        // ------------------------------------------------------

        'updatedAt': now,
      };

      // ========================================================
      // EDIT
      // ========================================================

      if (_isEdit) {
        await _firestore
            .collection('materials')
            .doc(widget.materialId)
            .update(materialData);
      }

      // ========================================================
      // TAMBAH
      // ========================================================

      else {
        await _firestore
            .collection('materials')
            .add({
          ...materialData,
          'createdAt': now,
        });
      }

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

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // FORMAT FILE SIZE
  // ============================================================

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) {
      return '0 B';
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
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
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
        borderSide: BorderSide(
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
        decoration: _inputDecoration(
          label: 'Course',
          icon: Icons.book_outlined,
        ),
        child: const SizedBox(
          height: 24,
          child: Align(
            alignment:
            Alignment.centerLeft,
            child: SizedBox(
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
        decoration: _inputDecoration(
          label: 'Course',
          icon: Icons.book_outlined,
        ),
        child: const Text(
          'Belum ada course yang ditugaskan kepada Anda.',
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue:
      _selectedCourseId,
      isExpanded: true,
      decoration: _inputDecoration(
        label: 'Course',
        icon: Icons.book_outlined,
      ),
      items: _courses.map((course) {
        final data = course.data();

        final name = (
            data['title'] ??
                data['courseTitle'] ??
                data['name'] ??
                'Tanpa Nama Course'
        ).toString();

        return DropdownMenuItem<String>(
          value: course.id,
          child: Text(
            name,
            overflow:
            TextOverflow.ellipsis,
          ),
        );
      }).toList(),
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
  // AUTO CLASS INFO
  // ============================================================

  Widget _buildClassInfo() {
    final theme =
    Theme.of(context);

    if (_selectedCourseId == null) {
      return Container(
        padding:
        const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius:
          BorderRadius.circular(12),
          border: Border.all(
            color:
            theme.colorScheme.outline,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.groups_outlined,
              color:
              theme.colorScheme.outline,
            ),
            const SizedBox(width: 12),
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

    if (_selectedClassId == null ||
        _selectedClassId!.isEmpty) {
      return Container(
        padding:
        const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme
              .colorScheme
              .errorContainer,
          borderRadius:
          BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color:
              theme.colorScheme.error,
            ),
            const SizedBox(width: 12),
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
      const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest,
        borderRadius:
        BorderRadius.circular(12),
        border: Border.all(
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
            decoration: BoxDecoration(
              color: theme
                  .colorScheme
                  .primaryContainer,
              borderRadius:
              BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.groups_outlined,
              color:
              theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
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
                const SizedBox(height: 3),
                Text(
                  _selectedClassName ??
                      _selectedClassId!,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
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
            color:
            theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VIDEO PICKER UI
  // ============================================================

  Widget _buildVideoSection() {
    final theme =
    Theme.of(context);

    final hasNewVideo =
        _selectedVideo != null;

    final hasExistingVideo =
        _existingVideoUrl != null &&
            _existingVideoUrl!.isNotEmpty;

    return Container(
      padding:
      const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color: theme
              .colorScheme
              .outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          // ======================================================
          // HEADER
          // ======================================================

          Row(
            children: [
              Icon(
                Icons.video_library_outlined,
                color:
                theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
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

          const SizedBox(height: 8),

          Text(
            'Tambahkan video pembelajaran untuk ditampilkan pada Lesson.',
            style: TextStyle(
              fontSize: 13,
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 14),

          // ======================================================
          // VIDEO BARU
          // ======================================================

          if (hasNewVideo)
            Container(
              padding:
              const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme
                    .colorScheme
                    .primaryContainer,
                borderRadius:
                BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.video_file_outlined,
                    color: theme
                        .colorScheme
                        .primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedVideo!.name,
                          maxLines: 2,
                          overflow:
                          TextOverflow.ellipsis,
                          style:
                          const TextStyle(
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                    const Icon(Icons.close),
                    tooltip:
                    'Hapus pilihan',
                  ),
                ],
              ),
            )

          // ======================================================
          // VIDEO LAMA
          // ======================================================

          else if (hasExistingVideo)
            Container(
              padding:
              const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius:
                BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.video_file_outlined,
                    color: theme
                        .colorScheme
                        .primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          _existingVideoFileName
                              ?.isNotEmpty ==
                              true
                              ? _existingVideoFileName!
                              : 'Video materi tersedia',
                          maxLines: 2,
                          overflow:
                          TextOverflow.ellipsis,
                          style:
                          const TextStyle(
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                ],
              ),
            )

          // ======================================================
          // BELUM ADA VIDEO
          // ======================================================

          else
            Container(
              padding:
              const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius:
                BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    color: theme
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
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

          const SizedBox(height: 14),

          // ======================================================
          // BUTTON VIDEO
          // ======================================================

          SizedBox(
            width: double.infinity,
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

          const SizedBox(height: 8),

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
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit
              ? 'Edit Materi'
              : 'Tambah Materi',
          style: const TextStyle(
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
          const EdgeInsets.all(16),
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Container(
              padding:
              const EdgeInsets.all(16),
              decoration:
              BoxDecoration(
                color: theme
                    .colorScheme
                    .primaryContainer,
                borderRadius:
                BorderRadius.circular(16),
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
                    width: 12,
                  ),
                  Expanded(
                    child: Text(
                      _isEdit
                          ? 'Perbarui materi pembelajaran'
                          : 'Buat materi pembelajaran baru',
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

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
              validator: (value) {
                if (value == null ||
                    value
                        .trim()
                        .isEmpty) {
                  return 'Judul materi wajib diisi';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

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

            const SizedBox(height: 16),

            // ==================================================
            // ISI MATERI
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
              validator: (value) {
                if (value == null ||
                    value
                        .trim()
                        .isEmpty) {
                  return 'Isi materi wajib diisi';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            // ==================================================
            // COURSE
            // ==================================================

            _buildCourseDropdown(),

            const SizedBox(height: 16),

            // ==================================================
            // KELAS
            // ==================================================

            _buildClassInfo(),

            const SizedBox(height: 16),

            // ==================================================
            // VIDEO
            // ==================================================

            _buildVideoSection(),

            const SizedBox(height: 16),

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
                icon:
                Icons.attach_file,
                hint:
                'https://...',
              ),
            ),

            const SizedBox(height: 28),

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
                    strokeWidth: 2,
                  ),
                )
                    : Icon(
                  _isEdit
                      ? Icons.save
                      : Icons.add,
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

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}