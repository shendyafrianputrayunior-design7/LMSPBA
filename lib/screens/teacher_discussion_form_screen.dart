import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherDiscussionFormScreen extends StatefulWidget {
  final String? discussionId;
  final Map<String, dynamic>? discussionData;

  const TeacherDiscussionFormScreen({
    super.key,
    this.discussionId,
    this.discussionData,
  });

  @override
  State<TeacherDiscussionFormScreen> createState() =>
      _TeacherDiscussionFormScreenState();
}

class _TeacherDiscussionFormScreenState
    extends State<TeacherDiscussionFormScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _titleController =
  TextEditingController();
  final TextEditingController _contentController =
  TextEditingController();

  bool _loading = false;
  bool _loadingData = true;

  String _teacherName = '';
  String? _teacherDocumentId;
  String? _loadError;

  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _classes = [];

  String? _selectedCourseId;
  String? _selectedCourseName;

  String? _selectedClassId;
  String? _selectedClassName;

  bool get _isEdit =>
      widget.discussionId != null &&
          widget.discussionId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
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

    // 1. Cari users/{uid}.teacherId.
    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data();
      final teacherId = data?['teacherId']?.toString().trim();

      if (teacherId != null && teacherId.isNotEmpty) {
        final teacherDoc = await _firestore
            .collection('teachers')
            .doc(teacherId)
            .get();

        if (teacherDoc.exists) {
          return teacherId;
        }
      }
    } catch (e) {
      debugPrint('ERROR GET TEACHER ID FROM USER: $e');
    }

    // 2. Fallback berdasarkan email akun.
    try {
      final email = user.email?.trim();

      if (email != null && email.isNotEmpty) {
        final result = await _firestore
            .collection('teachers')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (result.docs.isNotEmpty) {
          return result.docs.first.id;
        }
      }
    } catch (e) {
      debugPrint('ERROR GET TEACHER BY EMAIL: $e');
    }

    return null;
  }

  // ============================================================
  // LOAD INITIAL DATA
  // ============================================================

  Future<void> _loadInitialData() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Anda belum login.');
      }

      await _loadTeacherProfile();

      if (_teacherDocumentId == null ||
          _teacherDocumentId!.isEmpty) {
        throw Exception(
          'Data guru tidak ditemukan. '
              'Periksa teacherId pada collection users atau email '
              'pada collection teachers.',
        );
      }

      await _loadCourses();
      await _loadClasses();

      // Data edit dimuat setelah dropdown tersedia.
      if (_isEdit) {
        _loadExistingDiscussion();
      }
    } catch (e) {
      debugPrint('ERROR INITIAL DATA: $e');
      _loadError = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loadingData = false;
        });
      }
    }
  }

  // ============================================================
  // LOAD TEACHER PROFILE
  // ============================================================

  Future<void> _loadTeacherProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();

      if (data != null) {
        _teacherName = (
            data['name'] ??
                data['username'] ??
                data['displayName'] ??
                user.displayName ??
                ''
        ).toString().trim();
      }

      if (_teacherName.isEmpty) {
        _teacherName = user.displayName?.trim() ?? '';
      }

      if (_teacherName.isEmpty && user.email != null) {
        _teacherName = user.email!.split('@').first;
      }

      if (_teacherName.isEmpty) {
        _teacherName = 'Guru';
      }
    } catch (e) {
      debugPrint('ERROR LOAD TEACHER PROFILE: $e');

      _teacherName = user.displayName?.trim() ?? '';

      if (_teacherName.isEmpty) {
        _teacherName = 'Guru';
      }
    }

    _teacherDocumentId = await _getTeacherDocumentId();

    debugPrint('======================================');
    debugPrint('TEACHER PROFILE');
    debugPrint('Teacher Name : $_teacherName');
    debugPrint('Teacher ID   : $_teacherDocumentId');
    debugPrint('======================================');
  }

  // ============================================================
  // LOAD COURSES
  // ============================================================

  Future<void> _loadCourses() async {
    final user = _auth.currentUser;
    final teacherId = _teacherDocumentId;

    if (user == null) {
      return;
    }

    final Map<String, Map<String, dynamic>> courseMap = {};

    void addCourses(
        QuerySnapshot<Map<String, dynamic>> snapshot,
        ) {
      for (final doc in snapshot.docs) {
        final data = doc.data();

        final name = (
            data['name'] ??
                data['title'] ??
                data['courseName'] ??
                data['subject'] ??
                data['nama'] ??
                ''
        ).toString().trim();

        if (name.isEmpty) {
          continue;
        }

        courseMap[doc.id] = {
          'id': doc.id,
          'name': name,
          'teacherId': data['teacherId'],
        };
      }
    }

    // Query menggunakan document ID guru.
    if (teacherId != null && teacherId.isNotEmpty) {
      try {
        debugPrint('QUERY COURSES teacherId = $teacherId');

        final snapshot = await _firestore
            .collection('courses')
            .where('teacherId', isEqualTo: teacherId)
            .get();

        addCourses(snapshot);

        debugPrint(
          'HASIL COURSE TEACHER ID = ${snapshot.docs.length}',
        );
      } catch (e) {
        debugPrint('ERROR COURSE TEACHER ID: $e');
      }
    }

    // Kompatibilitas dengan data lama yang menggunakan UID.
    try {
      debugPrint('QUERY COURSES teacherId = ${user.uid}');

      final snapshot = await _firestore
          .collection('courses')
          .where('teacherId', isEqualTo: user.uid)
          .get();

      addCourses(snapshot);

      debugPrint(
        'HASIL COURSE AUTH UID = ${snapshot.docs.length}',
      );
    } catch (e) {
      debugPrint('ERROR COURSE AUTH UID: $e');
    }

    // Jangan mengambil semua courses sebagai fallback karena dapat
    // menampilkan mata pelajaran milik guru lain.
    _courses = courseMap.values.toList();

    _courses.sort(
          (a, b) => a['name']
          .toString()
          .toLowerCase()
          .compareTo(
        b['name'].toString().toLowerCase(),
      ),
    );

    debugPrint('======================================');
    debugPrint('TOTAL COURSE : ${_courses.length}');

    for (final course in _courses) {
      debugPrint(
        'COURSE: ${course['id']} | ${course['name']}',
      );
    }

    debugPrint('======================================');
  }

  // ============================================================
  // LOAD CLASSES
  // ============================================================

  Future<void> _loadClasses() async {
    try {
      final snapshot =
      await _firestore.collection('classes').get();

      _classes = snapshot.docs.map((doc) {
        final data = doc.data();

        final name = (
            data['name'] ??
                data['className'] ??
                data['nama'] ??
                doc.id
        ).toString().trim();

        return {
          'id': doc.id,
          'name': name,
        };
      }).toList();

      _classes.sort(
            (a, b) => a['name']
            .toString()
            .toLowerCase()
            .compareTo(
          b['name'].toString().toLowerCase(),
        ),
      );

      debugPrint('TOTAL CLASS : ${_classes.length}');
    } catch (e) {
      debugPrint('ERROR LOAD CLASSES: $e');
    }
  }

  // ============================================================
  // LOAD EXISTING DISCUSSION
  // ============================================================

  void _loadExistingDiscussion() {
    final data = widget.discussionData;

    if (data == null) {
      _loadError = 'Data diskusi yang akan diedit tidak tersedia.';
      return;
    }

    _titleController.text = data['title']?.toString() ?? '';
    _contentController.text = data['content']?.toString() ?? '';

    // CLASS ID
    final savedClassId = data['classId']?.toString().trim();

    if (savedClassId != null && savedClassId.isNotEmpty) {
      final index = _classes.indexWhere(
            (item) => item['id'].toString() == savedClassId,
      );

      if (index >= 0) {
        _selectedClassId = savedClassId;
        _selectedClassName =
            _classes[index]['name']?.toString();
      } else {
        // Tetap simpan ID lama agar pengguna mengetahui
        // bahwa kelas tersebut tidak tersedia pada dropdown.
        debugPrint('KELAS LAMA TIDAK DITEMUKAN: $savedClassId');
      }
    }

    // COURSE ID
    final savedCourseId = data['courseId']?.toString().trim();
    final savedCourseName =
    data['courseName']?.toString().trim();
    final savedSubject = data['subject']?.toString().trim();

    if (savedCourseId != null && savedCourseId.isNotEmpty) {
      final index = _courses.indexWhere(
            (item) => item['id'].toString() == savedCourseId,
      );

      if (index >= 0) {
        _selectedCourseId = savedCourseId;
        _selectedCourseName =
            _courses[index]['name']?.toString();
      }
    }

    // FALLBACK BERDASARKAN NAMA MATA PELAJARAN
    final fallbackCourseName =
    savedCourseName?.isNotEmpty == true
        ? savedCourseName
        : savedSubject;

    if ((_selectedCourseId == null ||
        _selectedCourseId!.isEmpty) &&
        fallbackCourseName != null &&
        fallbackCourseName.isNotEmpty) {
      final index = _courses.indexWhere(
            (course) =>
        course['name']
            .toString()
            .toLowerCase() ==
            fallbackCourseName.toLowerCase(),
      );

      if (index >= 0) {
        _selectedCourseId = _courses[index]['id']?.toString();
        _selectedCourseName =
            _courses[index]['name']?.toString();
      }
    }

    debugPrint('EDIT DISCUSSION');
    debugPrint('Course ID   : $_selectedCourseId');
    debugPrint('Course Name : $_selectedCourseName');
    debugPrint('Class ID    : $_selectedClassId');
    debugPrint('Class Name  : $_selectedClassName');
  }

  // ============================================================
  // SAVE DISCUSSION
  // ============================================================

  Future<void> _saveDiscussion() async {
    if (_loading) {
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Anda belum login.', isError: true);
      return;
    }

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // VALIDASI
    if (title.isEmpty) {
      _showMessage(
        'Judul diskusi belum diisi.',
        isError: true,
      );
      return;
    }

    if (content.isEmpty) {
      _showMessage(
        'Isi diskusi belum diisi.',
        isError: true,
      );
      return;
    }

    if (_teacherDocumentId == null ||
        _teacherDocumentId!.isEmpty) {
      _showMessage(
        'Data guru tidak ditemukan. Muat ulang form.',
        isError: true,
      );
      return;
    }

    if (_selectedCourseId == null ||
        _selectedCourseId!.isEmpty ||
        _selectedCourseName == null ||
        _selectedCourseName!.isEmpty) {
      _showMessage(
        'Silakan pilih mata pelajaran.',
        isError: true,
      );
      return;
    }

    if (_selectedClassId == null ||
        _selectedClassId!.isEmpty ||
        _selectedClassName == null ||
        _selectedClassName!.isEmpty) {
      _showMessage(
        'Silakan pilih kelas.',
        isError: true,
      );
      return;
    }

    // Pastikan pilihan masih terdapat pada data yang dimuat.
    final selectedCourseIndex = _courses.indexWhere(
          (course) => course['id'].toString() == _selectedCourseId,
    );

    final selectedClassIndex = _classes.indexWhere(
          (item) => item['id'].toString() == _selectedClassId,
    );

    if (selectedCourseIndex < 0) {
      _showMessage(
        'Mata pelajaran yang dipilih tidak tersedia.',
        isError: true,
      );
      return;
    }

    if (selectedClassIndex < 0) {
      _showMessage(
        'Kelas yang dipilih tidak tersedia.',
        isError: true,
      );
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final teacherId = _teacherDocumentId!;

      final subject =
      _courses[selectedCourseIndex]['name'].toString().trim();

      final className =
      _classes[selectedClassIndex]['name'].toString().trim();

      debugPrint('======================================');
      debugPrint('DEBUG SAVE DISCUSSION');
      debugPrint('UID         : ${user.uid}');
      debugPrint('Teacher ID  : $teacherId');
      debugPrint('Course ID   : $_selectedCourseId');
      debugPrint('Course Name : $subject');
      debugPrint('Class ID    : $_selectedClassId');
      debugPrint('Class Name  : $className');
      debugPrint('Title       : $title');
      debugPrint('Content     : ${content.length} karakter');
      debugPrint('======================================');

      final firestoreData = <String, dynamic>{
        'userId': user.uid,
        'username': _teacherName,
        'title': title,
        'content': content,
        'subject': subject,
        'classId': _selectedClassId,
        'teacherId': teacherId,
        'courseId': _selectedCourseId,
        'courseName': subject,
        'className': className,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!_isEdit) {
        // CREATE
        firestoreData['createdAt'] =
            FieldValue.serverTimestamp();

        final doc = await _firestore
            .collection('discussions')
            .add(firestoreData);

        debugPrint('DISKUSI BERHASIL DITAMBAHKAN');
        debugPrint('DOCUMENT ID: ${doc.id}');
      } else {
        // UPDATE: createdAt tidak diubah.
        final docRef = _firestore
            .collection('discussions')
            .doc(widget.discussionId);

        // Periksa dokumen yang akan diedit dan pastikan dokumen
        // masih tersedia serta dimiliki akun yang sedang login.
        final existingDoc = await docRef.get();

        if (!existingDoc.exists) {
          throw Exception('Data diskusi tidak ditemukan.');
        }

        final existingData = existingDoc.data();

        final existingUserId =
        existingData?['userId']?.toString();

        final existingTeacherId =
        existingData?['teacherId']?.toString();

        final canEdit =
            existingUserId == user.uid ||
                existingTeacherId == teacherId;

        if (!canEdit) {
          throw Exception(
            'Anda tidak memiliki akses untuk mengedit diskusi ini.',
          );
        }

        await docRef.update(firestoreData);

        debugPrint('DISKUSI BERHASIL DIPERBARUI');
        debugPrint('DOCUMENT ID: ${widget.discussionId}');
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        _isEdit
            ? 'Diskusi berhasil diperbarui.'
            : 'Diskusi berhasil ditambahkan.',
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('ERROR SAVE DISCUSSION: $e');

      if (mounted) {
        _showMessage(
          'Gagal menyimpan diskusi: $e',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message, {
        bool isError = false,
      }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : null,
        ),
      );
  }

  // ============================================================
  // COURSE DROPDOWN
  // ============================================================

  Widget _buildCourseDropdown() {
    return DropdownButtonFormField<String>(
      key: ValueKey(
        'course_${_selectedCourseId ?? 'none'}_${_courses.length}',
      ),
      initialValue: _courses.any(
            (course) => course['id'].toString() == _selectedCourseId,
      )
          ? _selectedCourseId
          : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Mata Pelajaran',
        hintText: 'Pilih mata pelajaran',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.menu_book_rounded),
      ),
      items: _courses.map((course) {
        final id = course['id']?.toString() ?? '';
        final name = course['name']?.toString() ?? '';

        return DropdownMenuItem<String>(
          value: id,
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: _loading || _courses.isEmpty
          ? null
          : (value) {
        if (value == null) {
          return;
        }

        final selected = _courses.firstWhere(
              (course) => course['id'].toString() == value,
        );

        setState(() {
          _selectedCourseId = value;
          _selectedCourseName =
              selected['name']?.toString() ?? '';
        });

        debugPrint(
          'COURSE DIPILIH: '
              '$_selectedCourseId | $_selectedCourseName',
        );
      },
    );
  }

  // ============================================================
  // CLASS DROPDOWN
  // ============================================================

  Widget _buildClassDropdown() {
    return DropdownButtonFormField<String>(
      key: ValueKey(
        'class_${_selectedClassId ?? 'none'}_${_classes.length}',
      ),
      initialValue: _classes.any(
            (item) => item['id'].toString() == _selectedClassId,
      )
          ? _selectedClassId
          : null,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Kelas',
        hintText: 'Pilih kelas',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.groups_rounded),
      ),
      items: _classes.map((item) {
        final id = item['id']?.toString() ?? '';
        final name = item['name']?.toString() ?? '';

        return DropdownMenuItem<String>(
          value: id,
          child: Text(
            name,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: _loading || _classes.isEmpty
          ? null
          : (value) {
        if (value == null) {
          return;
        }

        final selected = _classes.firstWhere(
              (item) => item['id'].toString() == value,
        );

        setState(() {
          _selectedClassId = value;
          _selectedClassName =
              selected['name']?.toString() ?? '';
        });

        debugPrint(
          'KELAS DIPILIH: '
              '$_selectedClassId | $_selectedClassName',
        );
      },
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
          _isEdit ? 'Edit Diskusi' : 'Tambah Diskusi',
        ),
      ),
      body: _loadingData
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _loadError != null
          ? SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.red,
                ),
                const SizedBox(height: 12),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _loadingData = true;
                      _loadError = null;
                    });
                    _loadInitialData();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Muat Ulang'),
                ),
              ],
            ),
          ),
        ),
      )
          : SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 700,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.stretch,
                children: [
                  // HEADER
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary
                          .withValues(alpha: 0.08),
                      borderRadius:
                      BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                          theme.colorScheme.primary,
                          child: const Icon(
                            Icons.forum_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isEdit
                                    ? 'Edit Diskusi'
                                    : 'Buat Diskusi Baru',
                                style: theme
                                    .textTheme.titleLarge
                                    ?.copyWith(
                                  fontWeight:
                                  FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Buat diskusi untuk siswa '
                                    'berdasarkan mata pelajaran '
                                    'dan kelas.',
                                style: theme
                                    .textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // GURU
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Guru',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    child: Text(
                      _teacherName.isEmpty
                          ? 'Memuat nama guru...'
                          : _teacherName,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // TEACHER ID
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Teacher ID',
                      border: OutlineInputBorder(),
                      prefixIcon:
                      Icon(Icons.badge_outlined),
                    ),
                    child: Text(
                      _teacherDocumentId ??
                          'Tidak ditemukan',
                    ),
                  ),

                  const SizedBox(height: 16),

                  // JUDUL
                  TextFormField(
                    controller: _titleController,
                    textInputAction:
                    TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Judul Diskusi',
                      hintText: 'Contoh: Flutter',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // MATA PELAJARAN
                  _buildCourseDropdown(),

                  if (_courses.isEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding:
                      const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange
                            .withValues(alpha: 0.10),
                        borderRadius:
                        BorderRadius.circular(10),
                      ),
                      child: const Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Mata pelajaran guru belum '
                                  'ditemukan di collection '
                                  'courses. Pastikan field '
                                  'teacherId sesuai dengan '
                                  'UID atau document ID guru.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // KELAS
                  _buildClassDropdown(),

                  if (_classes.isEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding:
                      const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange
                            .withValues(alpha: 0.10),
                        borderRadius:
                        BorderRadius.circular(10),
                      ),
                      child: const Row(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Data kelas belum ditemukan '
                                  'di collection classes.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // ISI DISKUSI
                  TextFormField(
                    controller: _contentController,
                    minLines: 7,
                    maxLines: 12,
                    textInputAction:
                    TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: 'Isi Diskusi',
                      hintText:
                      'Tuliskan materi atau pertanyaan '
                          'yang ingin didiskusikan...',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(
                          bottom: 110,
                        ),
                        child: Icon(
                          Icons.description_outlined,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // SAVE BUTTON
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _loading
                          ? null
                          : _saveDiscussion,
                      icon: _loading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                        CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Icon(
                        _isEdit
                            ? Icons.save_rounded
                            : Icons
                            .add_comment_rounded,
                      ),
                      label: Text(
                        _loading
                            ? 'Menyimpan...'
                            : _isEdit
                            ? 'Simpan Perubahan'
                            : 'Tambah Diskusi',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Data akan disimpan ke collection discussions.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(
                      color: theme
                          .colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}