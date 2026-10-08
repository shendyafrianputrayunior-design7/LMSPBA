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

  // ID guru yang digunakan di seluruh sistem teacher
  static const String _teacherId = 'teacher_001';

  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  String _teacherName = 'Guru';

  String _selectedPriority = 'Normal';

  bool _loadingData = true;
  bool _saving = false;

  bool get _isEdit =>
      widget.announcementId != null;

  // ============================================================
  // COURSE
  // ============================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>>
  _courses = [];

  String? _selectedCourseId;
  String? _selectedCourseName;

  // ============================================================
  // CLASS
  // ============================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>>
  _classes = [];

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
          (data['content'] ??
              data['description'] ??
              '')
              .toString();

      // ========================================================
      // COURSE
      // ========================================================

      final oldCourseId =
      (data['courseId'] ?? '').toString();

      final oldCourseName =
      (data['courseName'] ??
          data['courseTitle'] ??
          '')
          .toString();

      if (oldCourseId.isNotEmpty) {
        _selectedCourseId = oldCourseId;
      }

      if (oldCourseName.isNotEmpty) {
        _selectedCourseName = oldCourseName;
      }

      // ========================================================
      // CLASS
      // ========================================================

      final oldClassId =
      (data['classId'] ?? '').toString();

      final oldClassName =
      (data['className'] ?? '').toString();

      if (oldClassId.isNotEmpty) {
        _selectedClassId = oldClassId;
      }

      if (oldClassName.isNotEmpty) {
        _selectedClassName = oldClassName;
      }

      // ========================================================
      // PRIORITY
      // ========================================================

      final priority =
      (data['priority'] ?? 'Normal').toString();

      if ([
        'Rendah',
        'Normal',
        'Tinggi',
      ].contains(priority)) {
        _selectedPriority = priority;
      }
    }

    await Future.wait([
      _loadTeacherProfile(),
      _loadCoursesAndClasses(),
    ]);
  }

  // ============================================================
  // LOAD TEACHER PROFILE
  // ============================================================

  Future<void> _loadTeacherProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _teacherName = 'Guru';
        });
      }

      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      String teacherName =
          user.displayName ?? 'Guru';

      if (snapshot.exists) {
        final data =
            snapshot.data() ?? {};

        teacherName = (
            data['name'] ??
                data['username'] ??
                data['displayName'] ??
                user.displayName ??
                'Guru'
        ).toString();
      }

      if (!mounted) return;

      setState(() {
        _teacherName =
        teacherName.isEmpty
            ? 'Guru'
            : teacherName;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _teacherName =
            user.displayName ?? 'Guru';
      });
    }
  }

  // ============================================================
  // LOAD COURSE + CLASS
  // ============================================================

  Future<void> _loadCoursesAndClasses() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingData = false;
        });
      }

      return;
    }

    try {
      final results = await Future.wait([
        // ======================================================
        // COURSE
        //
        // Gunakan teacherId standar
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
      results[0]
      as QuerySnapshot<
          Map<String, dynamic>>;

      final classSnapshot =
      results[1]
      as QuerySnapshot<
          Map<String, dynamic>>;

      final courses =
      courseSnapshot.docs.toList();

      final classes =
      classSnapshot.docs.toList();

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

      setState(() {
        _courses = courses;
        _classes = classes;
        _loadingData = false;
      });

      // ========================================================
      // SINKRONISASI COURSE SAAT EDIT
      // ========================================================

      if (_selectedCourseId != null) {
        for (final course in courses) {
          if (course.id ==
              _selectedCourseId) {
            final data = course.data();

            if (!mounted) return;

            setState(() {
              _selectedCourseName = (
                  data['title'] ??
                      data['courseTitle'] ??
                      data['name'] ??
                      ''
              ).toString();
            });

            break;
          }
        }
      }

      // ========================================================
      // SINKRONISASI CLASS SAAT EDIT
      // ========================================================

      if (_selectedClassId != null) {
        for (final classDoc in classes) {
          if (classDoc.id ==
              _selectedClassId) {
            final data =
            classDoc.data();

            if (!mounted) return;

            setState(() {
              _selectedClassName = (
                  data['name'] ??
                      data['className'] ??
                      classDoc.id
              ).toString();
            });

            break;
          }
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingData = false;
      });

      _showMessage(
        'Gagal mengambil data course/kelas:\n$e',
      );
    }
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

    QueryDocumentSnapshot<
        Map<String, dynamic>>?
    selectedCourse;

    for (final course in _courses) {
      if (course.id == courseId) {
        selectedCourse = course;
        break;
      }
    }

    if (selectedCourse == null) {
      return;
    }

    final data =
    selectedCourse.data();

    setState(() {
      _selectedCourseId =
          selectedCourse!.id;

      _selectedCourseName = (
          data['title'] ??
              data['courseTitle'] ??
              data['name'] ??
              ''
      ).toString();
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

    QueryDocumentSnapshot<
        Map<String, dynamic>>?
    selectedClass;

    for (final classDoc in _classes) {
      if (classDoc.id == classId) {
        selectedClass = classDoc;
        break;
      }
    }

    if (selectedClass == null) {
      return;
    }

    final data =
    selectedClass.data();

    setState(() {
      _selectedClassId =
          selectedClass!.id;

      _selectedClassName = (
          data['name'] ??
              data['className'] ??
              selectedClass.id
      ).toString();
    });
  }

  // ============================================================
  // SAVE ANNOUNCEMENT
  // ============================================================

  Future<void> _saveAnnouncement() async {
    if (_saving) {
      return;
    }

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
        'User belum login.',
      );

      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final now =
      FieldValue.serverTimestamp();

      final announcementData =
      <String, dynamic>{
        // ======================================================
        // GURU
        // ======================================================

        'teacherId': _teacherId,

        'teacherName':
        _teacherName,

        // ======================================================
        // TITLE + CONTENT
        // ======================================================

        'title':
        _titleController.text.trim(),

        'content':
        _contentController.text.trim(),

        // ======================================================
        // COURSE
        // ======================================================

        'courseId':
        _selectedCourseId,

        'courseName':
        _selectedCourseName ?? '',

        // ======================================================
        // CLASS
        // ======================================================

        'classId':
        _selectedClassId,

        'className':
        _selectedClassName ?? '',

        // ======================================================
        // PRIORITY
        // ======================================================

        'priority':
        _selectedPriority,

        'updatedAt': now,
      };

      // ========================================================
      // EDIT
      // ========================================================

      if (_isEdit) {
        await _firestore
            .collection('announcements')
            .doc(widget.announcementId)
            .update(
          announcementData,
        );
      }

      // ========================================================
      // TAMBAH
      // ========================================================

      else {
        await _firestore
            .collection('announcements')
            .add({
          ...announcementData,
          'createdAt': now,
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
        'Gagal menyimpan pengumuman: $e',
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
        borderRadius:
        BorderRadius.circular(12),
      ),
      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
      ),
      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context)
              .colorScheme
              .primary,
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
          icon:
          Icons.school_outlined,
        ),
        child: const Text(
          'Belum ada course yang ditugaskan kepada Anda.',
        ),
      );
    }

    return DropdownButtonFormField<
        String>(
      initialValue:
      _selectedCourseId,
      isExpanded: true,
      decoration: _inputDecoration(
        label: 'Course',
        icon:
        Icons.school_outlined,
      ),
      items: _courses.map((course) {
        final data =
        course.data();

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
            overflow:
            TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged:
      _saving
          ? null
          : _onCourseChanged,
      validator: (value) {
        if (value == null ||
            value.isEmpty) {
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
          icon:
          Icons.class_outlined,
        ),
        child: const Text(
          'Belum ada data kelas.',
        ),
      );
    }

    return DropdownButtonFormField<
        String>(
      initialValue:
      _selectedClassId,
      isExpanded: true,
      decoration: _inputDecoration(
        label: 'Kelas',
        icon:
        Icons.class_outlined,
      ),
      items: _classes.map((classDoc) {
        final data =
        classDoc.data();

        final name = (
            data['name'] ??
                data['className'] ??
                classDoc.id
        ).toString();

        return DropdownMenuItem<String>(
          value: classDoc.id,
          child: Text(
            name,
            overflow:
            TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged:
      _saving
          ? null
          : _onClassChanged,
      validator: (value) {
        if (value == null ||
            value.isEmpty) {
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
    final theme =
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEdit
              ? 'Edit Pengumuman'
              : 'Tambah Pengumuman',
          style:
          const TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ),
      body: _loadingData
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : Form(
        key: _formKey,
        child: ListView(
          padding:
          const EdgeInsets.all(16),
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Container(
              padding:
              const EdgeInsets.all(16),
              decoration:
              BoxDecoration(
                color: theme
                    .colorScheme
                    .primaryContainer,
                borderRadius:
                BorderRadius
                    .circular(
                  16,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                    theme
                        .colorScheme
                        .primary,
                    child: Icon(
                      Icons
                          .campaign_outlined,
                      color: theme
                          .colorScheme
                          .onPrimary,
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
                              ? 'Edit Pengumuman'
                              : 'Pengumuman Baru',
                          style:
                          const TextStyle(
                            fontSize: 17,
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
                              ? 'Perbarui informasi pengumuman'
                              : 'Buat pengumuman untuk siswa',
                          style:
                          TextStyle(
                            fontSize: 13,
                            color: theme
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // ==================================================
            // JUDUL
            // ==================================================

            TextFormField(
              controller:
              _titleController,
              textInputAction:
              TextInputAction.next,
              decoration:
              _inputDecoration(
                label:
                'Judul Pengumuman',
                icon: Icons
                    .title_outlined,
                hint:
                'Contoh: Pengumpulan Tugas Flutter',
              ),
              validator:
                  (value) {
                if (value == null ||
                    value
                        .trim()
                        .isEmpty) {
                  return 'Judul pengumuman wajib diisi';
                }

                return null;
              },
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // ISI
            // ==================================================

            TextFormField(
              controller:
              _contentController,
              minLines: 7,
              maxLines: 12,
              decoration:
              _inputDecoration(
                label:
                'Isi Pengumuman',
                icon: Icons
                    .article_outlined,
                hint:
                'Tulis isi pengumuman...',
              ),
              validator:
                  (value) {
                if (value == null ||
                    value
                        .trim()
                        .isEmpty) {
                  return 'Isi pengumuman wajib diisi';
                }

                return null;
              },
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // COURSE
            // ==================================================

            _buildCourseDropdown(),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // CLASS
            // ==================================================

            _buildClassDropdown(),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // PRIORITY
            // ==================================================

            DropdownButtonFormField<
                String>(
              initialValue:
              _selectedPriority,
              decoration:
              _inputDecoration(
                label:
                'Prioritas',
                icon: Icons
                    .flag_outlined,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'Rendah',
                  child:
                  Text('Rendah'),
                ),
                DropdownMenuItem(
                  value: 'Normal',
                  child:
                  Text('Normal'),
                ),
                DropdownMenuItem(
                  value: 'Tinggi',
                  child:
                  Text('Tinggi'),
                ),
              ],
              onChanged:
              _saving
                  ? null
                  : (value) {
                if (value ==
                    null) {
                  return;
                }

                setState(() {
                  _selectedPriority =
                      value;
                });
              },
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
                onPressed:
                _saving
                    ? null
                    : _saveAnnouncement,
                icon: _saving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth:
                    2,
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
                      : 'Simpan Pengumuman',
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),
          ],
        ),
      ),
    );
  }
}