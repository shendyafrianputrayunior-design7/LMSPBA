import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class AdminClassesScreen extends StatefulWidget {
  const AdminClassesScreen({super.key});

  @override
  State<AdminClassesScreen> createState() => _AdminClassesScreenState();
}

class _AdminClassesScreenState extends State<AdminClassesScreen> {
  final FirestoreService _firestore = FirestoreService.instance;

  // ============================================================
  // TAMBAH / EDIT KELAS
  // ============================================================

  Future<void> _showClassDialog({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    final result = await showDialog<_ClassFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _ClassFormDialog(
          document: document,
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    try {
      if (result.isEdit) {
        await _firestore.updateClass(
          id: result.id!,
          name: result.name,
          major: result.major,
          grade: result.grade,
          school: result.school,
          description: result.description,
        );
      } else {
        await _firestore.addClass(
          name: result.name,
          major: result.major,
          grade: result.grade,
          school: result.school,
          description: result.description,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isEdit
                ? 'Kelas berhasil diperbarui'
                : 'Kelas berhasil ditambahkan',
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
            result.isEdit
                ? 'Gagal memperbarui kelas: $e'
                : 'Gagal menambahkan kelas: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // HAPUS KELAS
  // ============================================================

  Future<void> _deleteClass(
      String id,
      String name,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Hapus Kelas',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Apakah kamu yakin ingin menghapus kelas "$name"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
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
      await _firestore.deleteClass(id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kelas berhasil dihapus'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus kelas: $e'),
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

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: const Text(
          'Kelola Kelas',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      // ========================================================
      // FLOATING ACTION BUTTON
      // ========================================================

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _showClassDialog();
        },
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Tambah Kelas',
        ),
      ),

      // ========================================================
      // DATA KELAS
      // ========================================================

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.getClasses(),
        builder: (
            context,
            snapshot,
            ) {
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
                  'Gagal memuat data kelas.\n\n${snapshot.error}',
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
              return const SizedBox(
                height: 12,
              );
            },
            itemBuilder: (
                context,
                index,
                ) {
              final document = documents[index];
              final data = document.data();

              final name = data['name']?.toString().trim().isNotEmpty == true
                  ? data['name'].toString()
                  : '-';

              final major = data['major']?.toString().trim().isNotEmpty == true
                  ? data['major'].toString()
                  : '-';

              final grade = data['grade']?.toString().trim().isNotEmpty == true
                  ? data['grade'].toString()
                  : '-';

              return _buildClassCard(
                context: context,
                document: document,
                name: name,
                major: major,
                grade: grade,
                theme: theme,
                colorScheme: colorScheme,
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // CLASS CARD
  // ============================================================

  Widget _buildClassCard({
    required BuildContext context,
    required DocumentSnapshot<Map<String, dynamic>> document,
    required String name,
    required String major,
    required String grade,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          // ======================================================
          // ICON
          // ======================================================

          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.class_rounded,
              color: colorScheme.primary,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          // ======================================================
          // DATA
          // ======================================================

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
                const SizedBox(
                  height: 4,
                ),
                Text(
                  '$grade • $major',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // ======================================================
          // EDIT
          // ======================================================

          IconButton(
            tooltip: 'Edit',
            onPressed: () async {
              await _showClassDialog(
                document: document,
              );
            },
            icon: const Icon(
              Icons.edit_outlined,
            ),
          ),

          // ======================================================
          // DELETE
          // ======================================================

          IconButton(
            tooltip: 'Hapus',
            onPressed: () async {
              await _deleteClass(
                document.id,
                name,
              );
            },
            icon: const Icon(
              Icons.delete_outline_rounded,
            ),
          ),
        ],
      ),
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
              Icons.class_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(
              height: 16,
            ),
            const Text(
              'Belum ada data kelas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'Tambahkan kelas menggunakan tombol di bawah.',
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
// HASIL FORM KELAS
// ==================================================================

class _ClassFormResult {
  final String? id;
  final String name;
  final String major;
  final String grade;
  final String school;
  final String description;

  const _ClassFormResult({
    this.id,
    required this.name,
    required this.major,
    required this.grade,
    required this.school,
    required this.description,
  });

  bool get isEdit => id != null;
}

// ==================================================================
// DIALOG FORM KELAS
// ==================================================================

class _ClassFormDialog extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>>? document;

  const _ClassFormDialog({
    this.document,
  });

  @override
  State<_ClassFormDialog> createState() => _ClassFormDialogState();
}

class _ClassFormDialogState extends State<_ClassFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _majorController;
  late final TextEditingController _gradeController;
  late final TextEditingController _schoolController;
  late final TextEditingController _descriptionController;

  bool _saving = false;

  bool get _isEdit => widget.document != null;

  @override
  void initState() {
    super.initState();

    final data = widget.document?.data();

    _nameController = TextEditingController(
      text: data?['name']?.toString() ?? '',
    );

    _majorController = TextEditingController(
      text: data?['major']?.toString() ?? '',
    );

    _gradeController = TextEditingController(
      text: data?['grade']?.toString() ?? '',
    );

    _schoolController = TextEditingController(
      text: data?['school']?.toString() ?? '',
    );

    _descriptionController = TextEditingController(
      text: data?['description']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _majorController.dispose();
    _gradeController.dispose();
    _schoolController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  // ============================================================
  // SIMPAN
  // ============================================================

  void _submit() {
    if (_saving || !mounted) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    Navigator.of(context).pop(
      _ClassFormResult(
        id: widget.document?.id,
        name: _nameController.text.trim(),
        major: _majorController.text.trim(),
        grade: _gradeController.text.trim(),
        school: _schoolController.text.trim(),
        description: _descriptionController.text.trim(),
      ),
    );
  }

  // ============================================================
  // BATAL
  // ============================================================

  void _cancel() {
    if (_saving || !mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  // ============================================================
  // BUILD DIALOG
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEdit ? 'Edit Kelas' : 'Tambah Kelas',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
        ),
      ),

      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ==================================================
                // NAMA KELAS
                // ==================================================

                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Nama Kelas',
                    hintText: 'Contoh: XI RPL 1',
                    prefixIcon: Icon(
                      Icons.class_outlined,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Nama kelas wajib diisi';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 12,
                ),

                // ==================================================
                // JURUSAN
                // ==================================================

                TextFormField(
                  controller: _majorController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Jurusan',
                    hintText: 'Contoh: Rekayasa Perangkat Lunak',
                    prefixIcon: Icon(
                      Icons.school_outlined,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                // ==================================================
                // TINGKAT
                // ==================================================

                TextFormField(
                  controller: _gradeController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Tingkat',
                    hintText: 'Contoh: XI',
                    prefixIcon: Icon(
                      Icons.format_list_numbered_rounded,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                // ==================================================
                // SEKOLAH
                // ==================================================

                TextFormField(
                  controller: _schoolController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Sekolah',
                    hintText: 'Contoh: SMK Negeri 1',
                    prefixIcon: Icon(
                      Icons.account_balance_outlined,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                // ==================================================
                // DESKRIPSI
                // ==================================================

                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    labelText: 'Deskripsi',
                    hintText: 'Deskripsi kelas (opsional)',
                    prefixIcon: Icon(
                      Icons.description_outlined,
                    ),
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      // ============================================================
      // ACTIONS
      // ============================================================

      actions: [
        TextButton(
          onPressed: _cancel,
          child: const Text(
            'Batal',
          ),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
              : Text(
            _isEdit
                ? 'Simpan Perubahan'
                : 'Simpan',
          ),
        ),
      ],
    );
  }
}