import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/cloudinary_service.dart';

class TeacherAssignmentFormScreen extends StatefulWidget {
  final String? assignmentId;
  final Map<String, dynamic>? assignmentData;

  const TeacherAssignmentFormScreen({
    super.key,
    this.assignmentId,
    this.assignmentData,
  });

  bool get isEdit => assignmentId != null;

  @override
  State<TeacherAssignmentFormScreen> createState() =>
      _TeacherAssignmentFormScreenState();
}

class _TeacherAssignmentFormScreenState
    extends State<TeacherAssignmentFormScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _instructionsController;
  late final TextEditingController _pointsController;

  DateTime? _dueDate;

  bool _saving = false;
  bool _loadingCourses = true;
  bool _loadingClasses = true;
  bool _uploadingFile = false;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _courses = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _classes = [];

  String? _selectedCourseId;
  String? _selectedCourseTitle;

  String? _selectedClassId;
  String? _selectedClassName;

  // ============================================================
  // FILE TUGAS
  // ============================================================

  File? _selectedFile;

  String _selectedFileName = '';
  int _selectedFileSize = 0;
  String _selectedFileType = '';

  // File lama ketika edit
  String _existingFileUrl = '';
  String _existingFileName = '';
  int _existingFileSize = 0;
  String _existingFileType = '';

  @override
  void initState() {
    super.initState();

    final data = widget.assignmentData;

    _titleController = TextEditingController(
      text: (data?['title'] ?? '').toString(),
    );

    _descriptionController = TextEditingController(
      text: (data?['description'] ?? '').toString(),
    );

    _instructionsController = TextEditingController(
      text: (data?['instructions'] ?? '').toString(),
    );

    _pointsController = TextEditingController(
      text: (data?['points'] ?? data?['maxScore'] ?? '100').toString(),
    );

    final existingDueDate = data?['dueDate'];

    if (existingDueDate is Timestamp) {
      _dueDate = existingDueDate.toDate();
    } else if (existingDueDate is DateTime) {
      _dueDate = existingDueDate;
    }

    final existingCourseId =
    (data?['courseId'] ?? '').toString().trim();

    if (existingCourseId.isNotEmpty) {
      _selectedCourseId = existingCourseId;
    }

    final existingCourseTitle =
    (data?['courseTitle'] ?? data?['courseName'] ?? '')
        .toString()
        .trim();

    if (existingCourseTitle.isNotEmpty) {
      _selectedCourseTitle = existingCourseTitle;
    }

    final existingClassId =
    (data?['classId'] ?? '').toString().trim();

    if (existingClassId.isNotEmpty) {
      _selectedClassId = existingClassId;
    }

    final existingClassName =
    (data?['className'] ?? '').toString().trim();

    if (existingClassName.isNotEmpty) {
      _selectedClassName = existingClassName;
    }

    // ==========================================================
    // FILE LAMA
    // ==========================================================

    _existingFileUrl =
        (data?['attachmentUrl'] ?? data?['fileUrl'] ?? '')
            .toString()
            .trim();

    _existingFileName =
        (data?['fileName'] ?? data?['attachmentName'] ?? '')
            .toString()
            .trim();

    _existingFileSize =
        int.tryParse(
          (data?['fileSize'] ?? 0).toString(),
        ) ??
            0;

    _existingFileType =
        (data?['fileType'] ?? '').toString().trim();

    _loadCourses();
    _loadClasses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _pointsController.dispose();

    super.dispose();
  }

  // ============================================================
  // GET TEACHER DOCUMENT ID
  // ============================================================

  Future<String?> _getTeacherDocumentId() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();

      final teacherIdFromUser =
      userData?['teacherId']?.toString().trim();

      if (teacherIdFromUser != null &&
          teacherIdFromUser.isNotEmpty) {
        final teacherDoc = await _firestore
            .collection('teachers')
            .doc(teacherIdFromUser)
            .get();

        if (teacherDoc.exists) {
          return teacherIdFromUser;
        }
      }

      final email = user.email?.trim();

      if (email != null && email.isNotEmpty) {
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
      }
    } catch (e) {
      debugPrint(
        'Gagal mencari teacher document ID: $e',
      );
    }

    return null;
  }

  // ============================================================
  // LOAD COURSES
  // ============================================================

  Future<void> _loadCourses() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingCourses = false;
        });
      }

      return;
    }

    try {
      final teacherDocumentId =
      await _getTeacherDocumentId();

      QuerySnapshot<Map<String, dynamic>> snapshot;

      if (teacherDocumentId != null &&
          teacherDocumentId.isNotEmpty) {
        snapshot = await _firestore
            .collection('courses')
            .where(
          'teacherId',
          isEqualTo: teacherDocumentId,
        )
            .get();
      } else {
        snapshot = await _firestore
            .collection('courses')
            .where(
          'teacherId',
          isEqualTo: user.uid,
        )
            .get();
      }

      if (!mounted) {
        return;
      }

      final Map<
          String,
          QueryDocumentSnapshot<Map<String, dynamic>>> uniqueCourses = {};

      for (final course in snapshot.docs) {
        uniqueCourses[course.id] = course;
      }

      final courses = uniqueCourses.values.toList();

      courses.sort((a, b) {
        final titleA =
        (a.data()['title'] ?? '').toString().toLowerCase();

        final titleB =
        (b.data()['title'] ?? '').toString().toLowerCase();

        return titleA.compareTo(titleB);
      });

      String? validSelectedCourseId = _selectedCourseId;
      String? validSelectedCourseTitle = _selectedCourseTitle;

      if (validSelectedCourseId != null) {
        QueryDocumentSnapshot<
            Map<String, dynamic>>? selectedCourse;

        for (final course in courses) {
          if (course.id == validSelectedCourseId) {
            selectedCourse = course;
            break;
          }
        }

        if (selectedCourse != null) {
          final courseData = selectedCourse.data();

          validSelectedCourseId = selectedCourse.id;

          validSelectedCourseTitle =
              (courseData['title'] ?? 'Course tanpa nama')
                  .toString()
                  .trim();

          if (validSelectedCourseTitle!.isEmpty) {
            validSelectedCourseTitle = 'Course tanpa nama';
          }
        } else {
          validSelectedCourseId = null;
          validSelectedCourseTitle = null;
        }
      }

      setState(() {
        _courses = courses;
        _selectedCourseId = validSelectedCourseId;
        _selectedCourseTitle = validSelectedCourseTitle;
        _loadingCourses = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingCourses = false;
        _courses = [];
        _selectedCourseId = null;
        _selectedCourseTitle = null;
      });

      _showMessage(
        'Gagal mengambil daftar course:\n$e',
      );
    }
  }

  // ============================================================
  // LOAD CLASSES
  // ============================================================

  Future<void> _loadClasses() async {
    try {
      final snapshot = await _firestore
          .collection('classes')
          .get();

      if (!mounted) {
        return;
      }

      final Map<
          String,
          QueryDocumentSnapshot<Map<String, dynamic>>> uniqueClasses = {};

      for (final classDoc in snapshot.docs) {
        uniqueClasses[classDoc.id] = classDoc;
      }

      final classes = uniqueClasses.values.toList();

      classes.sort((a, b) {
        final nameA = _getClassName(a).toLowerCase();
        final nameB = _getClassName(b).toLowerCase();

        return nameA.compareTo(nameB);
      });

      String? validSelectedClassId = _selectedClassId;
      String? validSelectedClassName = _selectedClassName;

      if (validSelectedClassId != null) {
        QueryDocumentSnapshot<
            Map<String, dynamic>>? selectedClass;

        for (final classDoc in classes) {
          if (classDoc.id == validSelectedClassId) {
            selectedClass = classDoc;
            break;
          }
        }

        if (selectedClass != null) {
          validSelectedClassId = selectedClass.id;
          validSelectedClassName = _getClassName(selectedClass);
        } else {
          validSelectedClassId = null;
          validSelectedClassName = null;
        }
      }

      setState(() {
        _classes = classes;
        _selectedClassId = validSelectedClassId;
        _selectedClassName = validSelectedClassName;
        _loadingClasses = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingClasses = false;
        _classes = [];
        _selectedClassId = null;
        _selectedClassName = null;
      });

      _showMessage(
        'Gagal mengambil daftar kelas:\n$e',
      );
    }
  }

  // ============================================================
  // GET CLASS NAME
  // ============================================================

  String _getClassName(
      QueryDocumentSnapshot<Map<String, dynamic>> classDoc,
      ) {
    final data = classDoc.data();

    final name = (data['name'] ?? '').toString().trim();

    if (name.isNotEmpty) {
      return name;
    }

    final className =
    (data['className'] ?? '').toString().trim();

    if (className.isNotEmpty) {
      return className;
    }

    return classDoc.id;
  }

  // ============================================================
  // SELECT COURSE
  // ============================================================

  void _setSelectedCourse(
      QueryDocumentSnapshot<Map<String, dynamic>> course,
      ) {
    final data = course.data();

    final title = (data['title'] ?? '').toString().trim();

    setState(() {
      _selectedCourseId = course.id;
      _selectedCourseTitle =
      title.isNotEmpty ? title : 'Course tanpa nama';
    });
  }

  // ============================================================
  // SELECT CLASS
  // ============================================================

  void _setSelectedClass(
      QueryDocumentSnapshot<Map<String, dynamic>> classDoc,
      ) {
    setState(() {
      _selectedClassId = classDoc.id;
      _selectedClassName = _getClassName(classDoc);
    });
  }

  // ============================================================
  // PICK ASSIGNMENT FILE
  // ============================================================

  Future<void> _pickAssignmentFile() async {
    if (_saving || _uploadingFile) {
      return;
    }

    try {
      // ========================================================
      // SESUAI DENGAN VERSI FILE_PICKER YANG KAMU PAKAI
      //
      // Tidak menggunakan:
      // - FilePicker.platform
      // - FilePickerResult
      // - withData
      // - result.files.single
      //
      // pickFiles() mengembalikan List<PlatformFile>
      // ========================================================

      final List<PlatformFile> result =
          await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: [
              'pdf',
              'doc',
              'docx',
              'ppt',
              'pptx',
              'xls',
              'xlsx',
              'zip',
              'rar',
              'jpg',
              'jpeg',
              'png',
            ],
          ) ??
              <PlatformFile>[];

      if (result.isEmpty) {
        return;
      }

      final PlatformFile picked = result.first;

      final String? pickedPath = picked.path;

      if (pickedPath == null || pickedPath.trim().isEmpty) {
        _showMessage(
          'File tidak dapat dibaca dari perangkat.',
        );
        return;
      }

      final File file = File(pickedPath);

      if (!await file.exists()) {
        _showMessage(
          'File tidak ditemukan.',
        );
        return;
      }

      final String fileName = picked.name.trim();

      final String extension = fileName.contains('.')
          ? fileName.split('.').last.toUpperCase()
          : '';

      final int fileSize = await file.length();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedFile = file;
        _selectedFileName = fileName;
        _selectedFileSize = fileSize;
        _selectedFileType = extension;
      });
    } catch (e) {
      _showMessage(
        'Gagal memilih file:\n$e',
      );
    }
  }

  // ============================================================
  // REMOVE SELECTED FILE
  // ============================================================

  void _removeSelectedFile() {
    if (_saving || _uploadingFile) {
      return;
    }

    setState(() {
      _selectedFile = null;
      _selectedFileName = '';
      _selectedFileSize = 0;
      _selectedFileType = '';
    });
  }

  // ============================================================
  // REMOVE EXISTING FILE
  // ============================================================

  void _removeExistingFile() {
    if (_saving || _uploadingFile) {
      return;
    }

    setState(() {
      _existingFileUrl = '';
      _existingFileName = '';
      _existingFileSize = 0;
      _existingFileType = '';
    });
  }

  // ============================================================
  // FORMAT FILE SIZE
  // ============================================================

  String _formatFileSize(int bytes) {
    if (bytes <= 0) {
      return '-';
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
  // UPLOAD FILE
  // ============================================================

  Future<String?> _uploadAssignmentFile() async {
    if (_selectedFile == null) {
      return null;
    }

    if (mounted) {
      setState(() {
        _uploadingFile = true;
      });
    }

    try {
      final url =
      await CloudinaryService.uploadAssignmentFile(
        _selectedFile!,
      );

      if (url == null || url.trim().isEmpty) {
        throw Exception(
          'Cloudinary tidak mengembalikan URL file.',
        );
      }

      return url;
    } catch (e) {
      _showMessage(
        'Gagal mengunggah dokumen:\n$e',
      );

      return null;
    } finally {
      if (mounted) {
        setState(() {
          _uploadingFile = false;
        });
      }
    }
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // ============================================================
  // SAVE ASSIGNMENT
  // ============================================================

  Future<void> _saveAssignment() async {
    if (_saving || _uploadingFile) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCourseId == null ||
        _selectedCourseId!.isEmpty ||
        _selectedCourseTitle == null ||
        _selectedCourseTitle!.isEmpty) {
      _showMessage(
        'Silakan pilih course terlebih dahulu.',
      );
      return;
    }

    if (_selectedClassId == null ||
        _selectedClassId!.isEmpty ||
        _selectedClassName == null ||
        _selectedClassName!.isEmpty) {
      _showMessage(
        'Silakan pilih kelas terlebih dahulu.',
      );
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Akun guru tidak ditemukan.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final points =
          int.tryParse(
            _pointsController.text.trim(),
          ) ??
              100;

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();

      final teacherName =
      (userData?['name'] ??
          userData?['username'] ??
          userData?['displayName'] ??
          user.displayName ??
          'Guru')
          .toString();

      final teacherDocumentId =
      await _getTeacherDocumentId();

      // ========================================================
      // FILE
      // ========================================================

      String fileUrl = _existingFileUrl;
      String fileName = _existingFileName;
      int fileSize = _existingFileSize;
      String fileType = _existingFileType;

      // File baru dipilih
      if (_selectedFile != null) {
        final uploadedUrl =
        await _uploadAssignmentFile();

        if (uploadedUrl == null ||
            uploadedUrl.trim().isEmpty) {
          if (mounted) {
            setState(() {
              _saving = false;
            });
          }

          return;
        }

        fileUrl = uploadedUrl;
        fileName = _selectedFileName;
        fileSize = _selectedFileSize;
        fileType = _selectedFileType;
      }

      // ========================================================
      // DATA ASSIGNMENT
      // ========================================================

      final data = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'instructions': _instructionsController.text.trim(),

        'courseId': _selectedCourseId,
        'courseTitle': _selectedCourseTitle,

        'classId': _selectedClassId,
        'className': _selectedClassName,

        'points': points,

        // Canonical teacher ID.
        'teacherId': teacherDocumentId ?? 'teacher_001',

        'teacherName': teacherName,

        // Attachment utama.
        'attachmentUrl': fileUrl,

        // Legacy compatibility.
        'fileUrl': fileUrl,

        'fileName': fileName,
        'fileSize': fileSize,
        'fileType': fileType,

        'updatedAt': FieldValue.serverTimestamp(),
      };

      // ========================================================
      // DEADLINE
      // ========================================================

      if (_dueDate != null) {
        data['dueDate'] = Timestamp.fromDate(_dueDate!);
      } else {
        data['dueDate'] = null;
      }

      // ========================================================
      // ADD
      // ========================================================

      if (widget.assignmentId == null) {
        data['createdAt'] =
            FieldValue.serverTimestamp();

        await _firestore
            .collection('assignments')
            .add(data);
      }

      // ========================================================
      // EDIT
      // ========================================================

      else {
        await _firestore
            .collection('assignments')
            .doc(widget.assignmentId)
            .update(data);
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _saving = false;
      });

      _showMessage(
        'Gagal menyimpan assignment:\n$e',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      enabled: !_saving,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        alignLabelWithHint: maxLines > 1,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ============================================================
  // FILE SECTION
  // ============================================================

  Widget _buildFileSection(ThemeData theme) {
    final hasNewFile = _selectedFile != null;
    final hasExistingFile = _existingFileUrl.isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.attach_file_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Dokumen Tugas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              'Upload file tugas yang akan digunakan oleh siswa.',
              style: theme.textTheme.bodySmall,
            ),

            const SizedBox(height: 14),

            // ==================================================
            // FILE BARU
            // ==================================================

            if (hasNewFile)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      _fileIcon(_selectedFileType),
                      size: 34,
                      color:
                      theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedFileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                            theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_selectedFileType.isEmpty ? 'FILE' : _selectedFileType} • '
                                '${_formatFileSize(_selectedFileSize)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed:
                      _saving || _uploadingFile
                          ? null
                          : _removeSelectedFile,
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              )

            // ==================================================
            // FILE LAMA
            // ==================================================

            else if (hasExistingFile)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                  theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      _fileIcon(_existingFileType),
                      size: 34,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            _existingFileName.isEmpty
                                ? 'Dokumen tugas'
                                : _existingFileName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style:
                            theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_existingFileType.isEmpty ? 'FILE' : _existingFileType} • '
                                '${_formatFileSize(_existingFileSize)}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Hapus lampiran',
                      onPressed:
                      _saving || _uploadingFile
                          ? null
                          : _removeExistingFile,
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              )

            // ==================================================
            // TIDAK ADA FILE
            // ==================================================

            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color:
                  theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 32,
                      color:
                      theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Belum ada dokumen tugas.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),

            // ==================================================
            // PICK FILE BUTTON
            // ==================================================

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                _saving || _uploadingFile
                    ? null
                    : _pickAssignmentFile,
                icon:
                _uploadingFile
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.upload_file_outlined,
                ),
                label: Text(
                  _uploadingFile
                      ? 'Mengunggah...'
                      : hasExistingFile || hasNewFile
                      ? 'Ganti Dokumen'
                      : 'Pilih Dokumen',
                ),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Format: PDF, DOC, DOCX, PPT, PPTX, '
                  'XLS, XLSX, ZIP, RAR, JPG, JPEG, PNG.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FILE ICON
  // ============================================================

  IconData _fileIcon(String type) {
    switch (type.toUpperCase()) {
      case 'PDF':
        return Icons.picture_as_pdf_outlined;

      case 'DOC':
      case 'DOCX':
        return Icons.description_outlined;

      case 'PPT':
      case 'PPTX':
        return Icons.slideshow_outlined;

      case 'XLS':
      case 'XLSX':
        return Icons.table_chart_outlined;

      case 'ZIP':
      case 'RAR':
        return Icons.folder_zip_outlined;

      case 'JPG':
      case 'JPEG':
      case 'PNG':
        return Icons.image_outlined;

      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  // ============================================================
  // COURSE & CLASS SECTION
  // ============================================================

  Widget _buildCourseClassSection(ThemeData theme) {
    if (_loadingCourses || _loadingClasses) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Memuat course dan kelas...',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_courses.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Belum ada course yang tersedia '
                      'untuk guru ini.\n\n'
                      'Buat course terlebih dahulu '
                      'sebelum menambahkan assignment.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_classes.isEmpty) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Belum ada kelas yang tersedia.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    String? courseDropdownValue;

    if (_selectedCourseId != null) {
      final matchingCourses = _courses.where(
            (course) => course.id == _selectedCourseId,
      );

      if (matchingCourses.length == 1) {
        courseDropdownValue = _selectedCourseId;
      }
    }

    String? classDropdownValue;

    if (_selectedClassId != null) {
      final matchingClasses = _classes.where(
            (classDoc) => classDoc.id == _selectedClassId,
      );

      if (matchingClasses.length == 1) {
        classDropdownValue = _selectedClassId;
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Course & Kelas',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: courseDropdownValue,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Pilih Course',
                prefixIcon: Icon(
                  Icons.library_books_outlined,
                ),
              ),
              items: _courses.map((course) {
                final data = course.data();

                final title =
                (data['title'] ?? 'Course tanpa nama')
                    .toString();

                return DropdownMenuItem<String>(
                  value: course.id,
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged:
              _saving
                  ? null
                  : (courseId) {
                if (courseId == null) {
                  return;
                }

                QueryDocumentSnapshot<
                    Map<String, dynamic>>?
                selected;

                for (final course in _courses) {
                  if (course.id == courseId) {
                    selected = course;
                    break;
                  }
                }

                if (selected != null) {
                  _setSelectedCourse(
                    selected,
                  );
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Course wajib dipilih';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              value: classDropdownValue,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Pilih Kelas',
                prefixIcon: Icon(
                  Icons.groups_outlined,
                ),
              ),
              items: _classes.map((classDoc) {
                return DropdownMenuItem<String>(
                  value: classDoc.id,
                  child: Text(
                    _getClassName(classDoc),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged:
              _saving
                  ? null
                  : (classId) {
                if (classId == null) {
                  return;
                }

                QueryDocumentSnapshot<
                    Map<String, dynamic>>?
                selected;

                for (final classDoc in _classes) {
                  if (classDoc.id == classId) {
                    selected = classDoc;
                    break;
                  }
                }

                if (selected != null) {
                  _setSelectedClass(
                    selected,
                  );
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Kelas wajib dipilih';
                }

                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DATE SECTION
  // ============================================================

  Widget _buildDateSection(ThemeData theme) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    DateTime initialDate = _dueDate ?? today;

    if (initialDate.isBefore(today)) {
      initialDate = today;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Deadline',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            CalendarDatePicker(
              initialDate: initialDate,
              firstDate: today,
              lastDate: DateTime(2100),
              onDateChanged: (date) {
                setState(() {
                  _dueDate = date;
                });
              },
            ),

            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_available_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dueDate == null
                          ? 'Belum memilih deadline'
                          : 'Deadline: '
                          '${_formatDate(_dueDate!)}',
                      style:
                      theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_dueDate != null)
                    IconButton(
                      tooltip: 'Hapus deadline',
                      onPressed:
                      _saving
                          ? null
                          : () {
                        setState(() {
                          _dueDate = null;
                        });
                      },
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
            ),
          ],
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

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEdit
              ? 'Edit Assignment'
              : 'Tambah Assignment',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            32,
          ),
          children: [
            // ==================================================
            // TITLE
            // ==================================================

            _buildTextField(
              controller: _titleController,
              label: 'Judul Tugas',
              icon: Icons.assignment_outlined,
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Judul tugas wajib diisi';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            // ==================================================
            // DESCRIPTION
            // ==================================================

            _buildTextField(
              controller: _descriptionController,
              label: 'Deskripsi',
              icon: Icons.description_outlined,
              maxLines: 4,
            ),

            const SizedBox(height: 16),

            // ==================================================
            // INSTRUCTIONS
            // ==================================================

            _buildTextField(
              controller: _instructionsController,
              label: 'Instruksi',
              icon: Icons.rule_outlined,
              maxLines: 4,
            ),

            const SizedBox(height: 16),

            // ==================================================
            // COURSE + CLASS
            // ==================================================

            _buildCourseClassSection(theme),

            const SizedBox(height: 16),

            // ==================================================
            // FILE
            // ==================================================

            _buildFileSection(theme),

            const SizedBox(height: 16),

            // ==================================================
            // POINT
            // ==================================================

            _buildTextField(
              controller: _pointsController,
              label: 'Nilai Maksimal',
              icon: Icons.star_outline,
              keyboardType: TextInputType.number,
              validator: (value) {
                final points = int.tryParse(
                  value?.trim() ?? '',
                );

                if (points == null || points <= 0) {
                  return 'Nilai maksimal harus lebih dari 0';
                }

                return null;
              },
            ),

            const SizedBox(height: 20),

            // ==================================================
            // DEADLINE
            // ==================================================

            _buildDateSection(theme),

            const SizedBox(height: 24),

            // ==================================================
            // SAVE
            // ==================================================

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed:
                _saving || _uploadingFile
                    ? null
                    : _saveAssignment,
                icon:
                _saving || _uploadingFile
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.save_outlined,
                ),
                label: Text(
                  _uploadingFile
                      ? 'Mengunggah dokumen...'
                      : _saving
                      ? 'Menyimpan...'
                      : widget.isEdit
                      ? 'Simpan Perubahan'
                      : 'Tambah Assignment',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}