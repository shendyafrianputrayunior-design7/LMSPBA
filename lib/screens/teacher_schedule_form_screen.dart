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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

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
  String? _teacherId;

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

  bool get _isEdit => widget.scheduleId != null;

  @override
  void initState() {
    super.initState();

    final data = widget.scheduleData;

    _subjectController = TextEditingController(
      text: (data?['subject'] ?? '').toString(),
    );

    _roomController = TextEditingController(
      text: (data?['room'] ?? '').toString(),
    );

    _selectedCourseId =
    (data?['courseId'] ?? '').toString().isEmpty
        ? null
        : (data?['courseId'] ?? '').toString();

    _selectedCourseName =
    (data?['courseName'] ?? '').toString().isEmpty
        ? null
        : (data?['courseName'] ?? '').toString();

    _selectedClassId =
    (data?['classId'] ?? '').toString().isEmpty
        ? null
        : (data?['classId'] ?? '').toString();

    _selectedClassName =
    (data?['className'] ?? '').toString().isEmpty
        ? null
        : (data?['className'] ?? '').toString();

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

    _loadTeacherProfile();
    _loadCourses();
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

      final teacherId =
      userData?['teacherId']?.toString().trim();

      if (teacherId != null && teacherId.isNotEmpty) {
        return teacherId;
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
        'Error get teacher document ID: $e',
      );
    }

    return null;
  }

  // ============================================================
  // LOAD GURU
  // ============================================================

  Future<void> _loadTeacherProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingTeacher = false;
        });
      }
      return;
    }

    try {
      _teacherId = await _getTeacherDocumentId();

      if (_teacherId != null &&
          _teacherId!.isNotEmpty) {
        final teacherDoc = await _firestore
            .collection('teachers')
            .doc(_teacherId)
            .get();

        if (teacherDoc.exists) {
          final data = teacherDoc.data() ?? {};

          _teacherName = (
              data['name'] ??
                  data['username'] ??
                  data['displayName'] ??
                  user.displayName ??
                  'Guru'
          ).toString();
        }
      }

      // Fallback ke users.
      if (_teacherName == 'Guru' ||
          _teacherName.trim().isEmpty) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data() ?? {};

          _teacherName = (
              data['name'] ??
                  data['username'] ??
                  data['displayName'] ??
                  user.displayName ??
                  'Guru'
          ).toString();
        }
      }
    } catch (e) {
      debugPrint(
        'Error load teacher: $e',
      );

      _teacherName =
          user.displayName ?? 'Guru';
    }

    if (_teacherName.trim().isEmpty) {
      _teacherName = 'Guru';
    }

    if (mounted) {
      setState(() {
        _loadingTeacher = false;
      });
    }
  }

  // ============================================================
  // LOAD COURSE GURU
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
      // JANGAN DIUBAH.
      // Courses saat ini menggunakan Firebase Auth UID
      // dan sudah berjalan dengan benar.
      final snapshot = await _firestore
          .collection('courses')
          .where(
        'teacherId',
        isEqualTo: user.uid,
      )
          .get();

      final loadedCourses =
      snapshot.docs.map((doc) {
        final data = doc.data();

        final courseName = (
            data['title'] ??
                data['courseTitle'] ??
                data['name'] ??
                doc.id
        ).toString();

        return {
          'id': doc.id,
          'name': courseName,
          'classId':
          (data['classId'] ?? '').toString(),
          'className':
          (data['className'] ?? '').toString(),
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _courses = loadedCourses;
        _loadingCourses = false;
      });

      // Jika sedang edit, pulihkan course lama.
      if (_selectedCourseId != null) {
        final matchingCourses = _courses.where(
              (course) =>
          course['id'].toString() ==
              _selectedCourseId,
        );

        if (matchingCourses.isNotEmpty) {
          final course =
              matchingCourses.first;

          setState(() {
            _selectedCourseName =
                course['name'].toString();

            _selectedClassId =
                course['classId'].toString();

            _selectedClassName =
                course['className'].toString();
          });
        }
      }
    } catch (e) {
      debugPrint(
        'Error load courses: $e',
      );

      if (!mounted) return;

      setState(() {
        _loadingCourses = false;
      });

      _showMessage(
        'Gagal mengambil data course.',
      );
    }
  }

  // ============================================================
  // COURSE DIPILIH
  // ============================================================

  void _onCourseChanged(String? courseId) {
    if (courseId == null) return;

    final matchingCourses = _courses.where(
          (course) =>
      course['id'].toString() == courseId,
    );

    if (matchingCourses.isEmpty) {
      return;
    }

    final course = matchingCourses.first;

    setState(() {
      _selectedCourseId =
          course['id'].toString();

      _selectedCourseName =
          course['name'].toString();

      _selectedClassId =
          course['classId'].toString();

      _selectedClassName =
          course['className'].toString();
    });
  }

  // ============================================================
  // TIME HELPER
  // ============================================================

  TimeOfDay? _parseTime(String value) {
    if (value.isEmpty || !value.contains(':')) {
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

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  int _timeToMinutes(TimeOfDay time) {
    return time.hour * 60 + time.minute;
  }

  // ============================================================
  // PICK TIME
  // ============================================================

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
      _selectedStartTime ?? TimeOfDay.now(),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedStartTime = picked;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
      _selectedEndTime ?? TimeOfDay.now(),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedEndTime = picked;
      });
    }
  }

  // ============================================================
  // SAVE
  // ============================================================

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCourseId == null) {
      _showMessage(
        'Silakan pilih course.',
      );
      return;
    }

    if (_selectedClassId == null ||
        _selectedClassId!.isEmpty) {
      _showMessage(
        'Course tersebut belum memiliki kelas.',
      );
      return;
    }

    if (_selectedDay == null) {
      _showMessage(
        'Silakan pilih hari.',
      );
      return;
    }

    if (_selectedStartTime == null) {
      _showMessage(
        'Silakan pilih jam mulai.',
      );
      return;
    }

    if (_selectedEndTime == null) {
      _showMessage(
        'Silakan pilih jam selesai.',
      );
      return;
    }

    final startMinutes =
    _timeToMinutes(
      _selectedStartTime!,
    );

    final endMinutes =
    _timeToMinutes(
      _selectedEndTime!,
    );

    if (endMinutes <= startMinutes) {
      _showMessage(
        'Jam selesai harus lebih besar dari jam mulai.',
      );
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'User belum login.',
      );
      return;
    }

    // ==========================================================
    // RESOLVE TEACHER DOCUMENT ID
    // ==========================================================

    final teacherId =
        _teacherId ?? await _getTeacherDocumentId();

    if (teacherId == null ||
        teacherId.isEmpty) {
      _showMessage(
        'Data guru tidak ditemukan. Pastikan akun guru sudah terhubung dengan data teachers.',
      );
      return;
    }

    if (mounted) {
      setState(() {
        _saving = true;
      });
    }

    try {
      final scheduleData =
      <String, dynamic>{
        // ======================================================
        // INI YANG DIPERBAIKI
        // teacherId = ID dokumen teachers
        // BUKAN Firebase Auth UID
        // ======================================================
        'teacherId': teacherId,

        'teacherName': _teacherName,

        'courseId':
        _selectedCourseId,

        'courseName':
        _selectedCourseName,

        'subject':
        _subjectController.text.trim(),

        // Otomatis dari Course
        'classId':
        _selectedClassId,

        // Otomatis dari Course
        'className':
        _selectedClassName,

        'day':
        _selectedDay,

        'startTime':
        _formatTimeOfDay(
          _selectedStartTime!,
        ),

        'endTime':
        _formatTimeOfDay(
          _selectedEndTime!,
        ),

        'room':
        _roomController.text.trim(),

        'updatedAt':
        FieldValue.serverTimestamp(),
      };

      if (_isEdit) {
        await _firestore
            .collection('schedules')
            .doc(widget.scheduleId)
            .update(scheduleData);
      } else {
        await _firestore
            .collection('schedules')
            .add({
          ...scheduleData,
          'createdAt':
          FieldValue.serverTimestamp(),
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
        _saving = false;
      });

      _showMessage(
        'Gagal menyimpan jadwal: $e',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
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

    if (_selectedCourseId != null &&
        _courses.any(
              (course) =>
          course['id'].toString() ==
              _selectedCourseId,
        )) {
      courseDropdownValue =
          _selectedCourseId;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit
              ? 'Edit Jadwal Mengajar'
              : 'Tambah Jadwal Mengajar',
        ),
      ),
      body: _loadingTeacher ||
          _loadingCourses
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : Form(
        key: _formKey,
        child: ListView(
          padding:
          const EdgeInsets.all(20),
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration:
                  BoxDecoration(
                    color: theme
                        .colorScheme
                        .primary
                        .withValues(
                      alpha: 0.1,
                    ),
                    borderRadius:
                    BorderRadius
                        .circular(14),
                  ),
                  child: Icon(
                    Icons
                        .calendar_month_outlined,
                    color: theme
                        .colorScheme
                        .primary,
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
                        _isEdit
                            ? 'Edit Jadwal Mengajar'
                            : 'Tambah Jadwal Mengajar',
                        style:
                        const TextStyle(
                          fontSize: 21,
                          fontWeight:
                          FontWeight
                              .bold,
                        ),
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        _isEdit
                            ? 'Perbarui informasi jadwal.'
                            : 'Buat jadwal mengajar baru.',
                        style:
                        TextStyle(
                          color: Colors
                              .grey
                              .shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 28,
            ),

            // ==================================================
            // COURSE
            // ==================================================

            DropdownButtonFormField<
                String>(
              initialValue:
              courseDropdownValue,
              decoration:
              const InputDecoration(
                labelText: 'Course',
                hintText:
                'Pilih course',
                prefixIcon: Icon(
                  Icons
                      .menu_book_outlined,
                ),
                border:
                OutlineInputBorder(),
              ),
              items: _courses
                  .map(
                    (course) {
                  return DropdownMenuItem<
                      String>(
                    value: course[
                    'id']
                        .toString(),
                    child: Text(
                      course[
                      'name']
                          .toString(),
                      overflow:
                      TextOverflow
                          .ellipsis,
                    ),
                  );
                },
              )
                  .toList(),
              onChanged: _saving
                  ? null
                  : _onCourseChanged,
              validator: (value) {
                if (value == null ||
                    value.isEmpty) {
                  return 'Course wajib dipilih';
                }

                return null;
              },
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // KELAS OTOMATIS
            // ==================================================

            InputDecorator(
              decoration:
              const InputDecoration(
                labelText: 'Kelas',
                prefixIcon: Icon(
                  Icons
                      .groups_outlined,
                ),
                border:
                OutlineInputBorder(),
              ),
              child: Text(
                _selectedClassName
                    ?.isNotEmpty ==
                    true
                    ? _selectedClassName!
                    : 'Kelas akan mengikuti course',
                style: TextStyle(
                  color: _selectedClassName
                      ?.isNotEmpty ==
                      true
                      ? null
                      : theme
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // SUBJECT
            // ==================================================

            TextFormField(
              controller:
              _subjectController,
              textInputAction:
              TextInputAction.next,
              decoration:
              const InputDecoration(
                labelText:
                'Mata Pelajaran',
                hintText:
                'Contoh: Pemrograman Mobile',
                prefixIcon: Icon(
                  Icons
                      .book_outlined,
                ),
                border:
                OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null ||
                    value
                        .trim()
                        .isEmpty) {
                  return 'Mata pelajaran wajib diisi';
                }

                return null;
              },
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // DAY
            // ==================================================

            DropdownButtonFormField<
                String>(
              initialValue:
              _selectedDay,
              decoration:
              const InputDecoration(
                labelText: 'Hari',
                prefixIcon: Icon(
                  Icons
                      .today_outlined,
                ),
                border:
                OutlineInputBorder(),
              ),
              items: _days.map(
                    (day) {
                  return DropdownMenuItem<
                      String>(
                    value: day,
                    child:
                    Text(day),
                  );
                },
              ).toList(),
              onChanged: _saving
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

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // TIME
            // ==================================================

            Row(
              children: [
                Expanded(
                  child:
                  _buildTimeField(
                    label:
                    'Jam Mulai',
                    time:
                    _selectedStartTime,
                    onTap:
                    _pickStartTime,
                    icon: Icons
                        .access_time_outlined,
                  ),
                ),
                const SizedBox(
                  width: 12,
                ),
                Expanded(
                  child:
                  _buildTimeField(
                    label:
                    'Jam Selesai',
                    time:
                    _selectedEndTime,
                    onTap:
                    _pickEndTime,
                    icon: Icons
                        .access_time_filled,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // ROOM
            // ==================================================

            TextFormField(
              controller:
              _roomController,
              textInputAction:
              TextInputAction.done,
              decoration:
              const InputDecoration(
                labelText:
                'Ruangan',
                hintText:
                'Contoh: Lab Komputer 1',
                prefixIcon: Icon(
                  Icons
                      .meeting_room_outlined,
                ),
                border:
                OutlineInputBorder(),
              ),
            ),

            const SizedBox(
              height: 28,
            ),

            // ==================================================
            // SAVE
            // ==================================================

            SizedBox(
              width:
              double.infinity,
              height: 52,
              child:
              FilledButton.icon(
                onPressed: _saving
                    ? null
                    : _saveSchedule,
                icon: _saving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                    Colors.white,
                  ),
                )
                    : const Icon(
                  Icons
                      .save_outlined,
                ),
                label: Text(
                  _saving
                      ? 'Menyimpan...'
                      : _isEdit
                      ? 'Simpan Perubahan'
                      : 'Simpan Jadwal',
                ),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // ==================================================
            // CANCEL
            // ==================================================

            SizedBox(
              width:
              double.infinity,
              height: 52,
              child:
              OutlinedButton(
                onPressed: _saving
                    ? null
                    : () =>
                    Navigator.pop(
                      context,
                    ),
                child:
                const Text(
                  'Batal',
                ),
              ),
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

    return TextFormField(
      key: ValueKey(
        '$label-$text',
      ),
      readOnly: true,
      controller:
      TextEditingController(
        text: text,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: '08:00',
        prefixIcon: Icon(icon),
        border:
        const OutlineInputBorder(),
      ),
      onTap:
      _saving ? null : onTap,
      validator: (_) {
        if (time == null) {
          return 'Wajib';
        }

        return null;
      },
    );
  }
}