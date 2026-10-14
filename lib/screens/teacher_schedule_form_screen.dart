import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherScheduleFormScreen extends StatefulWidget {
  final String? scheduleId;
  final Map<String, dynamic>? scheduleData;

  const TeacherScheduleFormScreen({
    super.key,
    this.scheduleId,
    this.scheduleData,
  });

  @override
  State<TeacherScheduleFormScreen> createState() =>
      _TeacherScheduleFormScreenState();
}

class _TeacherScheduleFormScreenState
    extends State<TeacherScheduleFormScreen> {
  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  String? _teacherId;

  // ============================================================
  // FORM
  // ============================================================

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _subjectController;
  late final TextEditingController _roomController;

  final List<String> _days = const [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  String _teacherName = 'Guru';

  String? _selectedDay;

  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;

  String? _selectedCourseId;
  String? _selectedCourseName;

  String? _selectedClassId;
  String? _selectedClassName;

  List<Map<String, dynamic>> _courses = [];

  bool _loadingTeacher = true;
  bool _loadingCourses = true;
  bool _saving = false;
  bool _closing = false;

  bool get _isEdit => widget.scheduleId != null;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    final data = widget.scheduleData;

    _subjectController = TextEditingController(
      text: (
          data?['subject'] ??
              data?['courseTitle'] ??
              data?['courseName'] ??
              ''
      ).toString(),
    );

    _roomController = TextEditingController(
      text: (data?['room'] ?? '').toString(),
    );

    final courseId =
    (data?['courseId'] ?? '').toString().trim();

    final courseName = (
        data?['courseName'] ??
            data?['courseTitle'] ??
            ''
    ).toString().trim();

    final classId =
    (data?['classId'] ?? '').toString().trim();

    final className =
    (data?['className'] ?? '').toString().trim();

    _selectedCourseId =
    courseId.isEmpty ? null : courseId;

    _selectedCourseName =
    courseName.isEmpty ? null : courseName;

    _selectedClassId =
    classId.isEmpty ? null : classId;

    _selectedClassName =
    className.isEmpty ? null : className;

    final day = (data?['day'] ?? '').toString();

    if (day.isNotEmpty && _days.contains(day)) {
      _selectedDay = day;
    }

    _selectedStartTime = _parseTime(
      (data?['startTime'] ?? '').toString(),
    );

    _selectedEndTime = _parseTime(
      (data?['endTime'] ?? '').toString(),
    );

    _initializeForm();
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> _initializeForm() async {
    try {
      await _loadTeacherProfile();

      if (!mounted || _closing) return;

      if (_teacherId == null || _teacherId!.isEmpty) {
        throw Exception(
          'ID guru tidak ditemukan pada profil akun.',
        );
      }

      await _loadCourses();

      if (!mounted || _closing) return;

      if (_isEdit) {
        await _loadScheduleForEdit();
      }
    } catch (e) {
      debugPrint('Gagal menginisialisasi form: $e');

      if (mounted && !_closing) {
        _showMessage('Gagal memuat data: $e');
      }
    } finally {
      if (mounted && !_closing) {
        setState(() {
          _loadingTeacher = false;
          _loadingCourses = false;
        });
      }
    }
  }

  // ============================================================
  // CLOSE
  // ============================================================

  void _closeScreen([dynamic result]) {
    if (!mounted || _closing) return;

    _closing = true;
    Navigator.of(context).pop(result);
  }

  // ============================================================
  // GET TEACHER DOCUMENT ID
  // ============================================================

  Future<String?> _getTeacherDocumentId(User user) async {
    final userDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userDoc.data() ?? {};

    // ID dari AccountCreationService yang sudah ada.
    final possibleIds = [
      userData['teacherDocId']?.toString().trim(),
      userData['teacherId']?.toString().trim(),
    ];

    for (final id in possibleIds) {
      if (id == null || id.isEmpty) continue;

      final teacherDoc = await _firestore
          .collection('teachers')
          .doc(id)
          .get();

      if (!teacherDoc.exists) continue;

      final data = teacherDoc.data() ?? {};
      final storedUid = data['uid']?.toString();

      if (storedUid != null &&
          storedUid.isNotEmpty &&
          storedUid != user.uid) {
        continue;
      }

      return teacherDoc.id;
    }

    // Fallback berdasarkan UID.
    final uidQuery = await _firestore
        .collection('teachers')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (uidQuery.docs.isNotEmpty) {
      return uidQuery.docs.first.id;
    }

    // Fallback untuk data guru lama berdasarkan email.
    final email = user.email?.trim();

    if (email != null && email.isNotEmpty) {
      final emailQuery = await _firestore
          .collection('teachers')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      for (final doc in emailQuery.docs) {
        final storedUid = doc.data()['uid']?.toString();

        if (storedUid == null ||
            storedUid.isEmpty ||
            storedUid == user.uid) {
          return doc.id;
        }
      }
    }

    return null;
  }

  // ============================================================
  // LOAD TEACHER PROFILE
  // ============================================================

  Future<void> _loadTeacherProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('User belum login.');
    }

    final teacherId = await _getTeacherDocumentId(user);

    if (teacherId == null || teacherId.isEmpty) {
      throw Exception(
        'Profil guru tidak ditemukan. Periksa teacherDocId '
            'atau teacherId pada koleksi users.',
      );
    }

    final teacherDoc = await _firestore
        .collection('teachers')
        .doc(teacherId)
        .get();

    if (!teacherDoc.exists) {
      throw Exception('Dokumen guru tidak ditemukan.');
    }

    final teacherData = teacherDoc.data() ?? {};
    final storedUid = teacherData['uid']?.toString();

    if (storedUid != null &&
        storedUid.isNotEmpty &&
        storedUid != user.uid) {
      throw Exception(
        'Profil guru tidak sesuai dengan akun yang login.',
      );
    }

    var name = (
        teacherData['name'] ??
            teacherData['username'] ??
            teacherData['displayName'] ??
            ''
    ).toString().trim();

    if (name.isEmpty) {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      name = (
          userData['name'] ??
              userData['username'] ??
              userData['displayName'] ??
              user.displayName ??
              'Guru'
      ).toString().trim();
    }

    if (!mounted || _closing) return;

    setState(() {
      _teacherId = teacherDoc.id;
      _teacherName = name.isEmpty ? 'Guru' : name;
      _loadingTeacher = false;
    });
  }

  // ============================================================
  // LOAD COURSE GURU
  // ============================================================

  Future<void> _loadCourses() async {
    final teacherId = _teacherId;

    if (_auth.currentUser == null) {
      throw Exception('User belum login.');
    }

    if (teacherId == null || teacherId.isEmpty) {
      throw Exception('ID guru belum tersedia.');
    }

    try {
      final snapshot = await _firestore
          .collection('courses')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      if (!mounted || _closing) return;

      final Map<String, Map<String, dynamic>> uniqueCourses = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final courseName = (
            data['title'] ??
                data['courseTitle'] ??
                data['name'] ??
                doc.id
        ).toString();

        final classId =
        (data['classId'] ?? '').toString().trim();

        final className =
        (data['className'] ?? '').toString().trim();

        uniqueCourses[doc.id] = {
          'id': doc.id,
          'name': courseName,
          'classId': classId,
          'className': className,
        };
      }

      final loadedCourses = uniqueCourses.values.toList();

      loadedCourses.sort(
            (a, b) => a['name']
            .toString()
            .toLowerCase()
            .compareTo(
          b['name'].toString().toLowerCase(),
        ),
      );

      if (!mounted || _closing) return;

      setState(() {
        _courses = loadedCourses;
        _loadingCourses = false;
      });

      // Pulihkan nama course dan kelas ketika edit.
      if (_selectedCourseId != null) {
        Map<String, dynamic>? selectedCourse;

        for (final course in _courses) {
          if (course['id'].toString() == _selectedCourseId) {
            selectedCourse = course;
            break;
          }
        }

        if (selectedCourse != null &&
            mounted &&
            !_closing) {
          final course = selectedCourse;

          final classId = course['classId'].toString();
          final className = course['className'].toString();

          setState(() {
            _selectedCourseName = course['name'].toString();
            _selectedClassId =
            classId.isEmpty ? null : classId;
            _selectedClassName =
            className.isEmpty ? null : className;
          });
        }
      }
    } catch (e) {
      debugPrint('Error load courses: $e');
      rethrow;
    }
  }

  // ============================================================
  // LOAD SCHEDULE FOR EDIT
  // ============================================================

  Future<void> _loadScheduleForEdit() async {
    final scheduleId = widget.scheduleId;
    final teacherId = _teacherId;

    if (scheduleId == null || teacherId == null) return;

    final scheduleDoc = await _firestore
        .collection('schedules')
        .doc(scheduleId)
        .get();

    if (!scheduleDoc.exists) {
      throw Exception('Jadwal yang akan diubah tidak ditemukan.');
    }

    final data = scheduleDoc.data() ?? {};

    if (data['teacherId']?.toString() != teacherId) {
      throw Exception(
        'Anda tidak memiliki izin untuk mengubah jadwal ini.',
      );
    }

    if (!mounted || _closing) return;

    final courseId = (data['courseId'] ?? '').toString();
    final courseName = (
        data['courseName'] ??
            data['courseTitle'] ??
            ''
    ).toString();

    final classId = (data['classId'] ?? '').toString();
    final className = (data['className'] ?? '').toString();

    setState(() {
      _subjectController.text = (
          data['subject'] ??
              data['courseTitle'] ??
              data['courseName'] ??
              ''
      ).toString();

      _roomController.text = (data['room'] ?? '').toString();

      _selectedCourseId =
      courseId.isEmpty ? null : courseId;

      _selectedCourseName =
      courseName.isEmpty ? null : courseName;

      _selectedClassId =
      classId.isEmpty ? null : classId;

      _selectedClassName =
      className.isEmpty ? null : className;

      final day = (data['day'] ?? '').toString();
      _selectedDay = _days.contains(day) ? day : null;

      _selectedStartTime = _parseTime(
        (data['startTime'] ?? '').toString(),
      );

      _selectedEndTime = _parseTime(
        (data['endTime'] ?? '').toString(),
      );
    });
  }

  // ============================================================
  // COURSE CHANGED
  // ============================================================

  void _onCourseChanged(String? courseId) {
    if (courseId == null || !mounted || _closing) return;

    Map<String, dynamic>? selectedCourse;

    for (final course in _courses) {
      if (course['id'].toString() == courseId) {
        selectedCourse = course;
        break;
      }
    }

    if (selectedCourse == null) return;

    final course = selectedCourse;
    final classId = course['classId'].toString();
    final className = course['className'].toString();

    setState(() {
      _selectedCourseId = course['id'].toString();
      _selectedCourseName = course['name'].toString();

      _selectedClassId = classId.isEmpty ? null : classId;
      _selectedClassName = className.isEmpty ? null : className;
    });
  }

  // ============================================================
  // PARSE TIME
  // ============================================================

  TimeOfDay? _parseTime(String value) {
    if (value.isEmpty || !value.contains(':')) {
      return null;
    }

    final parts = value.split(':');

    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) return null;

    if (hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // TIME TO MINUTES
  // ============================================================

  int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  // ============================================================
  // PICK START TIME
  // ============================================================

  Future<void> _pickStartTime() async {
    if (!mounted || _closing || _saving) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedStartTime ??
          const TimeOfDay(hour: 7, minute: 0),
    );

    if (!mounted || _closing) return;

    if (picked != null) {
      setState(() {
        _selectedStartTime = picked;
      });
    }
  }

  // ============================================================
  // PICK END TIME
  // ============================================================

  Future<void> _pickEndTime() async {
    if (!mounted || _closing || _saving) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedEndTime ??
          const TimeOfDay(hour: 8, minute: 0),
    );

    if (!mounted || _closing) return;

    if (picked != null) {
      setState(() {
        _selectedEndTime = picked;
      });
    }
  }

  // ============================================================
  // SAVE SCHEDULE
  // ============================================================

  Future<void> _saveSchedule() async {
    if (!mounted || _closing || _saving) return;

    final form = _formKey.currentState;

    if (form == null || !form.validate()) return;

    final teacherId = _teacherId;

    if (teacherId == null || teacherId.isEmpty) {
      _showMessage('ID guru tidak ditemukan.');
      return;
    }

    if (_selectedCourseId == null ||
        _selectedCourseId!.isEmpty) {
      _showMessage('Silakan pilih course.');
      return;
    }

    if (_selectedClassId == null ||
        _selectedClassId!.isEmpty) {
      _showMessage('Course tersebut belum memiliki kelas.');
      return;
    }

    if (_selectedDay == null || _selectedDay!.isEmpty) {
      _showMessage('Silakan pilih hari.');
      return;
    }

    if (_selectedStartTime == null) {
      _showMessage('Silakan pilih jam mulai.');
      return;
    }

    if (_selectedEndTime == null) {
      _showMessage('Silakan pilih jam selesai.');
      return;
    }

    final startMinutes = _timeToMinutes(_selectedStartTime!);
    final endMinutes = _timeToMinutes(_selectedEndTime!);

    if (endMinutes <= startMinutes) {
      _showMessage(
        'Jam selesai harus lebih besar dari jam mulai.',
      );
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('User belum login.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      // Pastikan course masih tersedia dan milik guru ini.
      final courseDoc = await _firestore
          .collection('courses')
          .doc(_selectedCourseId)
          .get();

      if (!courseDoc.exists) {
        throw Exception('Course tidak ditemukan.');
      }

      final courseData = courseDoc.data() ?? {};

      if (courseData['teacherId']?.toString() != teacherId) {
        throw Exception(
          'Course ini bukan milik guru yang sedang login.',
        );
      }

      // ========================================================
      // DATA SCHEDULE
      // ========================================================

      final scheduleData = <String, dynamic>{
        'teacherId': teacherId,
        'teacherUid': user.uid,
        'teacherName': _teacherName,
        'courseId': _selectedCourseId,
        'courseName': _selectedCourseName,
        'courseTitle': _selectedCourseName,
        'subject': _subjectController.text.trim(),
        'classId': _selectedClassId,
        'className': _selectedClassName,
        'day': _selectedDay,
        'startTime': _formatTimeOfDay(_selectedStartTime!),
        'endTime': _formatTimeOfDay(_selectedEndTime!),
        'room': _roomController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // ========================================================
      // EDIT
      // ========================================================

      if (_isEdit) {
        final scheduleRef = _firestore
            .collection('schedules')
            .doc(widget.scheduleId);

        // Periksa kepemilikan ulang saat menyimpan.
        await _firestore.runTransaction((transaction) async {
          final scheduleDoc = await transaction.get(scheduleRef);

          if (!scheduleDoc.exists) {
            throw Exception('Jadwal tidak ditemukan.');
          }

          final oldData = scheduleDoc.data() ?? {};

          if (oldData['teacherId']?.toString() != teacherId) {
            throw Exception(
              'Anda tidak memiliki izin untuk mengubah jadwal ini.',
            );
          }

          transaction.update(scheduleRef, scheduleData);
        });
      }

      // ========================================================
      // TAMBAH
      // ========================================================

      else {
        await _firestore.collection('schedules').add({
          ...scheduleData,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted || _closing) return;

      _closeScreen(true);
    } catch (e) {
      debugPrint('Gagal menyimpan jadwal: $e');

      if (!mounted || _closing) return;

      setState(() {
        _saving = false;
      });

      _showMessage('Gagal menyimpan jadwal: $e');
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted || _closing) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _closing = true;
    _subjectController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String? courseDropdownValue;

    if (_selectedCourseId != null) {
      final matches = _courses.where(
            (course) =>
        course['id'].toString() == _selectedCourseId,
      );

      if (matches.length == 1) {
        courseDropdownValue = _selectedCourseId;
      }
    }

    return PopScope(
      canPop: !_saving,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_saving) {
          _closeScreen();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEdit
                ? 'Edit Jadwal Mengajar'
                : 'Tambah Jadwal Mengajar',
          ),
          automaticallyImplyLeading: !_saving,
        ),
        body: _loadingTeacher || _loadingCourses
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : _teacherId == null
            ? _buildTeacherError(theme)
            : Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // HEADER
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.calendar_month_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit
                              ? 'Edit Jadwal Mengajar'
                              : 'Tambah Jadwal Mengajar',
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isEdit
                              ? 'Perbarui informasi jadwal.'
                              : 'Buat jadwal mengajar baru.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // COURSE
              DropdownButtonFormField<String>(
                initialValue: courseDropdownValue,
                decoration: const InputDecoration(
                  labelText: 'Course',
                  hintText: 'Pilih course',
                  prefixIcon: Icon(
                    Icons.menu_book_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
                items: _courses.map((course) {
                  return DropdownMenuItem<String>(
                    value: course['id'].toString(),
                    child: Text(
                      course['name'].toString(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: _saving || _courses.isEmpty
                    ? null
                    : _onCourseChanged,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Course wajib dipilih';
                  }
                  return null;
                },
              ),

              if (_courses.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Belum ada course yang terhubung '
                        'dengan akun guru ini.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),

              const SizedBox(height: 16),

              // KELAS
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Kelas',
                  prefixIcon: Icon(
                    Icons.groups_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _selectedClassName?.isNotEmpty == true
                      ? _selectedClassName!
                      : 'Kelas akan mengikuti course',
                  style: TextStyle(
                    color:
                    _selectedClassName?.isNotEmpty == true
                        ? null
                        : theme.colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // SUBJECT
              TextFormField(
                controller: _subjectController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Mata Pelajaran',
                  hintText: 'Contoh: Pemrograman Mobile',
                  prefixIcon: Icon(Icons.book_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Mata pelajaran wajib diisi';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // HARI
              DropdownButtonFormField<String>(
                initialValue: _selectedDay,
                decoration: const InputDecoration(
                  labelText: 'Hari',
                  prefixIcon: Icon(Icons.today_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _days.map((day) {
                  return DropdownMenuItem<String>(
                    value: day,
                    child: Text(day),
                  );
                }).toList(),
                onChanged: _saving
                    ? null
                    : (value) {
                  setState(() {
                    _selectedDay = value;
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Hari wajib dipilih';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // WAKTU
              Row(
                children: [
                  Expanded(
                    child: _buildTimeField(
                      label: 'Jam Mulai',
                      time: _selectedStartTime,
                      onTap: _pickStartTime,
                      icon: Icons.access_time_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTimeField(
                      label: 'Jam Selesai',
                      time: _selectedEndTime,
                      onTap: _pickEndTime,
                      icon: Icons.access_time_filled,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // RUANGAN
              TextFormField(
                controller: _roomController,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Ruangan',
                  hintText: 'Contoh: Lab Komputer 1',
                  prefixIcon: Icon(
                    Icons.meeting_room_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 28),

              // SIMPAN
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed:
                  _saving ? null : _saveSchedule,
                  icon: _saving
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _saving
                        ? 'Menyimpan...'
                        : _isEdit
                        ? 'Simpan Perubahan'
                        : 'Simpan Jadwal',
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // BATAL
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _saving
                      ? null
                      : () => _closeScreen(),
                  child: const Text('Batal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TEACHER ERROR
  // ============================================================

  Widget _buildTeacherError(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 54,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Data Guru Tidak Ditemukan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pastikan profil guru pada users dan teachers '
                  'sudah terhubung dengan benar.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _loadingTeacher = true;
                  _loadingCourses = true;
                });
                _initializeForm();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TIME FIELD
  // ============================================================

  Widget _buildTimeField({
    required String label,
    required TimeOfDay? time,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    final text = time == null
        ? ''
        : _formatTimeOfDay(time);

    return FormField<TimeOfDay>(
      initialValue: time,
      validator: (_) {
        if (time == null) {
          return 'Wajib';
        }
        return null;
      },
      builder: (field) {
        return InkWell(
          onTap: _saving ? null : onTap,
          borderRadius: BorderRadius.circular(4),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              hintText: '08:00',
              prefixIcon: Icon(icon),
              border: const OutlineInputBorder(),
              errorText: field.errorText,
            ),
            child: Text(
              text.isEmpty ? 'Pilih waktu' : text,
              style: TextStyle(
                color: text.isEmpty
                    ? Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    : Theme.of(context)
                    .colorScheme
                    .onSurface,
              ),
            ),
          ),
        );
      },
    );
  }
}