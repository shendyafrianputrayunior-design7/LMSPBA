
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

  String? _teacherDocumentId;

  File? _selectedFile;
  String _selectedFileName = '';
  int _selectedFileSize = 0;
  String _selectedFileType = '';

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
      text: (data?['points'] ?? data?['maxScore'] ?? 100).toString(),
    );

    final existingDueDate = data?['dueDate'];

    if (existingDueDate is Timestamp) {
      _dueDate = existingDueDate.toDate();
    } else if (existingDueDate is DateTime) {
      _dueDate = existingDueDate;
    }

    _selectedCourseId =
    (data?['courseId'] ?? '').toString().trim().isEmpty
        ? null
        : data!['courseId'].toString().trim();

    _selectedCourseTitle =
        (data?['courseTitle'] ?? data?['courseName'] ?? '')
            .toString()
            .trim();

    _selectedClassId =
    (data?['classId'] ?? '').toString().trim().isEmpty
        ? null
        : data!['classId'].toString().trim();

    _selectedClassName =
        (data?['className'] ?? '').toString().trim();

    _existingFileUrl =
        (data?['attachmentUrl'] ?? data?['fileUrl'] ?? '')
            .toString()
            .trim();

    _existingFileName =
        (data?['fileName'] ?? data?['attachmentName'] ?? '')
            .toString()
            .trim();

    _existingFileSize =
        int.tryParse((data?['fileSize'] ?? 0).toString()) ?? 0;

    _existingFileType =
        (data?['fileType'] ?? '').toString().trim();

    _initializeForm();
  }

  Future<void> _initializeForm() async {
    await _loadTeacherDocumentId();

    if (!mounted) return;

    await Future.wait([
      _loadCourses(),
      _loadClasses(),
    ]);
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
  // Prioritas: users.teacherId, kemudian UID/email pada teachers.
  // Tidak menggunakan fallback teacher_001 secara otomatis.
  // ============================================================

  Future<void> _loadTeacherDocumentId() async {
    final user = _auth.currentUser;

    if (user == null) {
      _teacherDocumentId = null;
      return;
    }

    try {
      final userDoc =
      await _firestore.collection('users').doc(user.uid).get();

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
          _teacherDocumentId = teacherDoc.id;
          debugPrint('Teacher document ID: $_teacherDocumentId');
          return;
        }
      }

      // Alternatif jika dokumen teachers menyimpan Firebase UID.
      final uidQuery = await _firestore
          .collection('teachers')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (uidQuery.docs.isNotEmpty) {
        _teacherDocumentId = uidQuery.docs.first.id;
        debugPrint('Teacher document ID: $_teacherDocumentId');
        return;
      }

      // Alternatif pencarian menggunakan email akun.
      final email = user.email?.trim();

      if (email != null && email.isNotEmpty) {
        final emailQuery = await _firestore
            .collection('teachers')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (emailQuery.docs.isNotEmpty) {
          _teacherDocumentId = emailQuery.docs.first.id;
          debugPrint('Teacher document ID: $_teacherDocumentId');
          return;
        }
      }

      _teacherDocumentId = null;
      debugPrint('Dokumen guru tidak ditemukan untuk UID ${user.uid}');
    } catch (e) {
      _teacherDocumentId = null;
      debugPrint('Gagal mencari ID dokumen guru: $e');
    }
  }

  // ============================================================
  // LOAD COURSES
  // Course harus menggunakan teacherId yang sama dengan dokumen guru.
  // ============================================================

  Future<void> _loadCourses() async {
    try {
      final teacherId = _teacherDocumentId;

      if (teacherId == null || teacherId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _courses = [];
          _selectedCourseId = null;
          _selectedCourseTitle = null;
          _loadingCourses = false;
        });
        return;
      }

      final snapshot = await _firestore
          .collection('courses')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      if (!mounted) return;

      final courses = snapshot.docs.toList();

      courses.sort((a, b) {
        final titleA =
        (a.data()['title'] ?? '').toString().toLowerCase();
        final titleB =
        (b.data()['title'] ?? '').toString().toLowerCase();
        return titleA.compareTo(titleB);
      });

      final selectedCourse = courses.where(
            (course) => course.id == _selectedCourseId,
      );

      if (selectedCourse.isNotEmpty) {
        final data = selectedCourse.first.data();
        _selectedCourseTitle =
            (data['title'] ?? 'Course tanpa nama').toString().trim();
      } else {
        _selectedCourseId = null;
        _selectedCourseTitle = null;
      }

      setState(() {
        _courses = courses;
        _loadingCourses = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _courses = [];
        _selectedCourseId = null;
        _selectedCourseTitle = null;
        _loadingCourses = false;
      });

      _showMessage('Gagal mengambil daftar course:\n$e');
    }
  }

  // ============================================================
  // LOAD CLASSES
  // ============================================================

  Future<void> _loadClasses() async {
    try {
      final snapshot = await _firestore.collection('classes').get();

      if (!mounted) return;

      final classes = snapshot.docs.toList();

      classes.sort((a, b) {
        return _getClassName(a)
            .toLowerCase()
            .compareTo(_getClassName(b).toLowerCase());
      });

      final selectedClass = classes.where(
            (item) => item.id == _selectedClassId,
      );

      if (selectedClass.isNotEmpty) {
        _selectedClassName = _getClassName(selectedClass.first);
      } else {
        _selectedClassId = null;
        _selectedClassName = null;
      }

      setState(() {
        _classes = classes;
        _loadingClasses = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _classes = [];
        _selectedClassId = null;
        _selectedClassName = null;
        _loadingClasses = false;
      });

      _showMessage('Gagal mengambil daftar kelas:\n$e');
    }
  }

  String _getClassName(
      QueryDocumentSnapshot<Map<String, dynamic>> classDoc,
      ) {
    final data = classDoc.data();

    final name = (data['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    final className = (data['className'] ?? '').toString().trim();
    if (className.isNotEmpty) return className;

    return classDoc.id;
  }

  void _setSelectedCourse(
      QueryDocumentSnapshot<Map<String, dynamic>> course,
      ) {
    final title = (course.data()['title'] ?? '').toString().trim();

    setState(() {
      _selectedCourseId = course.id;
      _selectedCourseTitle =
      title.isNotEmpty ? title : 'Course tanpa nama';
    });
  }

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
    if (_saving || _uploadingFile) return;

    try {
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

      if (result.isEmpty) return;

      final PlatformFile picked = result.first;
      final String? pickedPath = picked.path;

      if (pickedPath == null || pickedPath.trim().isEmpty) {
        _showMessage('File tidak dapat dibaca dari perangkat.');
        return;
      }

      final File file = File(pickedPath);

      if (!await file.exists()) {
        _showMessage('File tidak ditemukan.');
        return;
      }

      final String fileName = picked.name.trim();
      final String extension = fileName.contains('.')
          ? fileName.split('.').last.toUpperCase()
          : '';
      final int fileSize = await file.length();

      if (!mounted) return;

      setState(() {
        _selectedFile = file;
        _selectedFileName = fileName;
        _selectedFileSize = fileSize;
        _selectedFileType = extension;
      });
    } catch (e) {
      _showMessage('Gagal memilih file:\n$e');
    }
  }

  void _removeSelectedFile() {
    if (_saving || _uploadingFile) return;

    setState(() {
      _selectedFile = null;
      _selectedFileName = '';
      _selectedFileSize = 0;
      _selectedFileType = '';
    });
  }

  void _removeExistingFile() {
    if (_saving || _uploadingFile) return;

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
    if (bytes <= 0) return '-';
    if (bytes < 1024) return '$bytes B';

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
    if (_selectedFile == null) return null;

    if (mounted) {
      setState(() => _uploadingFile = true);
    }

    try {
      final url = await CloudinaryService.uploadAssignmentFile(
        _selectedFile!,
      );

      if (url == null || url.trim().isEmpty) {
        throw Exception('Cloudinary tidak mengembalikan URL file.');
      }

      return url;
    } catch (e) {
      _showMessage('Gagal mengunggah dokumen:\n$e');
      return null;
    } finally {
      if (mounted) {
        setState(() => _uploadingFile = false);
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
    if (_saving || _uploadingFile) return;

    if (!_formKey.currentState!.validate()) return;

    if (_teacherDocumentId == null ||
        _teacherDocumentId!.isEmpty) {
      _showMessage(
        'ID guru tidak ditemukan. Periksa data akun di Firestore.',
      );
      return;
    }

    if (_selectedCourseId == null ||
        _selectedCourseId!.isEmpty ||
        _selectedCourseTitle == null ||
        _selectedCourseTitle!.isEmpty) {
      _showMessage('Silakan pilih course terlebih dahulu.');
      return;
    }

    if (_selectedClassId == null ||
        _selectedClassId!.isEmpty ||
        _selectedClassName == null ||
        _selectedClassName!.isEmpty) {
      _showMessage('Silakan pilih kelas terlebih dahulu.');
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Akun guru tidak ditemukan.');
      return;
    }

    setState(() => _saving = true);

    try {
      final points = int.parse(_pointsController.text.trim());

      if (points <= 0 || points > 100) {
        throw Exception('Nilai maksimal harus antara 1 sampai 100.');
      }

      // Pastikan course memang milik guru yang sedang login.
      final courseDoc = await _firestore
          .collection('courses')
          .doc(_selectedCourseId)
          .get();

      if (!courseDoc.exists ||
          courseDoc.data()?['teacherId'] != _teacherDocumentId) {
        throw Exception(
          'Course tidak ditemukan atau bukan milik akun guru ini.',
        );
      }

      final userDoc =
      await _firestore.collection('users').doc(user.uid).get();

      final userData = userDoc.data();

      final teacherName = (
          userData?['name'] ??
              userData?['username'] ??
              userData?['displayName'] ??
              user.displayName ??
              'Guru'
      ).toString();

      // Saat edit, pastikan assignment memang milik guru ini.
      if (widget.assignmentId != null) {
        final assignmentDoc = await _firestore
            .collection('assignments')
            .doc(widget.assignmentId)
            .get();

        if (!assignmentDoc.exists) {
          throw Exception('Assignment yang akan diedit tidak ditemukan.');
        }

        if (assignmentDoc.data()?['teacherId'] != _teacherDocumentId) {
          throw Exception(
            'Kamu tidak memiliki izin untuk mengedit assignment ini.',
          );
        }
      }

      String fileUrl = _existingFileUrl;
      String fileName = _existingFileName;
      int fileSize = _existingFileSize;
      String fileType = _existingFileType;

      if (_selectedFile != null) {
        final uploadedUrl = await _uploadAssignmentFile();

        if (uploadedUrl == null || uploadedUrl.trim().isEmpty) {
          if (mounted) setState(() => _saving = false);
          return;
        }

        fileUrl = uploadedUrl;
        fileName = _selectedFileName;
        fileSize = _selectedFileSize;
        fileType = _selectedFileType;
      }

      final data = <String, dynamic>{
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'courseId': _selectedCourseId,
        'courseTitle': _selectedCourseTitle,
        'classId': _selectedClassId,
        'className': _selectedClassName,
        'points': points,
        'teacherId': _teacherDocumentId,
        'teacherName': teacherName,
        'attachmentUrl': fileUrl,
        'fileUrl': fileUrl,
        'fileName': fileName,
        'fileSize': fileSize,
        'fileType': fileType,
        'dueDate': _dueDate == null
            ? null
            : Timestamp.fromDate(_dueDate!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.assignmentId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();

        await _firestore.collection('assignments').add(data);
      } else {
        await _firestore
            .collection('assignments')
            .doc(widget.assignmentId)
            .update(data);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() => _saving = false);
      _showMessage('Gagal menyimpan assignment:\n$e');
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
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
            if (hasNewFile)
              _buildFileTile(
                theme: theme,
                name: _selectedFileName,
                type: _selectedFileType,
                size: _selectedFileSize,
                onRemove: _removeSelectedFile,
                isNew: true,
              )
            else if (hasExistingFile)
              _buildFileTile(
                theme: theme,
                name: _existingFileName.isEmpty
                    ? 'Dokumen tugas'
                    : _existingFileName,
                type: _existingFileType,
                size: _existingFileSize,
                onRemove: _removeExistingFile,
                isNew: false,
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 32,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Belum ada dokumen tugas.'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving || _uploadingFile
                    ? null
                    : _pickAssignmentFile,
                icon: _uploadingFile
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.upload_file_outlined),
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
                  'XLS, XLSX, ZIP, RAR, JPG, JPEG, PNG. Maksimal 20 MB.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileTile({
    required ThemeData theme,
    required String name,
    required String type,
    required int size,
    required VoidCallback onRemove,
    required bool isNew,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNew
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            _fileIcon(type),
            size: 34,
            color: isNew
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${type.isEmpty ? 'FILE' : type} • ${_formatFileSize(size)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: isNew ? 'Batalkan file baru' : 'Hapus lampiran',
            onPressed: _saving || _uploadingFile ? null : onRemove,
            icon: Icon(isNew ? Icons.close : Icons.delete_outline),
          ),
        ],
      ),
    );
  }

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
                child: Text('Memuat course dan kelas...'),
              ),
            ],
          ),
        ),
      );
    }

    if (_teacherDocumentId == null) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.red),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ID dokumen guru tidak ditemukan. '
                      'Periksa hubungan akun pada koleksi users dan teachers.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_courses.isEmpty) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.red),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Belum ada course untuk guru ini. '
                      'Pastikan teacherId pada course sesuai dengan ID dokumen guru.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_classes.isEmpty) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.red),
              SizedBox(width: 12),
              Expanded(
                child: Text('Belum ada kelas yang tersedia.'),
              ),
            ],
          ),
        ),
      );
    }

    final courseDropdownValue =
    _courses.any((course) => course.id == _selectedCourseId)
        ? _selectedCourseId
        : null;

    final classDropdownValue =
    _classes.any((item) => item.id == _selectedClassId)
        ? _selectedClassId
        : null;

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
                prefixIcon: Icon(Icons.library_books_outlined),
              ),
              items: _courses.map((course) {
                final title =
                (course.data()['title'] ?? 'Course tanpa nama')
                    .toString();

                return DropdownMenuItem<String>(
                  value: course.id,
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _saving
                  ? null
                  : (courseId) {
                if (courseId == null) return;

                for (final course in _courses) {
                  if (course.id == courseId) {
                    _setSelectedCourse(course);
                    break;
                  }
                }
              },
              validator: (value) =>
              value == null || value.isEmpty
                  ? 'Course wajib dipilih'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: classDropdownValue,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Pilih Kelas',
                prefixIcon: Icon(Icons.groups_outlined),
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
              onChanged: _saving
                  ? null
                  : (classId) {
                if (classId == null) return;

                for (final classDoc in _classes) {
                  if (classDoc.id == classId) {
                    _setSelectedClass(classDoc);
                    break;
                  }
                }
              },
              validator: (value) =>
              value == null || value.isEmpty
                  ? 'Kelas wajib dipilih'
                  : null,
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
          crossAxisAlignment: CrossAxisAlignment.start,
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
                setState(() => _dueDate = date);
              },
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
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
                          : 'Deadline: ${_formatDate(_dueDate!)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_dueDate != null)
                    IconButton(
                      tooltip: 'Hapus deadline',
                      onPressed: _saving
                          ? null
                          : () => setState(() => _dueDate = null),
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
          widget.isEdit ? 'Edit Assignment' : 'Tambah Assignment',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _buildTextField(
              controller: _titleController,
              label: 'Judul Tugas',
              icon: Icons.assignment_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Judul tugas wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _descriptionController,
              label: 'Deskripsi',
              icon: Icons.description_outlined,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _instructionsController,
              label: 'Instruksi',
              icon: Icons.rule_outlined,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            _buildCourseClassSection(theme),
            const SizedBox(height: 16),
            _buildFileSection(theme),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _pointsController,
              label: 'Nilai Maksimal',
              icon: Icons.star_outline,
              keyboardType: TextInputType.number,
              validator: (value) {
                final points = int.tryParse(value?.trim() ?? '');

                if (points == null || points < 1 || points > 100) {
                  return 'Nilai maksimal harus antara 1 sampai 100';
                }

                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildDateSection(theme),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving || _uploadingFile
                    ? null
                    : _saveAssignment,
                icon: _saving || _uploadingFile
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.save_outlined),
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
