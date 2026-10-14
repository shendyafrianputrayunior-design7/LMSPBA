
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherAnnouncementFormScreen extends StatefulWidget {
  final String? announcementId;
  final Map<String, dynamic>? announcementData;

  const TeacherAnnouncementFormScreen({
    super.key,
    this.announcementId,
    this.announcementData,
  });

  @override
  State<TeacherAnnouncementFormScreen> createState() =>
      _TeacherAnnouncementFormScreenState();
}

class _TeacherAnnouncementFormScreenState
    extends State<TeacherAnnouncementFormScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String? _teacherId;
  String _teacherName = 'Guru';
  String _selectedPriority = 'Normal';

  bool _loadingData = true;
  bool _saving = false;

  bool get _isEdit => widget.announcementId != null;

  // ============================================================
  // COURSE
  // ============================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _courses = [];

  String? _selectedCourseId;
  String? _selectedCourseName;

  // ============================================================
  // CLASS
  // ============================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _classes = [];

  String? _selectedClassId;
  String? _selectedClassName;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // ============================================================
  // LOAD INITIAL DATA
  // ============================================================

  Future<void> _loadInitialData() async {
    final data = widget.announcementData;

    if (data != null) {
      _titleController.text =
          (data['title'] ?? '').toString();

      _contentController.text =
          (data['content'] ?? data['description'] ?? '')
              .toString();

      final courseId = (data['courseId'] ?? '').toString();
      final courseName =
      (data['courseName'] ?? data['courseTitle'] ?? '')
          .toString();

      if (courseId.isNotEmpty) {
        _selectedCourseId = courseId;
      }

      if (courseName.isNotEmpty) {
        _selectedCourseName = courseName;
      }

      final classId = (data['classId'] ?? '').toString();
      final className = (data['className'] ?? '').toString();

      if (classId.isNotEmpty) {
        _selectedClassId = classId;
      }

      if (className.isNotEmpty) {
        _selectedClassName = className;
      }

      final priority = (data['priority'] ?? 'Normal').toString();

      _selectedPriority = const [
        'Rendah',
        'Normal',
        'Tinggi',
      ].contains(priority)
          ? priority
          : 'Normal';
    }

    try {
      // Wajib berurutan. Course bergantung pada ID guru.
      await _loadTeacherProfile();

      if (_teacherId != null) {
        await _loadCoursesAndClasses();
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingData = false;
        });
      }
    }
  }

  // ============================================================
  // RESOLVE TEACHER DOCUMENT ID
  // ============================================================

  Future<String?> _resolveTeacherId(
      User user,
      Map<String, dynamic>? userData,
      ) async {
    // 1. Gunakan teacherDocId dari users/{uid}.
    final teacherDocId = userData?['teacherDocId']?.toString();

    if (teacherDocId != null && teacherDocId.isNotEmpty) {
      final doc = await _firestore
          .collection('teachers')
          .doc(teacherDocId)
          .get();

      if (doc.exists) return doc.id;
    }

    // 2. Fallback ke teacherId dari users/{uid}.
    final teacherId = userData?['teacherId']?.toString();

    if (teacherId != null && teacherId.isNotEmpty) {
      final doc = await _firestore
          .collection('teachers')
          .doc(teacherId)
          .get();

      if (doc.exists) return doc.id;
    }

    // 3. Cari berdasarkan UID.
    final uidQuery = await _firestore
        .collection('teachers')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (uidQuery.docs.isNotEmpty) {
      return uidQuery.docs.first.id;
    }

    // 4. Fallback berdasarkan email.
    // Gunakan fallback ini hanya jika email guru unik di database.
    final email = user.email;

    if (email != null && email.isNotEmpty) {
      final emailQuery = await _firestore
          .collection('teachers')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (emailQuery.docs.isNotEmpty) {
        return emailQuery.docs.first.id;
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
      _showMessage('User belum login.');
      return;
    }

    try {
      final userSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userSnapshot.data();

      final resolvedId = await _resolveTeacherId(user, userData);

      String resolvedName =
          user.displayName ?? 'Guru';

      final userName = userData?['name'] ??
          userData?['username'] ??
          userData?['displayName'];

      if (userName != null &&
          userName.toString().trim().isNotEmpty) {
        resolvedName = userName.toString().trim();
      }

      if (resolvedId != null) {
        final teacherSnapshot = await _firestore
            .collection('teachers')
            .doc(resolvedId)
            .get();

        final teacherData = teacherSnapshot.data();

        final teacherName = teacherData?['name'] ??
            teacherData?['teacherName'] ??
            teacherData?['displayName'];

        if (teacherName != null &&
            teacherName.toString().trim().isNotEmpty) {
          resolvedName = teacherName.toString().trim();
        }
      }

      if (!mounted) return;

      setState(() {
        _teacherId = resolvedId;
        _teacherName =
        resolvedName.trim().isEmpty ? 'Guru' : resolvedName;
      });

      if (resolvedId == null) {
        _showMessage(
          'Data guru tidak ditemukan. Periksa teacherDocId, '
              'teacherId, atau UID pada Firestore.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage('Gagal memuat profil guru: $e');
    }
  }

  // ============================================================
  // LOAD COURSE + CLASS
  // ============================================================

  Future<void> _loadCoursesAndClasses() async {
    final user = _auth.currentUser;
    final teacherId = _teacherId;

    if (user == null || teacherId == null) return;

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
        final dataA = a.data();
        final dataB = b.data();

        final nameA = (dataA['title'] ??
            dataA['courseTitle'] ??
            dataA['courseName'] ??
            dataA['name'] ??
            '')
            .toString()
            .toLowerCase();

        final nameB = (dataB['title'] ??
            dataB['courseTitle'] ??
            dataB['courseName'] ??
            dataB['name'] ??
            '')
            .toString()
            .toLowerCase();

        return nameA.compareTo(nameB);
      });

      classes.sort((a, b) {
        final dataA = a.data();
        final dataB = b.data();

        final nameA =
        (dataA['name'] ?? dataA['className'] ?? a.id)
            .toString()
            .toLowerCase();

        final nameB =
        (dataB['name'] ?? dataB['className'] ?? b.id)
            .toString()
            .toLowerCase();

        return nameA.compareTo(nameB);
      });

      if (!mounted) return;

      setState(() {
        _courses = courses;
        _classes = classes;

        // Sinkronisasi course untuk mode edit.
        final courseExists = courses.any(
              (course) => course.id == _selectedCourseId,
        );

        if (courseExists) {
          final course = courses.firstWhere(
                (item) => item.id == _selectedCourseId,
          );

          _selectedCourseName = _getCourseName(course.data());
        } else {
          _selectedCourseId = null;
          _selectedCourseName = null;
        }

        // Sinkronisasi kelas untuk mode edit.
        final classExists = classes.any(
              (item) => item.id == _selectedClassId,
        );

        if (classExists) {
          final classDoc = classes.firstWhere(
                (item) => item.id == _selectedClassId,
          );

          _selectedClassName = _getClassName(
            classDoc.data(),
            classDoc.id,
          );
        } else {
          _selectedClassId = null;
          _selectedClassName = null;
        }
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage('Gagal mengambil data course/kelas:\n$e');
    }
  }

  // ============================================================
  // NAME HELPERS
  // ============================================================

  String _getCourseName(Map<String, dynamic> data) {
    return (data['title'] ??
        data['courseTitle'] ??
        data['courseName'] ??
        data['name'] ??
        'Tanpa Nama Course')
        .toString();
  }

  String _getClassName(
      Map<String, dynamic> data,
      String documentId,
      ) {
    return (data['name'] ??
        data['className'] ??
        data['title'] ??
        documentId)
        .toString();
  }

  // ============================================================
  // COURSE CHANGED
  // ============================================================

  void _onCourseChanged(String? courseId) {
    if (courseId == null) {
      setState(() {
        _selectedCourseId = null;
        _selectedCourseName = null;
      });
      return;
    }

    final matches = _courses.where(
          (course) => course.id == courseId,
    );

    if (matches.isEmpty) return;

    final course = matches.first;

    setState(() {
      _selectedCourseId = course.id;
      _selectedCourseName = _getCourseName(course.data());
    });
  }

  // ============================================================
  // CLASS CHANGED
  // ============================================================

  void _onClassChanged(String? classId) {
    if (classId == null) {
      setState(() {
        _selectedClassId = null;
        _selectedClassName = null;
      });
      return;
    }

    final matches = _classes.where(
          (item) => item.id == classId,
    );

    if (matches.isEmpty) return;

    final classDoc = matches.first;

    setState(() {
      _selectedClassId = classDoc.id;
      _selectedClassName = _getClassName(
        classDoc.data(),
        classDoc.id,
      );
    });
  }

  // ============================================================
  // SAVE ANNOUNCEMENT
  // ============================================================

  Future<void> _saveAnnouncement() async {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) return;

    final teacherId = _teacherId;
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('User belum login.');
      return;
    }

    if (teacherId == null) {
      _showMessage('ID guru tidak ditemukan.');
      return;
    }

    if (_selectedCourseId == null ||
        _selectedCourseName == null) {
      _showMessage('Silakan pilih course terlebih dahulu.');
      return;
    }

    if (_selectedClassId == null ||
        _selectedClassName == null) {
      _showMessage('Silakan pilih kelas terlebih dahulu.');
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final collection = _firestore.collection('announcements');

      final Map<String, dynamic> announcementData = {
        'teacherId': teacherId,
        'teacherUid': user.uid,
        'teacherName': _teacherName,
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'courseId': _selectedCourseId,
        'courseName': _selectedCourseName,
        'classId': _selectedClassId,
        'className': _selectedClassName,
        'priority': _selectedPriority,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_isEdit) {
        final announcementRef =
        collection.doc(widget.announcementId);

        final existingSnapshot = await announcementRef.get();

        if (!existingSnapshot.exists) {
          throw Exception('Pengumuman tidak ditemukan.');
        }

        final existingData = existingSnapshot.data()!;
        final existingTeacherId =
        existingData['teacherId']?.toString();

        final existingTeacherUid =
        existingData['teacherUid']?.toString();

        // Jangan izinkan pengguna mengubah pengumuman milik guru lain.
        final isOwner = existingTeacherId == teacherId ||
            existingTeacherUid == user.uid ||
            existingTeacherId == user.uid;

        if (!isOwner) {
          throw Exception(
            'Anda tidak memiliki izin mengubah pengumuman ini.',
          );
        }

        await announcementRef.update(announcementData);
      } else {
        await collection.add({
          ...announcementData,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      _showMessage(
        _isEdit
            ? 'Pengumuman berhasil diperbarui.'
            : 'Pengumuman berhasil dibuat.',
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      _showMessage('Gagal menyimpan pengumuman: $e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
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
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
    );
  }

  // ============================================================
  // COURSE DROPDOWN
  // ============================================================

  Widget _buildCourseDropdown() {
    if (_courses.isEmpty) {
      return InputDecorator(
        decoration: _inputDecoration(
          label: 'Course',
          icon: Icons.school_outlined,
        ),
        child: const Text(
          'Belum ada course yang ditugaskan kepada Anda.',
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedCourseId,
      isExpanded: true,
      decoration: _inputDecoration(
        label: 'Course',
        icon: Icons.school_outlined,
      ),
      items: _courses.map((course) {
        return DropdownMenuItem<String>(
          value: course.id,
          child: Text(
            _getCourseName(course.data()),
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
    if (_classes.isEmpty) {
      return InputDecorator(
        decoration: _inputDecoration(
          label: 'Kelas',
          icon: Icons.class_outlined,
        ),
        child: const Text('Belum ada data kelas.'),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: _selectedClassId,
      isExpanded: true,
      decoration: _inputDecoration(
        label: 'Kelas',
        icon: Icons.class_outlined,
      ),
      items: _classes.map((classDoc) {
        return DropdownMenuItem<String>(
          value: classDoc.id,
          child: Text(
            _getClassName(classDoc.data(), classDoc.id),
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
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
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
          _isEdit ? 'Edit Pengumuman' : 'Tambah Pengumuman',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _loadingData
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // HEADER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: Icon(
                      Icons.campaign_outlined,
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEdit
                              ? 'Edit Pengumuman'
                              : 'Pengumuman Baru',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isEdit
                              ? 'Perbarui informasi pengumuman'
                              : 'Buat pengumuman untuk siswa',
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // JUDUL
            TextFormField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                label: 'Judul Pengumuman',
                icon: Icons.title_outlined,
                hint: 'Contoh: Pengumpulan Tugas Flutter',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Judul pengumuman wajib diisi';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // ISI
            TextFormField(
              controller: _contentController,
              minLines: 7,
              maxLines: 12,
              decoration: _inputDecoration(
                label: 'Isi Pengumuman',
                icon: Icons.article_outlined,
                hint: 'Tulis isi pengumuman...',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Isi pengumuman wajib diisi';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // COURSE
            _buildCourseDropdown(),

            const SizedBox(height: 16),

            // KELAS
            _buildClassDropdown(),

            const SizedBox(height: 16),

            // PRIORITAS
            DropdownButtonFormField<String>(
              initialValue: _selectedPriority,
              decoration: _inputDecoration(
                label: 'Prioritas',
                icon: Icons.flag_outlined,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Rendah',
                  child: Text('Rendah'),
                ),
                DropdownMenuItem(
                  value: 'Normal',
                  child: Text('Normal'),
                ),
                DropdownMenuItem(
                  value: 'Tinggi',
                  child: Text('Tinggi'),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                if (value == null) return;
                setState(() {
                  _selectedPriority = value;
                });
              },
            ),

            const SizedBox(height: 28),

            // SIMPAN
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveAnnouncement,
                icon: _saving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
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
                      : 'Simpan Pengumuman',
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
