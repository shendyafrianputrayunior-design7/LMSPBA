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

  String? _teacherId;
  String? _selectedCourseId;
  Map<String, dynamic>? _selectedCourse;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _courses = [];
  List<Map<String, dynamic>> _students = [];

  final Map<String, TextEditingController> _controllers = {};
  final Set<String> _savingStudents = {};

  bool _loading = true;
  bool _loadingStudents = false;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
    if (mounted) {
      setState(() => _loading = true);
    }

    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Silakan login menggunakan akun guru.');
      }

      final userDoc =
      await _firestore.collection('users').doc(user.uid).get();

      final userData = userDoc.data() ?? {};
      final role =
      (userData['role'] ?? '').toString().trim().toLowerCase();

      if (role.isNotEmpty && role != 'teacher') {
        throw Exception('Halaman ini hanya dapat digunakan oleh guru.');
      }

      // Gunakan teacherId dari dokumen pengguna jika tersedia.
      // Jika tidak tersedia, gunakan UID Firebase pengguna.
      final teacherId =
      (userData['teacherId'] ?? user.uid).toString().trim();

      final courseSnapshot = await _firestore
          .collection('courses')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      if (!mounted) return;

      setState(() {
        _teacherId = teacherId;
        _courses = courseSnapshot.docs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);
      _showMessage('Gagal memuat mata pelajaran: $e');
    }
  }

  Future<void> _selectCourse(
      QueryDocumentSnapshot<Map<String, dynamic>> course,
      ) async {
    _clearControllers();

    setState(() {
      _selectedCourseId = course.id;
      _selectedCourse = course.data();
      _students = [];
      _loadingStudents = true;
    });

    try {
      final courseData = course.data();
      final classId = (courseData['classId'] ?? '').toString().trim();

      if (classId.isEmpty) {
        throw Exception(
          'Mata pelajaran ini belum memiliki classId.',
        );
      }

      // Ambil siswa berdasarkan kelas mata pelajaran.
      final studentSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      final students = studentSnapshot.docs
          .where((doc) {
        final studentClassId =
        (doc.data()['classId'] ?? '').toString().trim();
        return studentClassId == classId;
      })
          .map((doc) => <String, dynamic>{
        ...doc.data(),
        // ID dokumen users harus sama dengan UID Firebase siswa.
        'id': doc.id,
      })
          .toList();

      students.sort((a, b) {
        final nameA =
        (a['name'] ?? a['username'] ?? '').toString().toLowerCase();
        final nameB =
        (b['name'] ?? b['username'] ?? '').toString().toLowerCase();

        return nameA.compareTo(nameB);
      });

      // Muat nilai yang sudah tersimpan untuk mata pelajaran ini.
      final gradeSnapshot = await _firestore
          .collection('student_grades')
          .where('courseId', isEqualTo: course.id)
          .get();

      final gradesByStudent = <String, Map<String, dynamic>>{};

      for (final gradeDoc in gradeSnapshot.docs) {
        final grade = gradeDoc.data();
        final studentId = (grade['studentId'] ?? '').toString();

        if (studentId.isNotEmpty) {
          gradesByStudent[studentId] = grade;
        }
      }

      for (final student in students) {
        final studentId = student['id'].toString();
        final grade = gradesByStudent[studentId];
        final score = grade?['finalScore'];

        _controllers[studentId] = TextEditingController(
          text: score == null ? '' : score.toString(),
        );
      }

      if (!mounted) return;

      setState(() {
        _students = students;
        _loadingStudents = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _loadingStudents = false);
      _showMessage('Gagal memuat data siswa: $e');
    }
  }

  Future<void> _saveGrade(Map<String, dynamic> student) async {
    final courseId = _selectedCourseId;
    final course = _selectedCourse;
    final teacherId = _teacherId;
    final studentId = student['id'].toString();

    if (courseId == null || course == null || teacherId == null) {
      _showMessage('Pilih mata pelajaran terlebih dahulu.');
      return;
    }

    final text = _controllers[studentId]?.text.trim() ?? '';
    final scoreText = text.replaceAll(',', '.');
    final score = num.tryParse(scoreText);

    if (score == null || !score.isFinite || score < 0 || score > 100) {
      _showMessage('Nilai harus berupa angka dari 0 sampai 100.');
      return;
    }

    if (_savingStudents.contains(studentId)) return;

    setState(() => _savingStudents.add(studentId));

    try {
      final studentName =
      (student['name'] ?? student['username'] ?? 'Siswa').toString();

      final courseName = (
          course['title'] ??
              course['courseName'] ??
              course['courseTitle'] ??
              'Mata Pelajaran'
      ).toString();

      // Satu dokumen untuk satu kombinasi course dan siswa.
      final gradeId = '${courseId}_$studentId';
      final gradeRef =
      _firestore.collection('student_grades').doc(gradeId);

      final existingGrade = await gradeRef.get();

      final gradeData = <String, dynamic>{
        'studentId': studentId,
        'studentName': studentName,
        'classId': (course['classId'] ?? '').toString(),
        'courseId': courseId,
        'courseName': courseName,
        'teacherId': teacherId,
        'finalScore': score,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!existingGrade.exists) {
        gradeData['createdAt'] = FieldValue.serverTimestamp();
      }

      await gradeRef.set(
        gradeData,
        SetOptions(merge: true),
      );

      if (!mounted) return;

      _showMessage('Nilai $studentName berhasil disimpan.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Gagal menyimpan nilai: $e');
    } finally {
      if (mounted) {
        setState(() => _savingStudents.remove(studentId));
      }
    }
  }

  void _clearControllers() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }

    _controllers.clear();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
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
        title: const Text('Nilai Akhir Siswa'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _loadCourses,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadCourses,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Pilih Mata Pelajaran',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_courses.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Belum ada mata pelajaran yang terhubung '
                        'dengan akun guru ini.',
                  ),
                ),
              ),
            ..._courses.map((course) {
              final data = course.data();
              final title = (
                  data['title'] ??
                      data['courseName'] ??
                      data['courseTitle'] ??
                      'Mata Pelajaran'
              ).toString();

              final className =
              (data['className'] ?? data['classId'] ?? '-')
                  .toString();

              final selected = _selectedCourseId == course.id;

              return Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.menu_book_outlined),
                  ),
                  title: Text(title),
                  subtitle: Text('Kelas: $className'),
                  trailing: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.chevron_right,
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onTap: () => _selectCourse(course),
                ),
              );
            }),
            if (_selectedCourse != null) ...[
              const SizedBox(height: 24),
              Text(
                'Daftar Nilai — ${_selectedCourse!['title'] ?? _selectedCourse!['courseName'] ?? 'Mata Pelajaran'}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Masukkan nilai akhir setiap siswa dalam rentang 0–100.',
              ),
              const SizedBox(height: 12),
              if (_loadingStudents)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_students.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Belum ada siswa yang terdaftar di kelas ini. '
                          'Pastikan classId pada data siswa dan mata '
                          'pelajaran sama.',
                    ),
                  ),
                )
              else
                ..._students.map((student) {
                  final studentId = student['id'].toString();
                  final name = (
                      student['name'] ??
                          student['username'] ??
                          'Siswa'
                  ).toString();

                  final controller = _controllers[studentId];

                  if (controller == null) {
                    return const SizedBox.shrink();
                  }

                  final saving =
                  _savingStudents.contains(studentId);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  enabled: !saving,
                                  keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Nilai akhir',
                                    hintText: '0–100',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton(
                                onPressed: saving
                                    ? null
                                    : () => _saveGrade(student),
                                child: saving
                                    ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                  CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                    : const Text('Simpan'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }
}