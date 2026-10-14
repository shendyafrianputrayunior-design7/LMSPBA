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

  String? get _teacherId => _auth.currentUser?.uid;

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

    _selectedCourseId = (data?['courseId'] ?? '').toString().isEmpty
        ? null
        : data!['courseId'].toString();

    _selectedCourseName =
        (data?['courseName'] ?? data?['courseTitle'] ?? '').toString();

    _selectedClassId = (data?['classId'] ?? '').toString().isEmpty
        ? null
        : data!['classId'].toString();

    _selectedClassName = (data?['className'] ?? '').toString();

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
    final teacherId = _teacherId;

    if (teacherId == null) {
      if (!mounted) return;

      setState(() => _loadingData = false);
      _showMessage('Silakan login terlebih dahulu.');
      return;
    }

    try {
      final results = await Future.wait([
        _firestore
            .collection('courses')
            .where('teacherId', isEqualTo: teacherId)
            .get(),
        _firestore.collection('classes').get(),
      ]);

      final courseSnapshot =
      results[0] as QuerySnapshot<Map<String, dynamic>>;
      final classSnapshot =
      results[1] as QuerySnapshot<Map<String, dynamic>>;

      final courses = courseSnapshot.docs.toList();
      final classes = classSnapshot.docs.toList();

      courses.sort((a, b) {
        final nameA = _courseName(a.data()).toLowerCase();
        final nameB = _courseName(b.data()).toLowerCase();
        return nameA.compareTo(nameB);
      });

      classes.sort((a, b) {
        final nameA = _className(a.data(), a.id).toLowerCase();
        final nameB = _className(b.data(), b.id).toLowerCase();
        return nameA.compareTo(nameB);
      });

      String? validCourseId;
      String? validCourseName;

      for (final course in courses) {
        if (course.id == _selectedCourseId) {
          validCourseId = course.id;
          validCourseName = _courseName(course.data());
          break;
        }
      }

      String? validClassId;
      String? validClassName;

      for (final classDoc in classes) {
        if (classDoc.id == _selectedClassId) {
          validClassId = classDoc.id;
          validClassName = _className(classDoc.data(), classDoc.id);
          break;
        }
      }

      if (!mounted) return;

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

      setState(() => _loadingData = false);
      _showMessage('Gagal mengambil data:\n$e');
    }
  }

  String _courseName(Map<String, dynamic> data) {
    return (data['title'] ??
        data['courseTitle'] ??
        data['name'] ??
        'Tanpa Nama Course')
        .toString();
  }

  String _className(Map<String, dynamic> data, String id) {
    return (data['name'] ?? data['className'] ?? id).toString();
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

    for (final course in _courses) {
      if (course.id == courseId) {
        setState(() {
          _selectedCourseId = course.id;
          _selectedCourseName = _courseName(course.data());
        });
        return;
      }
    }
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

    for (final classDoc in _classes) {
      if (classDoc.id == classId) {
        setState(() {
          _selectedClassId = classDoc.id;
          _selectedClassName =
              _className(classDoc.data(), classDoc.id);
        });
        return;
      }
    }
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _saveExam() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) return;

    final teacherId = _teacherId;

    if (teacherId == null) {
      _showMessage('Akun guru tidak ditemukan. Silakan login kembali.');
      return;
    }

    if (_selectedCourseId == null || _selectedCourseId!.isEmpty) {
      _showMessage('Silakan pilih course terlebih dahulu.');
      return;
    }

    if (_selectedClassId == null || _selectedClassId!.isEmpty) {
      _showMessage('Silakan pilih kelas terlebih dahulu.');
      return;
    }

    final duration = int.tryParse(_durationController.text.trim());

    if (duration == null || duration <= 0) {
      _showMessage('Durasi harus lebih dari 0 menit.');
      return;
    }

    final start = _parseTime(_startTimeController.text);
    final end = _parseTime(_endTimeController.text);

    if (end.hour * 60 + end.minute <= start.hour * 60 + start.minute) {
      _showMessage('Jam selesai harus setelah jam mulai.');
      return;
    }

    setState(() => _saving = true);

    try {
      final examCollection = _firestore.collection('exams');

      // Periksa kepemilikan saat mengedit ujian.
      if (widget.examId != null) {
        final existingExam =
        await examCollection.doc(widget.examId).get();

        if (!existingExam.exists) {
          throw Exception('Dokumen ujian tidak ditemukan.');
        }

        final existingData = existingExam.data();

        if (existingData == null ||
            existingData['teacherId']?.toString() != teacherId) {
          throw Exception('Anda tidak memiliki akses untuk mengubah ujian ini.');
        }
      }

      // Pastikan course yang dipilih memang milik guru.
      final courseSnapshot = await _firestore
          .collection('courses')
          .doc(_selectedCourseId)
          .get();

      if (!courseSnapshot.exists) {
        throw Exception('Course yang dipilih tidak ditemukan.');
      }

      final courseData = courseSnapshot.data();

      if (courseData == null ||
          courseData['teacherId']?.toString() != teacherId) {
        throw Exception('Course tersebut bukan milik Anda.');
      }

      // Ambil nama guru dari profil, jika tersedia.
      final teacherDoc =
      await _firestore.collection('users').doc(teacherId).get();

      final teacherData = teacherDoc.data();

      final teacherName = (teacherData?['name'] ??
          teacherData?['username'] ??
          teacherData?['displayName'] ??
          _auth.currentUser?.displayName ??
          'Guru')
          .toString();

      final data = <String, dynamic>{
        'teacherId': teacherId,
        'teacherName': teacherName,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'courseId': _selectedCourseId,
        'courseName': _selectedCourseName ?? '',
        'classId': _selectedClassId,
        'className': _selectedClassName ?? '',
        'date': _dateController.text.trim(),
        'startTime': _startTimeController.text.trim(),
        'endTime': _endTimeController.text.trim(),
        'room': _roomController.text.trim(),
        'duration': duration,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (widget.examId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await examCollection.add(data);
      } else {
        await examCollection.doc(widget.examId).update(data);
      }

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _showMessage('Gagal menyimpan ujian:\n$e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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

      if (day != null && month != null && year != null) {
        try {
          final parsed = DateTime(year, month, day);

          if (parsed.year == year &&
              parsed.month == month &&
              parsed.day == day) {
            initialDate = parsed;
          }
        } catch (_) {
          // Gunakan tanggal hari ini jika tanggal lama tidak valid.
        }
      }
    }

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null || !mounted) return;

    setState(() {
      _dateController.text =
      '${selectedDate.day.toString().padLeft(2, '0')}/'
          '${selectedDate.month.toString().padLeft(2, '0')}/'
          '${selectedDate.year}';
    });
  }

  // ============================================================
  // TIME
  // ============================================================

  Future<void> _selectStartTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _parseTime(_startTimeController.text),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _startTimeController.text = _formatTime(selected);
    });
  }

  Future<void> _selectEndTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _parseTime(_endTimeController.text),
    );

    if (selected == null || !mounted) return;

    setState(() {
      _endTimeController.text = _formatTime(selected);
    });
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
        return TimeOfDay(hour: hour, minute: minute);
      }
    }

    return const TimeOfDay(hour: 7, minute: 0);
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
          prefixIcon: Icon(Icons.book_outlined),
        ),
        child: const SizedBox(
          height: 24,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_courses.isEmpty) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Course',
          prefixIcon: Icon(Icons.book_outlined),
        ),
        child: const Text(
          'Belum ada course yang ditugaskan kepada Anda.',
        ),
      );
    }

    final validCourseId = _courses.any(
          (course) => course.id == _selectedCourseId,
    )
        ? _selectedCourseId
        : null;

    return DropdownButtonFormField<String>(
      initialValue: validCourseId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Course',
        prefixIcon: Icon(Icons.book_outlined),
      ),
      items: _courses.map((course) {
        return DropdownMenuItem<String>(
          value: course.id,
          child: Text(
            _courseName(course.data()),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: _saving ? null : _onCourseChanged,
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
          prefixIcon: Icon(Icons.groups_outlined),
        ),
        child: const SizedBox(
          height: 24,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (_classes.isEmpty) {
      return InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Kelas',
          prefixIcon: Icon(Icons.groups_outlined),
        ),
        child: const Text('Belum ada data kelas.'),
      );
    }

    final validClassId = _classes.any(
          (classDoc) => classDoc.id == _selectedClassId,
    )
        ? _selectedClassId
        : null;

    return DropdownButtonFormField<String>(
      initialValue: validClassId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Kelas',
        prefixIcon: Icon(Icons.groups_outlined),
      ),
      items: _classes.map((classDoc) {
        return DropdownMenuItem<String>(
          value: classDoc.id,
          child: Text(
            _className(classDoc.data(), classDoc.id),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: _saving ? null : _onClassChanged,
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
          widget.isEdit ? 'Edit Ujian' : 'Tambah Ujian',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _buildField(
              controller: _titleController,
              label: 'Judul Ujian',
              icon: Icons.school_outlined,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
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
                if (value == null || value.trim().isEmpty) {
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
                    controller: _startTimeController,
                    label: 'Jam Mulai',
                    icon: Icons.access_time_outlined,
                    readOnly: true,
                    onTap: _selectStartTime,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Jam mulai wajib diisi';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    controller: _endTimeController,
                    label: 'Jam Selesai',
                    icon: Icons.access_time_outlined,
                    readOnly: true,
                    onTap: _selectEndTime,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
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
              icon: Icons.meeting_room_outlined,
            ),
            const SizedBox(height: 16),
            _buildField(
              controller: _durationController,
              label: 'Durasi (menit)',
              icon: Icons.timer_outlined,
              keyboardType: TextInputType.number,
              validator: (value) {
                final duration = int.tryParse(value?.trim() ?? '');

                if (duration == null || duration <= 0) {
                  return 'Durasi harus lebih dari 0';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving || _loadingData ? null : _saveExam,
                icon: _saving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : const Icon(Icons.save_outlined),
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