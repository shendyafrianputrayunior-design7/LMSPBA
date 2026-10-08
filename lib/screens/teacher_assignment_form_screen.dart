import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _courses = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _classes = [];

  String? _selectedCourseId;
  String? _selectedCourseTitle;

  String? _selectedClassId;
  String? _selectedClassName;

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

    final existingCourseId = (data?['courseId'] ?? '').toString().trim();

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

    final existingClassId = (data?['classId'] ?? '').toString().trim();

    if (existingClassId.isNotEmpty) {
      _selectedClassId = existingClassId;
    }

    final existingClassName = (data?['className'] ?? '').toString().trim();

    if (existingClassName.isNotEmpty) {
      _selectedClassName = existingClassName;
    }

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
      // ----------------------------------------------------------
      // 1. Cek users/{uid}.teacherId
      // ----------------------------------------------------------

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

      // ----------------------------------------------------------
      // 2. Fallback berdasarkan email
      // ----------------------------------------------------------

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
      final teacherDocumentId = await _getTeacherDocumentId();

      QuerySnapshot<Map<String, dynamic>> snapshot;

      // ----------------------------------------------------------
      // Gunakan teacher document ID sebagai data utama.
      // ----------------------------------------------------------

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
        // --------------------------------------------------------
        // Fallback untuk data lama yang masih menggunakan UID.
        // Tidak mengubah data lama.
        // --------------------------------------------------------

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

      // ----------------------------------------------------------
      // Hapus kemungkinan duplikasi berdasarkan document ID.
      // ----------------------------------------------------------

      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
      uniqueCourses = {};

      for (final course in snapshot.docs) {
        uniqueCourses[course.id] = course;
      }

      final courses = uniqueCourses.values.toList();

      // ----------------------------------------------------------
      // Urutkan berdasarkan nama course.
      // ----------------------------------------------------------

      courses.sort((a, b) {
        final titleA =
        (a.data()['title'] ?? '').toString().toLowerCase();

        final titleB =
        (b.data()['title'] ?? '').toString().toLowerCase();

        return titleA.compareTo(titleB);
      });

      // ----------------------------------------------------------
      // Sinkronisasi course ketika edit.
      // ----------------------------------------------------------

      String? validSelectedCourseId = _selectedCourseId;
      String? validSelectedCourseTitle = _selectedCourseTitle;

      if (validSelectedCourseId != null) {
        QueryDocumentSnapshot<Map<String, dynamic>>? selectedCourse;

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
          // ------------------------------------------------------
          // Course lama tidak ditemukan.
          //
          // Jangan memasukkan ID tersebut ke DropdownButton,
          // karena akan menyebabkan assertion Flutter.
          // ------------------------------------------------------

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

      // ----------------------------------------------------------
      // Hilangkan duplikasi berdasarkan document ID.
      // ----------------------------------------------------------

      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>>
      uniqueClasses = {};

      for (final classDoc in snapshot.docs) {
        uniqueClasses[classDoc.id] = classDoc;
      }

      final classes = uniqueClasses.values.toList();

      classes.sort((a, b) {
        final nameA = _getClassName(a).toLowerCase();
        final nameB = _getClassName(b).toLowerCase();

        return nameA.compareTo(nameB);
      });

      // ----------------------------------------------------------
      // Sinkronisasi kelas ketika edit.
      // ----------------------------------------------------------

      String? validSelectedClassId = _selectedClassId;
      String? validSelectedClassName = _selectedClassName;

      if (validSelectedClassId != null) {
        QueryDocumentSnapshot<Map<String, dynamic>>? selectedClass;

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

    return classDoc.id;
  }

  // ============================================================
  // SELECT COURSE
  // ============================================================

  void _setSelectedCourse(
      QueryDocumentSnapshot<Map<String, dynamic>> course,
      ) {
    final data = course.data();

    final title =
    (data['title'] ?? '').toString().trim();

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

      // ----------------------------------------------------------
      // Ambil teacher document ID.
      // ----------------------------------------------------------

      final teacherDocumentId =
      await _getTeacherDocumentId();

      // ----------------------------------------------------------
      // Data assignment
      // ----------------------------------------------------------

      final data = <String, dynamic>{
        'title': _titleController.text.trim(),

        'description':
        _descriptionController.text.trim(),

        'instructions':
        _instructionsController.text.trim(),

        // --------------------------------------------------------
        // COURSE
        // --------------------------------------------------------

        'courseId': _selectedCourseId,
        'courseTitle': _selectedCourseTitle,

        // --------------------------------------------------------
        // CLASS
        // --------------------------------------------------------

        'classId': _selectedClassId,
        'className': _selectedClassName,

        // --------------------------------------------------------
        // OTHER DATA
        // --------------------------------------------------------

        'points': points,

        // Gunakan teacher document ID jika tersedia.
        // Jika tidak ditemukan, pertahankan UID sebagai
        // fallback agar proses tidak gagal.
        'teacherId':
        teacherDocumentId ?? user.uid,

        'teacherName': teacherName,

        'updatedAt':
        FieldValue.serverTimestamp(),
      };

      // ----------------------------------------------------------
      // DEADLINE
      // ----------------------------------------------------------

      if (_dueDate != null) {
        data['dueDate'] =
            Timestamp.fromDate(_dueDate!);
      } else {
        data['dueDate'] = null;
      }

      // ----------------------------------------------------------
      // ADD
      // ----------------------------------------------------------

      if (widget.assignmentId == null) {
        data['createdAt'] =
            FieldValue.serverTimestamp();

        await _firestore
            .collection('assignments')
            .add(data);
      }

      // ----------------------------------------------------------
      // EDIT
      // ----------------------------------------------------------

      else {
        await _firestore
            .collection('assignments')
            .doc(widget.assignmentId)
            .update(data);
      }

      if (!mounted) {
        return;
      }

      Navigator.pop(context, true);
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

    ScaffoldMessenger.of(context).showSnackBar(
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
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }

  // ============================================================
  // COURSE & CLASS SECTION
  // ============================================================

  Widget _buildCourseClassSection(
      ThemeData theme,
      ) {
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
                  color:
                  theme.colorScheme.primary,
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
                  'Belum ada kelas yang tersedia.\n\n'
                      'Tambahkan kelas terlebih dahulu '
                      'di collection classes.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ============================================================
    // VALIDASI VALUE COURSE UNTUK DROPDOWN
    // ============================================================

    String? courseDropdownValue;

    if (_selectedCourseId != null) {
      final matchingCourses = _courses.where(
            (course) =>
        course.id == _selectedCourseId,
      );

      if (matchingCourses.length == 1) {
        courseDropdownValue =
            _selectedCourseId;
      }
    }

    // ============================================================
    // VALIDASI VALUE CLASS UNTUK DROPDOWN
    // ============================================================

    String? classDropdownValue;

    if (_selectedClassId != null) {
      final matchingClasses = _classes.where(
            (classDoc) =>
        classDoc.id == _selectedClassId,
      );

      if (matchingClasses.length == 1) {
        classDropdownValue =
            _selectedClassId;
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
            // ======================================================
            // HEADER
            // ======================================================

            Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  color:
                  theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Course & Kelas',
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                    FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ======================================================
            // COURSE
            // ======================================================

            DropdownButtonFormField<String>(
              value: courseDropdownValue,
              isExpanded: true,
              decoration:
              const InputDecoration(
                labelText: 'Pilih Course',
                prefixIcon: Icon(
                  Icons.library_books_outlined,
                ),
              ),
              items: _courses.map((course) {
                final data = course.data();

                final title =
                (data['title'] ??
                    'Course tanpa nama')
                    .toString();

                return DropdownMenuItem<String>(
                  value: course.id,
                  child: Text(
                    title,
                    overflow:
                    TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _saving
                  ? null
                  : (courseId) {
                if (courseId == null) {
                  return;
                }

                QueryDocumentSnapshot<
                    Map<String, dynamic>>?
                selected;

                for (final course
                in _courses) {
                  if (course.id ==
                      courseId) {
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
                if (value == null ||
                    value.isEmpty) {
                  return 'Course wajib dipilih';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            // ======================================================
            // CLASS
            // ======================================================

            DropdownButtonFormField<String>(
              value: classDropdownValue,
              isExpanded: true,
              decoration:
              const InputDecoration(
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
                    overflow:
                    TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _saving
                  ? null
                  : (classId) {
                if (classId == null) {
                  return;
                }

                QueryDocumentSnapshot<
                    Map<String, dynamic>>?
                selected;

                for (final classDoc
                in _classes) {
                  if (classDoc.id ==
                      classId) {
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
                if (value == null ||
                    value.isEmpty) {
                  return 'Kelas wajib dipilih';
                }

                return null;
              },
            ),

            const SizedBox(height: 12),

            // ======================================================
            // INFORMATION
            // ======================================================

            Container(
              width: double.infinity,
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
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color:
                    theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Course dan kelas dipilih '
                          'secara otomatis dari data '
                          'Firestore. ID tidak perlu '
                          'dimasukkan secara manual.',
                      style: theme
                          .textTheme
                          .bodySmall,
                    ),
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
  // DATE SECTION
  // ============================================================

  Widget _buildDateSection(
      ThemeData theme,
      ) {
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    DateTime initialDate =
        _dueDate ?? today;

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
                  color:
                  theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Deadline',
                  style: theme
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                    fontWeight:
                    FontWeight.bold,
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
                    Icons.event_available_outlined,
                    size: 20,
                    color:
                    theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _dueDate == null
                          ? 'Belum memilih deadline'
                          : 'Deadline: '
                          '${_formatDate(_dueDate!)}',
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_dueDate != null)
                    IconButton(
                      tooltip:
                      'Hapus deadline',
                      onPressed: _saving
                          ? null
                          : () {
                        setState(() {
                          _dueDate = null;
                        });
                      },
                      icon:
                      const Icon(Icons.close),
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
          padding:
          const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            32,
          ),
          children: [
            // ======================================================
            // TITLE
            // ======================================================

            _buildTextField(
              controller:
              _titleController,
              label: 'Judul Tugas',
              icon:
              Icons.assignment_outlined,
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Judul tugas wajib diisi';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            // ======================================================
            // DESCRIPTION
            // ======================================================

            _buildTextField(
              controller:
              _descriptionController,
              label: 'Deskripsi',
              icon:
              Icons.description_outlined,
              maxLines: 4,
            ),

            const SizedBox(height: 16),

            // ======================================================
            // INSTRUCTIONS
            // ======================================================

            _buildTextField(
              controller:
              _instructionsController,
              label: 'Instruksi',
              icon:
              Icons.rule_outlined,
              maxLines: 4,
            ),

            const SizedBox(height: 16),

            // ======================================================
            // COURSE + CLASS
            // ======================================================

            _buildCourseClassSection(
              theme,
            ),

            const SizedBox(height: 16),

            // ======================================================
            // POINTS
            // ======================================================

            _buildTextField(
              controller:
              _pointsController,
              label: 'Nilai Maksimal',
              icon:
              Icons.star_outline,
              keyboardType:
              TextInputType.number,
              validator: (value) {
                final points =
                int.tryParse(
                  value?.trim() ?? '',
                );

                if (points == null ||
                    points <= 0) {
                  return 'Nilai maksimal harus '
                      'lebih dari 0';
                }

                return null;
              },
            ),

            const SizedBox(height: 20),

            // ======================================================
            // DEADLINE
            // ======================================================

            _buildDateSection(theme),

            const SizedBox(height: 24),

            // ======================================================
            // SAVE BUTTON
            // ======================================================

            SizedBox(
              height: 52,
              child:
              FilledButton.icon(
                onPressed: _saving
                    ? null
                    : _saveAssignment,
                icon: _saving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.save_outlined,
                ),
                label: Text(
                  _saving
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