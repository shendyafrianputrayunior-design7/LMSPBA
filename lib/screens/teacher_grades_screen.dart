import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherGradesScreen extends StatefulWidget {
  const TeacherGradesScreen({super.key});

  @override
  State<TeacherGradesScreen> createState() =>
      _TeacherGradesScreenState();
}

class _TeacherGradesScreenState extends State<TeacherGradesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = true;
  String? _error;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _courses = [];
  List<Map<String, dynamic>> _students = [];

  String? _selectedCourseId;
  String _selectedCourseName = '';
  String _teacherId = '';

  final Map<String, TextEditingController> _scoreControllers = {};
  final Map<String, String> _gradeDocIds = {};

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  // Mengambil profil berdasarkan UID.
  // Jika data profil belum lengkap, coba cari berdasarkan email.
  Future<Map<String, dynamic>> _getTeacherProfile(User user) async {
    final userDoc =
    await _firestore.collection('users').doc(user.uid).get();

    final uidData = userDoc.data() ?? <String, dynamic>{};

    final hasTeacherId = [
      uidData['teacherId'],
      uidData['teacherDocId'],
      uidData['idGuru'],
    ].any((value) =>
    value != null && value.toString().trim().isNotEmpty);

    if (userDoc.exists &&
        uidData['role']?.toString().toLowerCase() == 'teacher' &&
        hasTeacherId) {
      return uidData;
    }

    if (user.email != null && user.email!.trim().isNotEmpty) {
      final emailSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: user.email!.trim())
          .limit(5)
          .get();

      for (final doc in emailSnapshot.docs) {
        final data = doc.data();
        final role =
        (data['role'] ?? '').toString().toLowerCase();

        if (role == 'teacher') {
          final profileHasTeacherId = [
            data['teacherId'],
            data['teacherDocId'],
            data['idGuru'],
          ].any((value) =>
          value != null && value.toString().trim().isNotEmpty);

          if (profileHasTeacherId) {
            return data;
          }
        }
      }
    }

    // Kembalikan profil UID jika tersedia agar permasalahannya
    // tetap dapat diperiksa melalui log.
    return uidData;
  }

  String _resolveTeacherId(
      Map<String, dynamic> userData,
      User user,
      ) {
    for (final key in ['teacherId', 'teacherDocId', 'idGuru']) {
      final value = userData[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return user.uid;
  }

  String _courseName(Map<String, dynamic> data) {
    return (data['title'] ??
        data['courseName'] ??
        data['name'] ??
        'Mata Pelajaran')
        .toString();
  }

  Future<void> _loadCourses() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Silakan login terlebih dahulu.');
      }

      final userData = await _getTeacherProfile(user);
      final role =
      (userData['role'] ?? '').toString().toLowerCase();

      if (role.isNotEmpty && role != 'teacher') {
        throw Exception(
          'Halaman ini hanya dapat diakses oleh guru.',
        );
      }

      _teacherId = _resolveTeacherId(userData, user);

      debugPrint('========== CEK NILAI GURU ==========');
      debugPrint('Auth UID: ${user.uid}');
      debugPrint('Email login: ${user.email}');
      debugPrint('Profil guru: $userData');
      debugPrint('Role: $role');
      debugPrint('Teacher ID: $_teacherId');

      var snapshot = await _firestore
          .collection('courses')
          .where('teacherId', isEqualTo: _teacherId)
          .get();

      // Fallback untuk data lama yang menyimpan UID Firebase
      // sebagai teacherId pada dokumen course.
      if (snapshot.docs.isEmpty && _teacherId != user.uid) {
        snapshot = await _firestore
            .collection('courses')
            .where('teacherId', isEqualTo: user.uid)
            .get();
      }

      debugPrint('Jumlah mata pelajaran: ${snapshot.docs.length}');

      for (final doc in snapshot.docs) {
        debugPrint(
          'Course ID: ${doc.id}, Data: ${doc.data()}',
        );
      }

      if (!mounted) return;

      _clearControllers();

      setState(() {
        _courses = snapshot.docs;
        _students = [];
        _selectedCourseId = null;
        _selectedCourseName = '';
      });

      if (_courses.isNotEmpty) {
        final firstCourse = _courses.first;

        await _selectCourse(
          firstCourse.id,
          _courseName(firstCourse.data()),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('Gagal memuat mata pelajaran: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectCourse(
      String courseId,
      String courseName,
      ) async {
    _clearControllers();

    if (!mounted) return;

    setState(() {
      _selectedCourseId = courseId;
      _selectedCourseName = courseName;
      _students = [];
      _loading = true;
      _error = null;
    });

    try {
      final courseDoc =
      await _firestore.collection('courses').doc(courseId).get();

      if (!courseDoc.exists) {
        throw Exception('Data mata pelajaran tidak ditemukan.');
      }

      final courseData = courseDoc.data() ?? {};
      final classId =
      (courseData['classId'] ?? '').toString().trim();

      if (classId.isEmpty) {
        throw Exception(
          'Kelas pada mata pelajaran ini belum ditentukan.',
        );
      }

      debugPrint('========== DETAIL MATA PELAJARAN ==========');
      debugPrint('Course ID: $courseId');
      debugPrint('Course name: $courseName');
      debugPrint('Class ID: $classId');

      // Ambil akun siswa. Filter kelas dilakukan setelah data diambil
      // agar kompatibel dengan struktur users yang saat ini digunakan.
      final studentsSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      final students = studentsSnapshot.docs
          .where((doc) {
        final data = doc.data();
        return (data['classId'] ?? '').toString().trim() ==
            classId;
      })
          .map((doc) {
        final data = doc.data();

        return <String, dynamic>{
          'id': doc.id,
          'name': (data['name'] ??
              data['fullName'] ??
              data['displayName'] ??
              data['username'] ??
              'Siswa')
              .toString(),
          'nis': (data['nis'] ?? data['nim'] ?? '').toString(),
          'classId': (data['classId'] ?? '').toString(),
        };
      })
          .toList();

      students.sort(
            (a, b) => (a['name'] as String)
            .toLowerCase()
            .compareTo((b['name'] as String).toLowerCase()),
      );

      final gradesSnapshot = await _firestore
          .collection('grades')
          .where('courseId', isEqualTo: courseId)
          .get();

      debugPrint('Jumlah dokumen nilai: ${gradesSnapshot.docs.length}');

      final gradesByStudent = <String, Map<String, dynamic>>{};

      for (final doc in gradesSnapshot.docs) {
        final data = doc.data();
        final studentId = (data['studentId'] ?? '').toString();

        if (studentId.isNotEmpty) {
          gradesByStudent[studentId] = {
            ...data,
            '_docId': doc.id,
          };

          debugPrint(
            'Nilai ditemukan: siswa=$studentId, '
                'score=${data['score']}, '
                'finalScore=${data['finalScore']}',
          );
        }
      }

      for (final student in students) {
        final studentId = student['id'] as String;
        final grade = gradesByStudent[studentId];

        // Mendukung data lama yang menggunakan finalScore.
        final savedScore = grade?['score'] ?? grade?['finalScore'];

        _scoreControllers[studentId] = TextEditingController(
          text: savedScore == null ? '' : savedScore.toString(),
        );

        _gradeDocIds[studentId] =
            (grade?['_docId'] ?? '${courseId}_$studentId').toString();
      }

      debugPrint('Jumlah seluruh akun siswa: ${studentsSnapshot.docs.length}');
      debugPrint('Jumlah siswa pada kelas $classId: ${students.length}');

      if (!mounted) return;

      setState(() {
        _students = students;
      });
    } catch (e, stackTrace) {
      debugPrint('Gagal memuat data nilai: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _saveGrade(Map<String, dynamic> student) async {
    final courseId = _selectedCourseId;

    if (courseId == null) {
      _showMessage('Pilih mata pelajaran terlebih dahulu.');
      return;
    }

    final studentId = student['id'] as String;
    final controller = _scoreControllers[studentId];

    if (controller == null) {
      _showMessage('Kolom nilai siswa tidak ditemukan.');
      return;
    }

    final scoreText = controller.text.trim().replaceAll(',', '.');

    if (scoreText.isEmpty) {
      _showMessage('Nilai tidak boleh kosong.');
      return;
    }

    final score = num.tryParse(scoreText);

    if (score == null ||
        !score.isFinite ||
        score < 0 ||
        score > 100) {
      _showMessage(
        'Nilai harus berupa angka antara 0 sampai 100.',
      );
      return;
    }

    try {
      final user = _auth.currentUser;

      if (user == null) {
        _showMessage(
          'Sesi login berakhir. Silakan login kembali.',
        );
        return;
      }

      final gradeDocId =
          _gradeDocIds[studentId] ?? '${courseId}_$studentId';

      final userData = await _getTeacherProfile(user);
      final teacherId = _resolveTeacherId(userData, user);

      await _firestore.collection('grades').doc(gradeDocId).set({
        'courseId': courseId,
        'courseName': _selectedCourseName,
        'classId': student['classId'] ?? '',
        'studentId': studentId,
        'studentName': student['name'],
        'score': score,
        'finalScore': score,
        'teacherId': teacherId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      _gradeDocIds[studentId] = gradeDocId;

      if (!mounted) return;

      _showMessage('Nilai ${student['name']} berhasil disimpan.');
    } catch (e, stackTrace) {
      debugPrint('Gagal menyimpan nilai: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      _showMessage(
        'Gagal menyimpan nilai: '
            '${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  void _clearControllers() {
    for (final controller in _scoreControllers.values) {
      controller.dispose();
    }

    _scoreControllers.clear();
    _gradeDocIds.clear();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _clearControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Nilai Siswa'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadCourses,
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadCourses,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      )
          : _courses.isEmpty
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada mata pelajaran yang terhubung '
                'dengan akun guru ini.',
            textAlign: TextAlign.center,
          ),
        ),
      )
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              value: _selectedCourseId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Pilih Mata Pelajaran',
                prefixIcon: Icon(
                  Icons.menu_book_outlined,
                ),
                border: OutlineInputBorder(),
              ),
              items: _courses.map((course) {
                final name = _courseName(course.data());

                return DropdownMenuItem<String>(
                  value: course.id,
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: _loading
                  ? null
                  : (courseId) {
                if (courseId == null) return;

                final course = _courses.firstWhere(
                      (item) => item.id == courseId,
                );

                _selectCourse(
                  courseId,
                  _courseName(course.data()),
                );
              },
            ),
          ),
          Expanded(
            child: _students.isEmpty
                ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Belum ada siswa pada kelas '
                      'mata pelajaran ini.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16,
              ),
              itemCount: _students.length,
              itemBuilder: (context, index) {
                final student = _students[index];
                final studentId =
                student['id'] as String;
                final controller =
                _scoreControllers[studentId];

                if (controller == null) {
                  return const SizedBox.shrink();
                }

                final studentName =
                student['name'] as String;
                final nis = student['nis'] as String;

                return Card(
                  margin: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              child: Text(
                                studentName.isNotEmpty
                                    ? studentName[0]
                                    .toUpperCase()
                                    : 'S',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                                children: [
                                  Text(
                                    studentName,
                                    style:
                                    const TextStyle(
                                      fontWeight:
                                      FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (nis.isNotEmpty)
                                    Text(
                                      'NIS/NIM: $nis',
                                      style:
                                      Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                keyboardType:
                                const TextInputType
                                    .numberWithOptions(
                                  decimal: true,
                                ),
                                decoration:
                                const InputDecoration(
                                  labelText: 'Nilai',
                                  hintText: '0–100',
                                  suffixText: '/ 100',
                                  border:
                                  OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _saveGrade(student),
                              icon: const Icon(
                                Icons.check_circle,
                              ),
                              label: const Text('Simpan'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}