
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../services/account_creation_service.dart';

class AdminTeachersScreen extends StatefulWidget {
  const AdminTeachersScreen({super.key});

  @override
  State<AdminTeachersScreen> createState() =>
      _AdminTeachersScreenState();
}

class _AdminTeachersScreenState extends State<AdminTeachersScreen> {
  final FirestoreService _firestore = FirestoreService.instance;
  final AccountCreationService _accountService =
      AccountCreationService.instance;

  // ============================================================
  // TAMBAH / EDIT GURU
  // ============================================================

  Future<void> _showTeacherDialog({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    final result = await showDialog<_TeacherFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TeacherFormDialog(document: document),
    );

    if (!mounted || result == null) return;

    try {
      if (document == null) {
        await _accountService.createTeacherAccount(
          name: result.name,
          subject: result.subject,
          email: result.email,
          nip: result.nip,
          password: result.password,
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

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            document == null
                ? 'Akun Guru berhasil dibuat'
                : 'Data Guru berhasil diperbarui',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan data Guru: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // ============================================================
  // AKTIFKAN / NONAKTIFKAN GURU
  // ============================================================

  Future<void> _toggleTeacherStatus({
    required DocumentSnapshot<Map<String, dynamic>> document,
    required String name,
    required bool currentlyActive,
  }) async {
    final newStatus = !currentlyActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          newStatus
              ? Icons.check_circle_outline_rounded
              : Icons.block_rounded,
          size: 38,
          color: newStatus ? Colors.green : Colors.orange,
        ),
        title: Text(
          newStatus ? 'Aktifkan Akun Guru' : 'Nonaktifkan Akun Guru',
        ),
        content: Text(
          newStatus
              ? 'Aktifkan kembali akun "$name"?'
              : 'Nonaktifkan akun "$name"? Akses data harus dibatasi '
              'oleh aturan keamanan Firestore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(newStatus ? 'Aktifkan' : 'Nonaktifkan'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      final data = document.data() ?? {};
      final email = (data['email'] ?? '').toString().trim();

      if (email.isEmpty || email == '-') {
        throw Exception('Email guru tidak ditemukan.');
      }

      final db = FirebaseFirestore.instance;

      // Cari profil guru berdasarkan email.
      final userQuery = await db
          .collection('users')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: 'teacher')
          .limit(2)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception(
          'Profil guru tidak ditemukan di koleksi users.',
        );
      }

      if (userQuery.docs.length > 1) {
        throw Exception(
          'Ada lebih dari satu profil guru dengan email ini. '
              'Periksa data users terlebih dahulu.',
        );
      }

      final userDoc = userQuery.docs.first;
      final uid = userDoc.id;

      // Pengaman tambahan untuk akun Bapak Andi yang UID-nya
      // sudah diketahui. Guru lain menggunakan ID dokumen users.
      if (email.toLowerCase() == 'bapakandi@gmail.com' &&
          uid != 'OOIe0HAmR7PZoodZEiHZX43ZpCR2') {
        throw Exception(
          'UID dokumen users tidak cocok dengan UID Bapak Andi. '
              'Periksa Document ID di Firestore.',
        );
      }

      // Jika dokumen users sudah memiliki field uid, nilainya
      // harus konsisten dengan Document ID.
      final storedUid = userDoc.data()['uid']?.toString().trim();
      if (storedUid != null &&
          storedUid.isNotEmpty &&
          storedUid != uid) {
        throw Exception(
          'UID pada profil users tidak cocok dengan Document ID.',
        );
      }

      final teacherRef = db.collection('teachers').doc(document.id);
      final userRef = userDoc.reference;

      final batch = db.batch();
      final timestamp = FieldValue.serverTimestamp();

      // Merge mempertahankan nama, email, NIP, dan mata pelajaran.
      batch.set(
        teacherRef,
        {
          'uid': uid,
          'active': newStatus,
          'updatedAt': timestamp,
        },
        SetOptions(merge: true),
      );

      batch.update(userRef, {
        'active': newStatus,
        'updatedAt': timestamp,
      });

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus
                ? 'Akun "$name" berhasil diaktifkan'
                : 'Akun "$name" berhasil dinonaktifkan',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengubah status akun: $e'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // ============================================================
  // HAPUS DATA GURU
  // ============================================================

  Future<void> _deleteTeacher(
      DocumentSnapshot<Map<String, dynamic>> document,
      String name,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.delete_forever_outlined,
          size: 38,
          color: Colors.red,
        ),
        title: const Text('Hapus Data Guru'),
        content: Text(
          'Apakah kamu yakin ingin menghapus data Guru "$name"?\n\n'
              'Penghapusan ini hanya menghapus profil dari koleksi teachers. '
              'Akun Firebase Authentication dan profil users tidak otomatis '
              'terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus Data'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    try {
      await _firestore.deleteTeacher(document.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Data Guru berhasil dihapus'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus Guru: $e'),
          duration: const Duration(seconds: 5),
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
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTeacherDialog(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Tambah Guru'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.getTeachers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat data Guru.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final documents = snapshot.data?.docs ?? [];

          if (documents.isEmpty) {
            return _buildEmptyState(context, colorScheme);
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            itemCount: documents.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final document = documents[index];
              final data = document.data();

              final name = data['name']?.toString() ?? '-';
              final subject = data['subject']?.toString() ?? '-';
              final email = data['email']?.toString() ?? '-';
              final nip = data['nip']?.toString() ?? '-';
              final isActive = data['active'] != false;

              return _buildTeacherCard(
                context: context,
                colorScheme: colorScheme,
                document: document,
                name: name,
                subject: subject,
                email: email,
                nip: nip,
                isActive: isActive,
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
    required bool isActive,
  }) {
    final theme = Theme.of(context);
    final statusColor = isActive ? Colors.green : Colors.red;

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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  if (value == 'edit') {
                    await _showTeacherDialog(document: document);
                  } else if (value == 'toggle') {
                    await _toggleTeacherStatus(
                      document: document,
                      name: name,
                      currentlyActive: isActive,
                    );
                  } else if (value == 'delete') {
                    await _deleteTeacher(document, name);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
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
                    value: 'toggle',
                    child: Row(
                      children: [
                        Icon(
                          isActive
                              ? Icons.block_rounded
                              : Icons.check_circle_outline_rounded,
                          color: isActive ? Colors.orange : Colors.green,
                        ),
                        const SizedBox(width: 10),
                        Text(isActive ? 'Nonaktifkan' : 'Aktifkan'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red,
                        ),
                        SizedBox(width: 10),
                        Text('Hapus'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isActive
                        ? Icons.check_circle_rounded
                        : Icons.block_rounded,
                    size: 15,
                    color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isActive ? 'Akun Aktif' : 'Akun Nonaktif',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: colorScheme.outline.withOpacity(0.20),
          ),
          const SizedBox(height: 14),
          _buildInfoRow(context, Icons.email_outlined, email),
          const SizedBox(height: 9),
          _buildInfoRow(context, Icons.badge_outlined, 'NIP: $nip'),
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
              'Belum ada data Guru',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambahkan data Guru menggunakan tombol di bawah.',
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

// ============================================================
// HASIL FORM GURU
// ============================================================

class _TeacherFormResult {
  final String name;
  final String subject;
  final String email;
  final String nip;
  final String password;

  const _TeacherFormResult({
    required this.name,
    required this.subject,
    required this.email,
    required this.nip,
    required this.password,
  });
}

// ============================================================
// DIALOG FORM GURU
// ============================================================

class _TeacherFormDialog extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>>? document;

  const _TeacherFormDialog({required this.document});

  @override
  State<_TeacherFormDialog> createState() =>
      _TeacherFormDialogState();
}

class _TeacherFormDialogState extends State<_TeacherFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _emailController;
  late final TextEditingController _nipController;

  final TextEditingController _passwordController =
  TextEditingController();

  bool _obscurePassword = true;
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
    _passwordController.dispose();
    super.dispose();
  }

  void _closeDialog() {
    if (_closing || !mounted) return;

    _closing = true;
    Navigator.of(context).pop();
  }

  void _submit() {
    if (_closing || !mounted) return;
    if (!_formKey.currentState!.validate()) return;

    _closing = true;

    Navigator.of(context).pop(
      _TeacherFormResult(
        name: _nameController.text.trim(),
        subject: _subjectController.text.trim(),
        email: _emailController.text.trim(),
        nip: _nipController.text.trim(),
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Guru' : 'Tambah Akun Guru'),
      content: SizedBox(
        width: 440,
        child: Form(
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
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama Guru wajib diisi';
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
                    prefixIcon: Icon(Icons.menu_book_outlined),
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
                    labelText: 'Email login Guru',
                    hintText: 'guru@sekolah.sch.id',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty || !email.contains('@')) {
                      return 'Masukkan email yang valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nipController,
                  textInputAction: _isEdit
                      ? TextInputAction.done
                      : TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'NIP',
                    hintText: 'Nomor Induk Pegawai',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'NIP wajib diisi';
                    }
                    return null;
                  },
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Password login',
                      helperText: 'Minimal 6 karakter',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.length < 6) {
                        return 'Password minimal 6 karakter';
                      }
                      return null;
                    },
                  ),
                ],
              ],
            ),
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
          child: Text(_isEdit ? 'Simpan Perubahan' : 'Buat Akun'),
        ),
      ],
    );
  }
}
