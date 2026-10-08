import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherExamFormScreen extends StatefulWidget {
  final String? examId;
  final Map<String, dynamic>? examData;

  const TeacherExamFormScreen({
    super.key,
    this.examId,
    this.examData,
  });

  bool get isEdit => examId != null;

  @override
  State<TeacherExamFormScreen> createState() =>
      _TeacherExamFormScreenState();
}

class _TeacherExamFormScreenState extends State<TeacherExamFormScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ID guru standar di seluruh sistem
  static const String _teacherId = 'teacher_001';

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dateController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;
  late final TextEditingController _roomController;
  late final TextEditingController _durationController;

  bool _saving = false;
  bool _loadingData = true;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _courses = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _classes = [];

  String? _selectedCourseId;
  String? _selectedCourseName;

  String? _selectedClassId;
  String? _selectedClassName;

  @override
  void initState() {
    super.initState();

    final data = widget.examData;

    _titleController = TextEditingController(
      text: (data?['title'] ?? '').toString(),
    );

    _descriptionController = TextEditingController(
      text: (data?['description'] ?? '').toString(),
    );

    _dateController = TextEditingController(
      text: (data?['date'] ?? '').toString(),
    );

    _startTimeController = TextEditingController(
      text: (data?['startTime'] ?? '07:00').toString(),
    );

    _endTimeController = TextEditingController(
      text: (data?['endTime'] ?? '08:00').toString(),
    );

    _roomController = TextEditingController(
      text: (data?['room'] ?? '').toString(),
    );

    _durationController = TextEditingController(
      text: (data?['duration'] ?? '60').toString(),
    );

    // Data lama ketika edit
    final oldCourseId = (data?['courseId'] ?? '').toString();
    final oldCourseName = (
        data?['courseName'] ??
            data?['courseTitle'] ??
            ''
    ).toString();

    final oldClassId = (data?['classId'] ?? '').toString();
    final oldClassName = (data?['className'] ?? '').toString();

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

    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _roomController.dispose();
    _durationController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD COURSE + CLASS
  // ============================================================

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        // ======================================================
        // COURSE
        // ======================================================
        _firestore
            .collection('courses')
            .where(
          'teacherId',
          isEqualTo: _teacherId,
        )
            .get(),

        // ======================================================
        // CLASS
        // ======================================================
        _firestore
            .collection('classes')
            .get(),
      ]);

      final courseSnapshot =
      results[0] as QuerySnapshot<Map<String, dynamic>>;

      final classSnapshot =
      results[1] as QuerySnapshot<Map<String, dynamic>>;

      final courses = courseSnapshot.docs.toList();
      final classes = classSnapshot.docs.toList();

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

      // ========================================================
      // SORT CLASS
      // ========================================================

      classes.sort((a, b) {
        final dataA = a.data();
        final dataB = b.data();

        final nameA = (
            dataA['name'] ??
                dataA['className'] ??
                a.id
        ).toString().toLowerCase();

        final nameB = (
            dataB['name'] ??
                dataB['className'] ??
                b.id
        ).toString().toLowerCase();

        return nameA.compareTo(nameB);
      });

      if (!mounted) return;

      // ========================================================
      // VALIDASI COURSE LAMA
      // ========================================================

      String? validCourseId;
      String? validCourseName;

      if (_selectedCourseId != null) {
        for (final course in courses) {
          if (course.id == _selectedCourseId) {
            final data = course.data();

            validCourseId = course.id;
            validCourseName = (
                data['title'] ??
                    data['courseTitle'] ??
                    data['name'] ??
                    ''
            ).toString();

            break;
          }
        }
      }

      // ========================================================
      // VALIDASI CLASS LAMA
      // ========================================================

      String? validClassId;
      String? validClassName;

      if (_selectedClassId != null) {
        for (final classDoc in classes) {
          if (classDoc.id == _selectedClassId) {
            final data = classDoc.data();

            validClassId = classDoc.id;
            validClassName = (
                data['name'] ??
                    data['className'] ??
                    classDoc.id
            ).toString();

            break;
          }
        }
      }

      setState(() {
        _courses = courses;
        _classes = classes;

        _selectedCourseId = validCourseId;
        _selectedCourseName = validCourseName;

        _selectedClassId = validClassId;
        _selectedClassName = validClassName;

        _loadingData = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingData = false;
      });

      _showMessage(
        'Gagal mengambil data:\n$e',
      );
    }
  }

  // ============================================================
  // COURSE
  // ============================================================

  void _onCourseChanged(String? courseId) {
    if (courseId == null) {
      setState(() {
        _selectedCourseId = null;
        _selectedCourseName = null;
      });

      return;
    }

    QueryDocumentSnapshot<Map<String, dynamic>>? selectedCourse;

    for (final course in _courses) {
      if (course.id == courseId) {
        selectedCourse = course;
        break;
      }
    }

    if (selectedCourse == null) return;

    final data = selectedCourse.data();

    setState(() {
      _selectedCourseId = selectedCourse!.id;

      _selectedCourseName = (
          data['title'] ??
              data['courseTitle'] ??
              data['name'] ??
              ''
      ).toString();
    });
  }

  // ============================================================
  // CLASS
  // ============================================================

  void _onClassChanged(String? classId) {
    if (classId == null) {
      setState(() {
        _selectedClassId = null;
        _selectedClassName = null;
      });

      return;
    }

    QueryDocumentSnapshot<Map<String, dynamic>>? selectedClass;

    for (final classDoc in _classes) {
      if (classDoc.id == classId) {
        selectedClass = classDoc;
        break;
      }
    }

    if (selectedClass == null) return;

    final data = selectedClass.data();

    setState(() {
      _selectedClassId = selectedClass!.id;

      _selectedClassName = (
          data['name'] ??
              data['className'] ??
              selectedClass.id
      ).toString();
    });
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _saveExam() async {
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
      // ========================================================
      // DATA GURU
      // ========================================================

      final teacherDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final teacherData = teacherDoc.data();

      final teacherName = (
          teacherData?['name'] ??
              teacherData?['username'] ??
              teacherData?['displayName'] ??
              user.displayName ??
              'Guru'
      ).toString();

      // ========================================================
      // DATA UJIAN
      // ========================================================

      final data = <String, dynamic>{
        // GURU
        'teacherId': _teacherId,
        'teacherName': teacherName,

        // UJIAN
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),

        // COURSE
        'courseId': _selectedCourseId,
        'courseName': _selectedCourseName ?? '',

        // KELAS
        'classId': _selectedClassId,
        'className': _selectedClassName ?? '',

        // JADWAL
        'date': _dateController.text.trim(),
        'startTime': _startTimeController.text.trim(),
        'endTime': _endTimeController.text.trim(),

        // RUANGAN
        'room': _roomController.text.trim(),

        // DURASI
        'duration': int.tryParse(
          _durationController.text.trim(),
        ) ??
            60,

        'updatedAt': FieldValue.serverTimestamp(),
      };

      // ========================================================
      // TAMBAH
      // ========================================================

      if (widget.examId == null) {
        data['createdAt'] =
            FieldValue.serverTimestamp();

        await _firestore
            .collection('exams')
            .add(data);
      }

      // ========================================================
      // EDIT
      // ========================================================

      else {
        await _firestore
            .collection('exams')
            .doc(widget.examId)
            .update(data);
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showMessage(
        'Gagal menyimpan ujian:\n$e',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // DATE
  // ============================================================

  Future<void> _selectDate() async {
    DateTime initialDate = DateTime.now();

    final currentText = _dateController.text.trim();

    final parts = currentText.split('/');

    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);

      if (day != null &&
          month != null &&
          year != null) {
        final parsed = DateTime.tryParse(
          '$year-'
              '${month.toString().padLeft(2, '0')}-'
              '${day.toString().padLeft(2, '0')}',
        );

        if (parsed != null) {
          initialDate = parsed;
        }
      }
    }

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null) {
      return;
    }

    _dateController.text =
    '${selectedDate.day.toString().padLeft(2, '0')}/'
        '${selectedDate.month.toString().padLeft(2, '0')}/'
        '${selectedDate.year}';
  }

  // ============================================================
  // TIME
  // ============================================================

  Future<void> _selectStartTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _parseTime(
        _startTimeController.text,
      ),
    );

    if (selected == null) return;

    _startTimeController.text =
        _formatTime(selected);
  }

  Future<void> _selectEndTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _parseTime(
        _endTimeController.text,
      ),
    );

    if (selected == null) return;

    _endTimeController.text =
        _formatTime(selected);
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');

    if (parts.length == 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);

      if (hour != null &&
          minute != null &&
          hour >= 0 &&
          hour <= 23 &&
          minute >= 0 &&
          minute <= 59) {
        return TimeOfDay(
          hour: hour,
          minute: minute,
        );
      }
    }

    return const TimeOfDay(
      hour: 7,
      minute: 0,
    );
  }

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }

  // ============================================================
  // COURSE DROPDOWN
  // ============================================================

  Widget _buildCourseDropdown() {
    if (_loadingData) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Course',
          prefixIcon: Icon(
            Icons.book_outlined,
          ),
        ),
        child: const SizedBox(
          height: 24,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ),
        ),
      );
    }

    if (_courses.isEmpty) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Course',
          prefixIcon: Icon(
            Icons.book_outlined,
          ),
        ),
        child: const Text(
          'Belum ada course yang ditugaskan kepada Anda.',
        ),
      );
    }

    // Pastikan nilai awal memang ada di daftar course.
    final validCourseId =
    _courses.any(
          (course) => course.id == _selectedCourseId,
    )
        ? _selectedCourseId
        : null;

    return DropdownButtonFormField<String>(
      initialValue: validCourseId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Course',
        prefixIcon: Icon(
          Icons.book_outlined,
        ),
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
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged:
      _saving ? null : _onCourseChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Course wajib dipilih';
        }

        return null;
      },
    );
  }

  // ============================================================
  // CLASS DROPDOWN
  // ============================================================

  Widget _buildClassDropdown() {
    if (_loadingData) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Kelas',
          prefixIcon: Icon(
            Icons.groups_outlined,
          ),
        ),
        child: const SizedBox(
          height: 24,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          ),
        ),
      );
    }

    if (_classes.isEmpty) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Kelas',
          prefixIcon: Icon(
            Icons.groups_outlined,
          ),
        ),
        child: const Text(
          'Belum ada data kelas.',
        ),
      );
    }

    final validClassId =
    _classes.any(
          (classDoc) => classDoc.id == _selectedClassId,
    )
        ? _selectedClassId
        : null;

    return DropdownButtonFormField<String>(
      initialValue: validClassId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Kelas',
        prefixIcon: Icon(
          Icons.groups_outlined,
        ),
      ),
      items: _classes.map((classDoc) {
        final data = classDoc.data();

        final name = (
            data['name'] ??
                data['className'] ??
                classDoc.id
        ).toString();

        return DropdownMenuItem<String>(
          value: classDoc.id,
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged:
      _saving ? null : _onClassChanged,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Kelas wajib dipilih';
        }

        return null;
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEdit
              ? 'Edit Ujian'
              : 'Tambah Ujian',
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
            _buildField(
              controller: _titleController,
              label: 'Judul Ujian',
              icon: Icons.school_outlined,
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Judul ujian wajib diisi';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            _buildField(
              controller: _descriptionController,
              label: 'Deskripsi',
              icon: Icons.description_outlined,
              maxLines: 4,
            ),

            const SizedBox(height: 16),

            _buildCourseDropdown(),

            const SizedBox(height: 16),

            _buildClassDropdown(),

            const SizedBox(height: 16),

            _buildField(
              controller: _dateController,
              label: 'Tanggal',
              icon: Icons.calendar_today_outlined,
              readOnly: true,
              onTap: _selectDate,
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Tanggal wajib diisi';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildField(
                    controller:
                    _startTimeController,
                    label: 'Jam Mulai',
                    icon:
                    Icons.access_time_outlined,
                    readOnly: true,
                    onTap:
                    _selectStartTime,
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Jam mulai wajib diisi';
                      }

                      return null;
                    },
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _buildField(
                    controller:
                    _endTimeController,
                    label: 'Jam Selesai',
                    icon:
                    Icons.access_time_outlined,
                    readOnly: true,
                    onTap:
                    _selectEndTime,
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Jam selesai wajib diisi';
                      }

                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            _buildField(
              controller: _roomController,
              label: 'Ruangan',
              icon:
              Icons.meeting_room_outlined,
            ),

            const SizedBox(height: 16),

            _buildField(
              controller: _durationController,
              label: 'Durasi (menit)',
              icon: Icons.timer_outlined,
              keyboardType:
              TextInputType.number,
              validator: (value) {
                final duration =
                int.tryParse(
                  value?.trim() ?? '',
                );

                if (duration == null ||
                    duration <= 0) {
                  return 'Durasi harus lebih dari 0';
                }

                return null;
              },
            ),

            const SizedBox(height: 28),

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed:
                _saving ? null : _saveExam,
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
                      : 'Tambah Ujian',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}