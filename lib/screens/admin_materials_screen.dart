import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class AdminMaterialsScreen extends StatefulWidget {
  const AdminMaterialsScreen({super.key});

  @override
  State<AdminMaterialsScreen> createState() =>
      _AdminMaterialsScreenState();
}

class _AdminMaterialsScreenState
    extends State<AdminMaterialsScreen> {
  final FirestoreService _firestore =
      FirestoreService.instance;

  // ============================================================
  // TAMBAH / EDIT MATERI
  // ============================================================

  Future<void> _showMaterialDialog({
    String? id,
    Map<String, dynamic>? material,
  }) async {
    final result = await showDialog<_MaterialFormResult>(
      context: context,
      builder: (dialogContext) {
        return _MaterialFormDialog(
          id: id,
          material: material,
        );
      },
    );

    if (result == null) return;
    if (!mounted) return;

    try {
      // ========================================================
      // EDIT
      // ========================================================

      if (result.id != null) {
        await _firestore.updateMaterial(
          id: result.id!,
          classId: result.classId,
          teacherId: 'teacher_001',
          subject: result.subject,
          title: result.title,
          description: result.description,
          type: result.type,
          fileUrl: result.fileUrl,
        );
      }

      // ========================================================
      // TAMBAH
      // ========================================================

      else {
        await _firestore.addMaterial(
          classId: result.classId,
          teacherId: 'teacher_001',
          subject: result.subject,
          title: result.title,
          description: result.description,
          type: result.type,
          fileUrl: result.fileUrl,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.id != null
                ? 'Materi berhasil diperbarui'
                : 'Materi berhasil ditambahkan',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan materi: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // HAPUS MATERI
  // ============================================================

  Future<void> _deleteMaterial(
      String id,
      String title,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Materi'),
          content: Text(
            'Apakah kamu yakin ingin menghapus '
                '"$title"?',
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

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await _firestore.deleteMaterial(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Materi berhasil dihapus',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus materi: $e',
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
      backgroundColor:
      theme.scaffoldBackgroundColor,

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
        theme.scaffoldBackgroundColor,
        title: const Text(
          'Kelola Materi',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: () {
          _showMaterialDialog();
        },
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Tambah Materi',
        ),
      ),

      body: StreamBuilder(
        stream: _firestore.getMaterials(),
        builder: (
            context,
            snapshot,
            ) {
          // ======================================================
          // LOADING
          // ======================================================

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // ======================================================
          // ERROR
          // ======================================================

          if (snapshot.hasError) {
            return _buildErrorState(
              context,
              snapshot.error.toString(),
            );
          }

          // ======================================================
          // DATA
          // ======================================================

          final materials =
              snapshot.data?.docs ?? [];

          if (materials.isEmpty) {
            return _buildEmptyState(
              context,
              colorScheme,
            );
          }

          // ======================================================
          // LIST
          // ======================================================

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              100,
            ),
            itemCount: materials.length,
            separatorBuilder: (_, __) {
              return const SizedBox(
                height: 12,
              );
            },
            itemBuilder: (
                context,
                index,
                ) {
              final document =
              materials[index];

              final data = document.data();

              return _buildMaterialCard(
                context,
                document.id,
                data,
                colorScheme,
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // MATERIAL CARD
  // ============================================================

  Widget _buildMaterialCard(
      BuildContext context,
      String id,
      Map<String, dynamic> material,
      ColorScheme colorScheme,
      ) {
    final theme = Theme.of(context);

    final title =
        material['title']?.toString() ?? '-';

    final subject =
        material['subject']?.toString() ?? '-';

    final classId =
        material['classId']?.toString() ?? '-';

    final type =
        material['type']?.toString() ?? '-';

    final description =
        material['description']?.toString() ?? '-';

    final fileUrl =
        material['fileUrl']?.toString() ?? '';

    // ==========================================================
    // ICON BERDASARKAN JENIS
    // ==========================================================

    IconData typeIcon;

    switch (type) {
      case 'Video':
        typeIcon =
            Icons.play_circle_outline_rounded;
        break;

      case 'Dokumen':
        typeIcon =
            Icons.description_outlined;
        break;

      case 'Link':
        typeIcon =
            Icons.link_rounded;
        break;

      default:
        typeIcon =
            Icons.picture_as_pdf_outlined;
    }

    // ==========================================================
    // NAMA KELAS
    // ==========================================================

    String className;

    switch (classId) {
      case 'X_RPL_1':
        className = 'X RPL 1';
        break;

      case 'XI_RPL_1':
        className = 'XI RPL 1';
        break;

      case 'XI_RPL_2':
        className = 'XI RPL 2';
        break;

      case 'XII_RPL_1':
        className = 'XII RPL 1';
        break;

      default:
        className = classId;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outline
              .withOpacity(0.35),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colorScheme.primary
                      .withOpacity(0.10),
                  borderRadius:
                  BorderRadius.circular(16),
                ),
                child: Icon(
                  typeIcon,
                  color:
                  colorScheme.primary,
                  size: 28,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      subject,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        color:
                        colorScheme.primary,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // ==================================================
              // MENU
              // ==================================================

              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showMaterialDialog(
                      id: id,
                      material: material,
                    );
                  } else if (value == 'delete') {
                    _deleteMaterial(
                      id,
                      title,
                    );
                  }
                },
                itemBuilder: (context) {
                  return const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit_outlined,
                          ),
                          SizedBox(width: 10),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .delete_outline_rounded,
                          ),
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
            color: colorScheme.outline
                .withOpacity(0.20),
          ),

          const SizedBox(height: 14),

          // ==========================================================
          // TAG
          // ==========================================================

          Row(
            children: [
              _buildTag(
                context,
                Icons.class_outlined,
                className,
              ),

              const SizedBox(width: 8),

              _buildTag(
                context,
                Icons.attach_file_rounded,
                type,
              ),
            ],
          ),

          // ==========================================================
          // DESKRIPSI
          // ==========================================================

          const SizedBox(height: 12),

          Align(
            alignment:
            Alignment.centerLeft,
            child: Text(
              description,
              maxLines: 3,
              overflow:
              TextOverflow.ellipsis,
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: colorScheme
                    .onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),

          // ==========================================================
          // URL
          // ==========================================================

          if (fileUrl.isNotEmpty &&
              fileUrl != '-') ...[
            const SizedBox(height: 10),

            Align(
              alignment:
              Alignment.centerLeft,
              child: Text(
                fileUrl,
                maxLines: 2,
                overflow:
                TextOverflow.ellipsis,
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  color:
                  colorScheme.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // TAG
  // ============================================================

  Widget _buildTag(
      BuildContext context,
      IconData icon,
      String text,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: colorScheme.primary
            .withOpacity(0.08),
        borderRadius:
        BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color:
            colorScheme.primary,
          ),

          const SizedBox(width: 5),

          Text(
            text,
            style: theme
                .textTheme
                .labelSmall
                ?.copyWith(
              color:
              colorScheme.primary,
              fontWeight:
              FontWeight.w600,
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
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 64,
              color: colorScheme
                  .onSurfaceVariant,
            ),

            const SizedBox(height: 16),

            const Text(
              'Belum ada materi',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Tambahkan materi pembelajaran '
                  'menggunakan tombol di bawah.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color: colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState(
      BuildContext context,
      String error,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
          MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 60,
              color:
              colorScheme.error,
            ),

            const SizedBox(height: 16),

            Text(
              'Gagal memuat materi',
              style: theme
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight:
                FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              error,
              textAlign:
              TextAlign.center,
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 16),

            FilledButton.icon(
              onPressed: () {
                setState(() {});
              },
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label:
              const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// FORM RESULT
// ================================================================

class _MaterialFormResult {
  final String? id;
  final String title;
  final String subject;
  final String classId;
  final String type;
  final String fileUrl;
  final String description;

  const _MaterialFormResult({
    this.id,
    required this.title,
    required this.subject,
    required this.classId,
    required this.type,
    required this.fileUrl,
    required this.description,
  });
}

// ================================================================
// MATERIAL FORM DIALOG
// ================================================================

class _MaterialFormDialog extends StatefulWidget {
  final String? id;
  final Map<String, dynamic>? material;

  const _MaterialFormDialog({
    this.id,
    this.material,
  });

  @override
  State<_MaterialFormDialog> createState() =>
      _MaterialFormDialogState();
}

class _MaterialFormDialogState
    extends State<_MaterialFormDialog> {
  final _formKey =
  GlobalKey<FormState>();

  late final TextEditingController
  _titleController;

  late final TextEditingController
  _subjectController;

  late final TextEditingController
  _descriptionController;

  late final TextEditingController
  _fileUrlController;

  static const classIds = [
    'X_RPL_1',
    'XI_RPL_1',
    'XI_RPL_2',
    'XII_RPL_1',
  ];

  static const materialTypes = [
    'PDF',
    'Video',
    'Dokumen',
    'Link',
  ];

  late String selectedClass;
  late String selectedType;

  bool _saving = false;

  bool get isEdit => widget.id != null;

  @override
  void initState() {
    super.initState();

    final material = widget.material;

    _titleController =
        TextEditingController(
          text:
          material?['title']?.toString() ??
              '',
        );

    _subjectController =
        TextEditingController(
          text:
          material?['subject']?.toString() ??
              '',
        );

    _descriptionController =
        TextEditingController(
          text:
          material?['description']
              ?.toString() ??
              '',
        );

    _fileUrlController =
        TextEditingController(
          text:
          material?['fileUrl']?.toString() ??
              '',
        );

    final savedClass =
    material?['classId']
        ?.toString()
        .trim();

    selectedClass =
    classIds.contains(savedClass)
        ? savedClass!
        : 'XI_RPL_1';

    final savedType =
    material?['type']
        ?.toString()
        .trim();

    selectedType =
    materialTypes.contains(savedType)
        ? savedType!
        : 'PDF';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _descriptionController.dispose();
    _fileUrlController.dispose();

    super.dispose();
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  void _submit() {
    if (_saving) return;

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
    });

    final result = _MaterialFormResult(
      id: widget.id,
      title:
      _titleController.text.trim(),
      subject:
      _subjectController.text.trim(),
      classId: selectedClass,
      type: selectedType,
      fileUrl:
      _fileUrlController.text.trim(),
      description:
      _descriptionController.text.trim(),
    );

    // Dialog hanya mengembalikan data.
    // Firestore diproses oleh parent setelah dialog tertutup.
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        isEdit
            ? 'Edit Materi'
            : 'Tambah Materi',
      ),

      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize:
            MainAxisSize.min,
            children: [
              // ==================================================
              // JUDUL
              // ==================================================

              TextFormField(
                controller:
                _titleController,
                decoration:
                const InputDecoration(
                  labelText:
                  'Judul Materi',
                  hintText:
                  'Contoh: Pengenalan Flutter',
                  prefixIcon: Icon(
                    Icons.title_rounded,
                  ),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Judul materi wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              // ==================================================
              // MATA PELAJARAN
              // ==================================================

              TextFormField(
                controller:
                _subjectController,
                decoration:
                const InputDecoration(
                  labelText:
                  'Mata Pelajaran',
                  hintText:
                  'Contoh: Pemrograman Mobile',
                  prefixIcon: Icon(
                    Icons.menu_book_outlined,
                  ),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Mata pelajaran wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              // ==================================================
              // KELAS
              // ==================================================

              DropdownButtonFormField<String>(
                initialValue:
                selectedClass,
                decoration:
                const InputDecoration(
                  labelText: 'Kelas',
                  prefixIcon: Icon(
                    Icons.class_outlined,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'X_RPL_1',
                    child: Text(
                      'X RPL 1',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'XI_RPL_1',
                    child: Text(
                      'XI RPL 1',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'XI_RPL_2',
                    child: Text(
                      'XI RPL 2',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'XII_RPL_1',
                    child: Text(
                      'XII RPL 1',
                    ),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    selectedClass =
                        value;
                  });
                },
              ),

              const SizedBox(height: 14),

              // ==================================================
              // JENIS MATERI
              // ==================================================

              DropdownButtonFormField<String>(
                initialValue:
                selectedType,
                decoration:
                const InputDecoration(
                  labelText:
                  'Jenis Materi',
                  prefixIcon: Icon(
                    Icons.attach_file_rounded,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'PDF',
                    child: Text('PDF'),
                  ),
                  DropdownMenuItem(
                    value: 'Video',
                    child: Text('Video'),
                  ),
                  DropdownMenuItem(
                    value: 'Dokumen',
                    child: Text(
                      'Dokumen',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Link',
                    child: Text('Link'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    selectedType =
                        value;
                  });
                },
              ),

              const SizedBox(height: 14),

              // ==================================================
              // URL
              // ==================================================

              TextFormField(
                controller:
                _fileUrlController,
                keyboardType:
                TextInputType.url,
                decoration:
                const InputDecoration(
                  labelText:
                  'URL Materi',
                  hintText:
                  'Masukkan link file / video / dokumen',
                  prefixIcon: Icon(
                    Icons.link_rounded,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // ==================================================
              // DESKRIPSI
              // ==================================================

              TextFormField(
                controller:
                _descriptionController,
                maxLines: 3,
                decoration:
                const InputDecoration(
                  labelText:
                  'Deskripsi',
                  hintText:
                  'Deskripsi singkat materi',
                  prefixIcon: Icon(
                    Icons.description_outlined,
                  ),
                  alignLabelWithHint:
                  true,
                ),
              ),
            ],
          ),
        ),
      ),

      actions: [
        // ========================================================
        // BATAL
        // ========================================================

        TextButton(
          onPressed: _saving
              ? null
              : () {
            Navigator.of(context)
                .pop();
          },
          child:
          const Text('Batal'),
        ),

        // ========================================================
        // SIMPAN
        // ========================================================

        FilledButton(
          onPressed:
          _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
            width: 18,
            height: 18,
            child:
            CircularProgressIndicator(
              strokeWidth: 2,
            ),
          )
              : Text(
            isEdit
                ? 'Simpan Perubahan'
                : 'Simpan',
          ),
        ),
      ],
    );
  }
}