import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherCourseFormScreen extends StatefulWidget {
  final String? courseId;
  final Map<String, dynamic>? courseData;

  const TeacherCourseFormScreen({
    super.key,
    this.courseId,
    this.courseData,
  });

  bool get isEdit => courseId != null;

  @override
  State<TeacherCourseFormScreen> createState() =>
      _TeacherCourseFormScreenState();
}

class _TeacherCourseFormScreenState
    extends State<TeacherCourseFormScreen> {
  // ============================================================
  // TEACHER ID STANDAR
  // ============================================================

  static const String _fixedTeacherId = 'teacher_001';

  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _instructorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageController = TextEditingController();
  final _lessonsController = TextEditingController();

  final _roomController = TextEditingController();

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  bool _loading = false;
  bool _loadingClasses = true;

  List<Map<String, dynamic>> _classes = [];

  String? _selectedClassId;
  String? _selectedClassName;

  // ============================================================
  // DATA JADWAL
  // ============================================================

  final List<String> _days = const [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  String? _selectedDay;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();

    if (widget.isEdit) {
      _fillExistingData();
    } else {
      _lessonsController.text = '0';
      _loadTeacherData();
    }

    _loadClasses();
  }

  // ============================================================
  // FILL DATA SAAT EDIT
  // ============================================================

  void _fillExistingData() {
    final data =
        widget.courseData ?? <String, dynamic>{};

    _titleController.text =
        (data['title'] ?? '').toString();

    _instructorController.text =
        (data['instructor'] ?? '').toString();

    _descriptionController.text =
        (data['description'] ?? '').toString();

    _imageController.text =
        (data['image'] ?? '').toString();

    _lessonsController.text =
        (data['lessons'] ?? 0).toString();

    final classId =
    (data['classId'] ?? '').toString().trim();

    final className =
    (data['className'] ?? '').toString().trim();

    _selectedClassId =
    classId.isEmpty ? null : classId;

    _selectedClassName =
    className.isEmpty ? null : className;

    // ------------------------------------------------------------
    // DATA JADWAL
    // ------------------------------------------------------------

    final day =
    (data['day'] ?? '').toString().trim();

    if (day.isNotEmpty && _days.contains(day)) {
      _selectedDay = day;
    }

    _roomController.text =
        (data['room'] ?? '').toString();

    _startTime = _parseTime(
      (data['startTime'] ?? '').toString(),
    );

    _endTime = _parseTime(
      (data['endTime'] ?? '').toString(),
    );
  }

  // ============================================================
  // PARSE JAM
  // ============================================================

  TimeOfDay? _parseTime(String value) {
    if (value.isEmpty) {
      return null;
    }

    final parts = value.split(':');

    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return null;
    }

    if (hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return TimeOfDay(
      hour: hour,
      minute: minute,
    );
  }

  // ============================================================
  // FORMAT JAM
  // ============================================================

  String _formatTime(TimeOfDay? time) {
    if (time == null) {
      return '';
    }

    final hour =
    time.hour.toString().padLeft(2, '0');

    final minute =
    time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  // ============================================================
  // LOAD DATA GURU
  // ============================================================

  Future<void> _loadTeacherData() async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) {
        return;
      }

      final data = doc.data();

      if (data != null) {
        _instructorController.text =
            (data['name'] ??
                data['username'] ??
                '')
                .toString();
      }
    } catch (e) {
      debugPrint(
        'Gagal mengambil data guru: $e',
      );
    }
  }

  // ============================================================
  // LOAD KELAS
  // ============================================================

  Future<void> _loadClasses() async {
    try {
      final snapshot = await _firestore
          .collection('classes')
          .get();

      final List<Map<String, dynamic>>
      loadedClasses = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final className =
        (data['name'] ??
            data['className'] ??
            data['title'] ??
            doc.id)
            .toString();

        loadedClasses.add({
          'id': doc.id,
          'name': className,
        });
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _classes = loadedClasses;
        _loadingClasses = false;
      });

      // ==========================================================
      // JIKA EDIT, CARI NAMA KELAS BERDASARKAN ID
      // ==========================================================

      if (widget.isEdit &&
          _selectedClassId != null) {
        Map<String, dynamic>? selectedClass;

        for (final item in _classes) {
          if (item['id'].toString() ==
              _selectedClassId) {
            selectedClass = item;
            break;
          }
        }

        if (selectedClass != null && mounted) {
          setState(() {
            _selectedClassName =
                selectedClass!['name'].toString();
          });
        }
      }
    } catch (e) {
      debugPrint(
        'Gagal mengambil data kelas: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loadingClasses = false;
      });

      _showMessage(
        'Gagal mengambil data kelas.',
      );
    }
  }

  // ============================================================
  // PILIH JAM MULAI
  // ============================================================

  Future<void> _selectStartTime() async {
    final selected =
    await showTimePicker(
      context: context,
      initialTime:
      _startTime ??
          const TimeOfDay(
            hour: 7,
            minute: 0,
          ),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _startTime = selected;
    });
  }

  // ============================================================
  // PILIH JAM SELESAI
  // ============================================================

  Future<void> _selectEndTime() async {
    final selected =
    await showTimePicker(
      context: context,
      initialTime:
      _endTime ??
          const TimeOfDay(
            hour: 8,
            minute: 0,
          ),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _endTime = selected;
    });
  }

  // ============================================================
  // VALIDASI JADWAL
  // ============================================================

  bool _validateSchedule() {
    if (_selectedDay == null ||
        _selectedDay!.isEmpty) {
      _showMessage(
        'Silakan pilih hari jadwal.',
      );
      return false;
    }

    if (_startTime == null) {
      _showMessage(
        'Silakan pilih jam mulai.',
      );
      return false;
    }

    if (_endTime == null) {
      _showMessage(
        'Silakan pilih jam selesai.',
      );
      return false;
    }

    final startMinutes =
        _startTime!.hour * 60 +
            _startTime!.minute;

    final endMinutes =
        _endTime!.hour * 60 +
            _endTime!.minute;

    if (endMinutes <= startMinutes) {
      _showMessage(
        'Jam selesai harus lebih besar dari jam mulai.',
      );
      return false;
    }

    if (_roomController.text.trim().isEmpty) {
      _showMessage(
        'Ruangan wajib diisi.',
      );
      return false;
    }

    return true;
  }

  // ============================================================
  // SAVE COURSE
  // ============================================================

  Future<void> _saveCourse() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedClassId == null ||
        _selectedClassId!.isEmpty) {
      _showMessage(
        'Silakan pilih kelas terlebih dahulu.',
      );
      return;
    }

    // ==========================================================
    // VALIDASI JADWAL
    // ==========================================================

    if (!_validateSchedule()) {
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
      _loading = true;
    });

    try {
      // ==========================================================
      // JUMLAH MATERI
      // ==========================================================

      final lessons =
          int.tryParse(
            _lessonsController.text.trim(),
          ) ??
              0;

      // ==========================================================
      // CARI KELAS
      // ==========================================================

      Map<String, dynamic>? selectedClass;

      for (final item in _classes) {
        if (item['id'].toString() ==
            _selectedClassId) {
          selectedClass = item;
          break;
        }
      }

      // ==========================================================
      // DATA KELAS
      // ==========================================================

      final classId =
          selectedClass?['id']?.toString() ??
              _selectedClassId!;

      final className =
          selectedClass?['name']?.toString() ??
              _selectedClassName ??
              '';

      // ==========================================================
      // DATA JADWAL
      // ==========================================================

      final startTime =
      _formatTime(_startTime);

      final endTime =
      _formatTime(_endTime);

      // ==========================================================
      // DATA COURSE
      //
      // Hari, jam dan ruangan disimpan juga di COURSE.
      // Dengan begitu COURSE menjadi sumber utama jadwal.
      // ==========================================================

      final Map<String, dynamic> courseData = {
        'teacherId': _fixedTeacherId,

        'classId': classId,
        'className': className,

        'title':
        _titleController.text.trim(),

        'instructor':
        _instructorController.text.trim(),

        'image':
        _imageController.text.trim(),

        'description':
        _descriptionController.text.trim(),

        'lessons': lessons,

        // ========================================================
        // DATA JADWAL
        // ========================================================

        'day': _selectedDay,
        'startTime': startTime,
        'endTime': endTime,
        'room':
        _roomController.text.trim(),

        'updatedAt':
        FieldValue.serverTimestamp(),
      };

      // ==========================================================
      // TAMBAH COURSE
      // ==========================================================

      if (!widget.isEdit) {
        final courseRef = await _firestore
            .collection('courses')
            .add({
          ...courseData,
          'createdAt':
          FieldValue.serverTimestamp(),
        });

        // ========================================================
        // OTOMATIS BUAT JADWAL
        // ========================================================

        await _createSchedule(
          courseId: courseRef.id,
          courseData: courseData,
        );
      }

      // ==========================================================
      // UPDATE COURSE
      // ==========================================================

      else {
        await _firestore
            .collection('courses')
            .doc(widget.courseId)
            .update(courseData);

        // ========================================================
        // OTOMATIS UPDATE JADWAL
        // ========================================================

        await _syncSchedule(
          courseId: widget.courseId!,
          courseData: courseData,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdit
                ? 'Course dan jadwal berhasil diperbarui.'
                : 'Course dan jadwal berhasil ditambahkan.',
          ),
        ),
      );

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      debugPrint(
        'Gagal menyimpan course: $e',
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        widget.isEdit
            ? 'Gagal memperbarui course: $e'
            : 'Gagal menambahkan course: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // CREATE SCHEDULE OTOMATIS
  // ============================================================

  Future<void> _createSchedule({
    required String courseId,
    required Map<String, dynamic> courseData,
  }) async {
    final scheduleData = {
      'teacherId': _fixedTeacherId,

      'courseId': courseId,

      'courseName':
      courseData['title'] ?? '',

      'subject':
      courseData['title'] ?? '',

      'teacherName':
      courseData['instructor'] ?? '',

      'classId':
      courseData['classId'] ?? '',

      'className':
      courseData['className'] ?? '',

      'day':
      courseData['day'] ?? '',

      'startTime':
      courseData['startTime'] ?? '',

      'endTime':
      courseData['endTime'] ?? '',

      'room':
      courseData['room'] ?? '',

      'createdAt':
      FieldValue.serverTimestamp(),

      'updatedAt':
      FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('schedules')
        .add(scheduleData);
  }

  // ============================================================
  // SYNC SCHEDULE SAAT COURSE DIEDIT
  // ============================================================

  Future<void> _syncSchedule({
    required String courseId,
    required Map<String, dynamic> courseData,
  }) async {
    final snapshot = await _firestore
        .collection('schedules')
        .where(
      'courseId',
      isEqualTo: courseId,
    )
        .get();

    // ==========================================================
    // DATA YANG HARUS SAMA DENGAN COURSE
    // ==========================================================

    final scheduleData = {
      'teacherId': _fixedTeacherId,

      'courseId': courseId,

      'courseName':
      courseData['title'] ?? '',

      'subject':
      courseData['title'] ?? '',

      'teacherName':
      courseData['instructor'] ?? '',

      'classId':
      courseData['classId'] ?? '',

      'className':
      courseData['className'] ?? '',

      'day':
      courseData['day'] ?? '',

      'startTime':
      courseData['startTime'] ?? '',

      'endTime':
      courseData['endTime'] ?? '',

      'room':
      courseData['room'] ?? '',

      'updatedAt':
      FieldValue.serverTimestamp(),
    };

    // ==========================================================
    // JIKA SUDAH ADA JADWAL
    // UPDATE SEMUA JADWAL TERKAIT COURSE
    // ==========================================================

    if (snapshot.docs.isNotEmpty) {
      final batch =
      _firestore.batch();

      for (final doc in snapshot.docs) {
        batch.update(
          doc.reference,
          scheduleData,
        );
      }

      await batch.commit();
    }

    // ==========================================================
    // JIKA BELUM ADA JADWAL
    // BUAT JADWAL BARU
    // ==========================================================

    else {
      await _createSchedule(
        courseId: courseId,
        courseData: courseData,
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

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
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: theme
          .colorScheme
          .surfaceContainerHighest
          .withOpacity(0.35),
      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide:
        BorderSide.none,
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide:
        BorderSide.none,
      ),
      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: BorderSide(
          color:
          theme.colorScheme.primary,
          width: 1.5,
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration({
    required String label,
    required IconData icon,
  }) {
    final theme =
    Theme.of(context);

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: theme
          .colorScheme
          .surfaceContainerHighest
          .withOpacity(0.35),
      border: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide:
        BorderSide.none,
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide:
        BorderSide.none,
      ),
      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: BorderSide(
          color:
          theme.colorScheme.primary,
          width: 1.5,
        ),
      ),
    );
  }

  // ============================================================
  // TIME FIELD DECORATION
  // ============================================================

  InputDecoration _timeDecoration({
    required String label,
    required IconData icon,
  }) {
    return _inputDecoration(
      label: label,
      icon: icon,
      hint: 'Pilih waktu',
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _titleController.dispose();
    _instructorController.dispose();
    _descriptionController.dispose();
    _imageController.dispose();
    _lessonsController.dispose();
    _roomController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);

    String? dropdownClassValue;

    if (_selectedClassId != null &&
        _classes.any(
              (item) =>
          item['id'].toString() ==
              _selectedClassId,
        )) {
      dropdownClassValue =
          _selectedClassId;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEdit
              ? 'Edit Course'
              : 'Tambah Course',
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
                    ? 'Edit Course'
                    : 'Buat Course Baru',
                style: theme
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                widget.isEdit
                    ? 'Perbarui informasi course Anda.'
                    : 'Lengkapi informasi course yang akan diberikan kepada siswa.',
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // JUDUL COURSE
              // ==================================================

              TextFormField(
                controller:
                _titleController,
                textInputAction:
                TextInputAction.next,
                decoration:
                _inputDecoration(
                  label:
                  'Judul Course',
                  hint:
                  'Contoh: Pemrograman Flutter',
                  icon: Icons
                      .menu_book_outlined,
                ),
                validator: (value) {
                  if (value == null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Judul course wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ==================================================
              // INSTRUKTUR
              // ==================================================

              TextFormField(
                controller:
                _instructorController,
                textInputAction:
                TextInputAction.next,
                decoration:
                _inputDecoration(
                  label:
                  'Nama Instruktur',
                  hint: 'Nama guru',
                  icon:
                  Icons.person_outline,
                ),
                validator: (value) {
                  if (value == null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Nama instruktur wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ==================================================
              // KELAS
              // ==================================================

              if (_loadingClasses)
                Container(
                  height: 56,
                  alignment:
                  Alignment.center,
                  decoration:
                  BoxDecoration(
                    color: theme
                        .colorScheme
                        .surfaceContainerHighest
                        .withOpacity(0.35),
                    borderRadius:
                    BorderRadius
                        .circular(
                      14,
                    ),
                  ),
                  child:
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  ),
                )
              else
                DropdownButtonFormField<
                    String>(
                  initialValue:
                  dropdownClassValue,
                  decoration:
                  _dropdownDecoration(
                    label: 'Kelas',
                    icon: Icons
                        .groups_outlined,
                  ),
                  hint: const Text(
                    'Pilih kelas',
                  ),
                  items:
                  _classes.map(
                        (classData) {
                      return DropdownMenuItem<
                          String>(
                        value:
                        classData['id']
                            .toString(),
                        child: Text(
                          classData['name']
                              .toString(),
                        ),
                      );
                    },
                  ).toList(),
                  onChanged:
                  _loading
                      ? null
                      : (value) {
                    if (value ==
                        null) {
                      return;
                    }

                    Map<String,
                        dynamic>?
                    selected;

                    for (final item
                    in _classes) {
                      if (item['id']
                          .toString() ==
                          value) {
                        selected =
                            item;
                        break;
                      }
                    }

                    setState(() {
                      _selectedClassId =
                          value;

                      _selectedClassName =
                          selected?[
                          'name']
                              ?.toString() ??
                              '';
                    });
                  },
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty) {
                      return 'Kelas wajib dipilih';
                    }

                    return null;
                  },
                ),

              const SizedBox(height: 16),

              // ==================================================
              // GAMBAR
              // ==================================================

              TextFormField(
                controller:
                _imageController,
                textInputAction:
                TextInputAction.next,
                decoration:
                _inputDecoration(
                  label:
                  'Path Gambar',
                  hint:
                  'Contoh: assets/images/flutter.png',
                  icon:
                  Icons.image_outlined,
                ),
                validator: (value) {
                  if (value == null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Path gambar wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ==================================================
              // JUMLAH MATERI
              // ==================================================

              TextFormField(
                controller:
                _lessonsController,
                keyboardType:
                TextInputType.number,
                decoration:
                _inputDecoration(
                  label:
                  'Jumlah Materi',
                  hint:
                  'Contoh: 10',
                  icon: Icons
                      .library_books_outlined,
                ),
                validator: (value) {
                  final number =
                  int.tryParse(
                    value?.trim() ?? '',
                  );

                  if (number == null ||
                      number < 0) {
                    return 'Masukkan jumlah materi yang valid';
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
                maxLines: 5,
                decoration:
                _inputDecoration(
                  label:
                  'Deskripsi Course',
                  hint:
                  'Jelaskan materi yang akan dipelajari...',
                  icon: Icons
                      .description_outlined,
                ),
                validator: (value) {
                  if (value == null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Deskripsi course wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 28),

              // ==================================================
              // PEMISAH JADWAL
              // ==================================================

              Text(
                'Jadwal Course',
                style: theme
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                  FontWeight.bold,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                'Jadwal ini akan otomatis digunakan pada Jadwal Mengajar.',
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color: theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // HARI
              // ==================================================

              DropdownButtonFormField<
                  String>(
                initialValue:
                _selectedDay,
                decoration:
                _dropdownDecoration(
                  label: 'Hari',
                  icon: Icons
                      .calendar_today_outlined,
                ),
                hint: const Text(
                  'Pilih hari',
                ),
                items:
                _days.map(
                      (day) {
                    return DropdownMenuItem<
                        String>(
                      value: day,
                      child:
                      Text(day),
                    );
                  },
                ).toList(),
                onChanged:
                _loading
                    ? null
                    : (value) {
                  setState(() {
                    _selectedDay =
                        value;
                  });
                },
                validator: (value) {
                  if (value == null ||
                      value.isEmpty) {
                    return 'Hari wajib dipilih';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // ==================================================
              // JAM MULAI
              // ==================================================

              InkWell(
                onTap:
                _loading
                    ? null
                    : _selectStartTime,
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
                child:
                InputDecorator(
                  decoration:
                  _timeDecoration(
                    label:
                    'Jam Mulai',
                    icon: Icons
                        .access_time_outlined,
                  ),
                  child: Text(
                    _startTime == null
                        ? 'Pilih waktu'
                        : _formatTime(
                      _startTime,
                    ),
                    style: TextStyle(
                      color:
                      _startTime ==
                          null
                          ? theme
                          .colorScheme
                          .onSurfaceVariant
                          : theme
                          .colorScheme
                          .onSurface,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // JAM SELESAI
              // ==================================================

              InkWell(
                onTap:
                _loading
                    ? null
                    : _selectEndTime,
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
                child:
                InputDecorator(
                  decoration:
                  _timeDecoration(
                    label:
                    'Jam Selesai',
                    icon: Icons
                        .access_time_filled_outlined,
                  ),
                  child: Text(
                    _endTime == null
                        ? 'Pilih waktu'
                        : _formatTime(
                      _endTime,
                    ),
                    style: TextStyle(
                      color:
                      _endTime ==
                          null
                          ? theme
                          .colorScheme
                          .onSurfaceVariant
                          : theme
                          .colorScheme
                          .onSurface,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // RUANGAN
              // ==================================================

              TextFormField(
                controller:
                _roomController,
                textInputAction:
                TextInputAction.done,
                decoration:
                _inputDecoration(
                  label: 'Ruangan',
                  hint:
                  'Contoh: Lab RPL',
                  icon: Icons
                      .meeting_room_outlined,
                ),
                validator: (value) {
                  if (value == null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Ruangan wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 28),

              // ==================================================
              // SIMPAN
              // ==================================================

              SizedBox(
                height: 52,
                child:
                FilledButton.icon(
                  onPressed: _loading
                      ? null
                      : _saveCourse,
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
                    widget.isEdit
                        ? Icons
                        .save_outlined
                        : Icons.add,
                  ),
                  label: Text(
                    _loading
                        ? 'Menyimpan...'
                        : widget.isEdit
                        ? 'Simpan Perubahan'
                        : 'Tambah Course',
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // BATAL
              // ==================================================

              SizedBox(
                height: 52,
                child:
                OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () {
                    Navigator.pop(
                      context,
                    );
                  },
                  child: const Text(
                    'Batal',
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}