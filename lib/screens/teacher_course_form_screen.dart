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
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _instructorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageController = TextEditingController();
  final _lessonsController = TextEditingController();

  bool _loading = false;
  bool _loadingClasses = true;

  List<Map<String, dynamic>> _classes = [];

  String? _selectedClassId;
  String? _selectedClassName;

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

  void _fillExistingData() {
    final data = widget.courseData ?? {};

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

    _selectedClassId =
    (data['classId'] ?? '').toString().isEmpty
        ? null
        : (data['classId'] ?? '').toString();

    _selectedClassName =
    (data['className'] ?? '').toString().isEmpty
        ? null
        : (data['className'] ?? '').toString();
  }

  Future<void> _loadTeacherData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

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

  Future<void> _loadClasses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .get();

      final loadedClasses = snapshot.docs.map((doc) {
        final data = doc.data();

        final className =
        (data['name'] ??
            data['className'] ??
            data['title'] ??
            doc.id)
            .toString();

        return {
          'id': doc.id,
          'name': className,
        };
      }).toList();

      if (!mounted) return;

      setState(() {
        _classes = loadedClasses;
        _loadingClasses = false;
      });

      // Jika sedang edit, cari nama kelas berdasarkan classId.
      if (widget.isEdit &&
          _selectedClassId != null) {
        final selectedClass = _classes.where(
              (item) =>
          item['id'].toString() ==
              _selectedClassId,
        );

        if (selectedClass.isNotEmpty) {
          setState(() {
            _selectedClassName =
                selectedClass.first['name']
                    .toString();
          });
        }
      }
    } catch (e) {
      debugPrint(
        'Gagal mengambil data kelas: $e',
      );

      if (!mounted) return;

      setState(() {
        _loadingClasses = false;
      });

      _showMessage(
        'Gagal mengambil data kelas.',
      );
    }
  }

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

    final user =
        FirebaseAuth.instance.currentUser;

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
      final lessons =
          int.tryParse(
            _lessonsController.text.trim(),
          ) ??
              0;

      final selectedClass =
      _classes.firstWhere(
            (item) =>
        item['id'].toString() ==
            _selectedClassId,
        orElse: () => {
          'id': _selectedClassId,
          'name': _selectedClassName ?? '',
        },
      );

      final courseData = {
        'teacherId': user.uid,

        // Class dipilih dari dropdown
        'classId':
        selectedClass['id'].toString(),
        'className':
        selectedClass['name'].toString(),

        'title':
        _titleController.text.trim(),

        'instructor':
        _instructorController.text.trim(),

        'image':
        _imageController.text.trim(),

        'description':
        _descriptionController.text.trim(),

        'lessons': lessons,

        'updatedAt':
        FieldValue.serverTimestamp(),
      };

      if (widget.isEdit) {
        await FirebaseFirestore.instance
            .collection('courses')
            .doc(widget.courseId)
            .update(courseData);
      } else {
        // ID Course dibuat otomatis oleh Firestore
        await FirebaseFirestore.instance
            .collection('courses')
            .add({
          ...courseData,
          'createdAt':
          FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEdit
                ? 'Course berhasil diperbarui.'
                : 'Course berhasil ditambahkan.',
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    final theme = Theme.of(context);

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
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
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
    final theme = Theme.of(context);

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
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
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

  @override
  void dispose() {
    _titleController.dispose();
    _instructorController.dispose();
    _descriptionController.dispose();
    _imageController.dispose();
    _lessonsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Pastikan value dropdown benar-benar ada
    // di daftar kelas yang sudah dimuat.
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

              // =========================
              // JUDUL COURSE
              // =========================
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
                  icon:
                  Icons.menu_book_outlined,
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Judul course wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // =========================
              // NAMA INSTRUKTUR
              // =========================
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
                      value.trim().isEmpty) {
                    return 'Nama instruktur wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // =========================
              // PILIH KELAS
              // =========================
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
                    BorderRadius.circular(
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
                    icon:
                    Icons.groups_outlined,
                  ),
                  hint: const Text(
                    'Pilih kelas',
                  ),
                  items: _classes.map(
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
                  onChanged: _loading
                      ? null
                      : (value) {
                    if (value ==
                        null) {
                      return;
                    }

                    final selected =
                    _classes
                        .firstWhere(
                          (item) =>
                      item['id']
                          .toString() ==
                          value,
                    );

                    setState(() {
                      _selectedClassId =
                          value;

                      _selectedClassName =
                          selected['name']
                              .toString();
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

              // =========================
              // GAMBAR
              // =========================
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
                      value.trim().isEmpty) {
                    return 'Path gambar wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 16),

              // =========================
              // JUMLAH MATERI
              // =========================
              TextFormField(
                controller:
                _lessonsController,
                keyboardType:
                TextInputType.number,
                decoration:
                _inputDecoration(
                  label:
                  'Jumlah Materi',
                  hint: 'Contoh: 10',
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

              // =========================
              // DESKRIPSI
              // =========================
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
                      value.trim().isEmpty) {
                    return 'Deskripsi course wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 28),

              // =========================
              // SIMPAN
              // =========================
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed:
                  _loading
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

              // =========================
              // BATAL
              // =========================
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () {
                    Navigator.pop(
                      context,
                    );
                  },
                  child:
                  const Text('Batal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}