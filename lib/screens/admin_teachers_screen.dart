import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class AdminTeachersScreen extends StatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  State<AdminTeachersScreen> createState() => _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends State<AdminTeachersScreen> {
  final FirestoreService _firestore = FirestoreService.instance;

  // ============================================================
  // TAMBAH / EDIT GURU
  // ============================================================

  Future<void> _showTeacherDialog({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    final result = await showDialog<_TeacherFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _TeacherFormDialog(
          document: document,
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    try {
      if (document == null) {
        await _firestore.addTeacher(
          name: result.name,
          subject: result.subject,
          email: result.email,
          nip: result.nip,
        );
      } else {
        await _firestore.updateTeacher(
          id: document.id,
          name: result.name,
          subject: result.subject,
          email: result.email,
          nip: result.nip,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            document == null
                ? 'Guru berhasil ditambahkan'
                : 'Data guru berhasil diperbarui',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan data guru: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // HAPUS GURU
  // ============================================================

  Future<void> _deleteTeacher(
      String id,
      String name,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Hapus Guru'),
          content: Text(
            'Apakah kamu yakin ingin menghapus data guru "$name"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    try {
      await _firestore.deleteTeacher(id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Data guru berhasil dihapus',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus guru: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: const Text(
          'Kelola Guru',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _showTeacherDialog();
        },
        icon: const Icon(
          Icons.person_add_alt_1_rounded,
        ),
        label: const Text(
          'Tambah Guru',
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.getTeachers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat data guru.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final documents = snapshot.data?.docs ?? [];

          if (documents.isEmpty) {
            return _buildEmptyState(
              context,
              colorScheme,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              100,
            ),
            itemCount: documents.length,
            separatorBuilder: (_, __) {
              return const SizedBox(height: 12);
            },
            itemBuilder: (context, index) {
              final document = documents[index];
              final data = document.data();

              final name = data['name']?.toString() ?? '-';
              final subject = data['subject']?.toString() ?? '-';
              final email = data['email']?.toString() ?? '-';
              final nip = data['nip']?.toString() ?? '-';

              return _buildTeacherCard(
                context: context,
                colorScheme: colorScheme,
                document: document,
                name: name,
                subject: subject,
                email: email,
                nip: nip,
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // TEACHER CARD
  // ============================================================

  Widget _buildTeacherCard({
    required BuildContext context,
    required ColorScheme colorScheme,
    required DocumentSnapshot<Map<String, dynamic>> document,
    required String name,
    required String subject,
    required String email,
    required String nip,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.35),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (!mounted) {
                    return;
                  }

                  if (value == 'edit') {
                    await _showTeacherDialog(
                      document: document,
                    );
                  } else if (value == 'delete') {
                    await _deleteTeacher(
                      document.id,
                      name,
                    );
                  }
                },
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 10),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded),
                          SizedBox(width: 10),
                          Text('Hapus'),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: colorScheme.outline.withOpacity(0.20),
          ),
          const SizedBox(height: 14),
          _buildInfoRow(
            context,
            Icons.email_outlined,
            email,
          ),
          const SizedBox(height: 9),
          _buildInfoRow(
            context,
            Icons.badge_outlined,
            'NIP: $nip',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _buildInfoRow(
      BuildContext context,
      IconData icon,
      String text,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState(
      BuildContext context,
      ColorScheme colorScheme,
      ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada data guru',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambahkan data guru menggunakan tombol di bawah.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// HASIL FORM GURU
// ==================================================================

class _TeacherFormResult {
  final String name;
  final String subject;
  final String email;
  final String nip;

  const _TeacherFormResult({
    required this.name,
    required this.subject,
    required this.email,
    required this.nip,
  });
}

// ==================================================================
// DIALOG FORM GURU
// ==================================================================

class _TeacherFormDialog extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>>? document;

  const _TeacherFormDialog({
    required this.document,
  });

  @override
  State<_TeacherFormDialog> createState() => _TeacherFormDialogState();
}

class _TeacherFormDialogState extends State<_TeacherFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _emailController;
  late final TextEditingController _nipController;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _closing = false;

  bool get _isEdit => widget.document != null;

  @override
  void initState() {
    super.initState();

    final data = widget.document?.data();

    _nameController = TextEditingController(
      text: data?['name']?.toString() ?? '',
    );

    _subjectController = TextEditingController(
      text: data?['subject']?.toString() ?? '',
    );

    _emailController = TextEditingController(
      text: data?['email']?.toString() ?? '',
    );

    _nipController = TextEditingController(
      text: data?['nip']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subjectController.dispose();
    _emailController.dispose();
    _nipController.dispose();

    super.dispose();
  }

  void _closeDialog() {
    if (_closing || !mounted) {
      return;
    }

    _closing = true;

    Navigator.of(context).pop();
  }

  void _submit() {
    if (_closing || !mounted) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    _closing = true;

    Navigator.of(context).pop(
      _TeacherFormResult(
        name: _nameController.text.trim(),
        subject: _subjectController.text.trim(),
        email: _emailController.text.trim(),
        nip: _nipController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEdit ? 'Edit Guru' : 'Tambah Guru',
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nama Guru',
                  hintText: 'Contoh: Bapak Andi',
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Nama guru wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _subjectController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Mata Pelajaran',
                  hintText: 'Contoh: Pemrograman Mobile',
                  prefixIcon: Icon(
                    Icons.menu_book_outlined,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Mata pelajaran wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'guru@sekolah.sch.id',
                  prefixIcon: Icon(
                    Icons.email_outlined,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _nipController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'NIP',
                  hintText: 'Nomor Induk Pegawai',
                  prefixIcon: Icon(
                    Icons.badge_outlined,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _closeDialog,
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            _isEdit ? 'Simpan Perubahan' : 'Simpan',
          ),
        ),
      ],
    );
  }
}