import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

const achievementCategories = [
  'Pembelajaran',
  'Quiz',
  'Ujian',
  'Kehadiran',
  'Prestasi',
  'Lainnya',
];

/// Data kelas yang digunakan Admin.
/// ID adalah ID resmi Firestore.
/// NAME hanya untuk tampilan.
const achievementClasses = [
  {
    'id': 'ALL',
    'name': 'Semua Kelas',
  },
  {
    'id': 'X_RPL_1',
    'name': 'X RPL 1',
  },
  {
    'id': 'XI_RPL_1',
    'name': 'XI RPL 1',
  },
  {
    'id': 'XI_RPL_2',
    'name': 'XI RPL 2',
  },
  {
    'id': 'XII_RPL_1',
    'name': 'XII RPL 1',
  },
];

class AdminAchievementsScreen extends StatefulWidget {
  const AdminAchievementsScreen({super.key});

  @override
  State<AdminAchievementsScreen> createState() =>
      _AdminAchievementsScreenState();
}

class _AdminAchievementsScreenState
    extends State<AdminAchievementsScreen> {
  final FirestoreService _firestore = FirestoreService.instance;

  // ============================================================
  // TAMBAH / EDIT ACHIEVEMENT
  // ============================================================

  Future<void> _showAchievementDialog({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    if (!mounted) return;

    final data = document?.data();
    final isEdit = document != null;

    final initialClassId =
        data?['targetClassId']?.toString() ??
            _convertOldClassNameToId(
              data?['targetClass']?.toString(),
            );

    final result = await showDialog<_AchievementFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _AchievementFormDialog(
          isEdit: isEdit,
          initialTitle: data?['title']?.toString() ?? '',
          initialDescription:
          data?['description']?.toString() ?? '',
          initialCategory: data?['category']?.toString(),
          initialClassId: initialClassId,
          initialPoints: data?['points']?.toString() ?? '10',
          initialActive: data?['active'] != false,
        );
      },
    );

    if (result == null) return;
    if (!mounted) return;

    try {
      final selectedClass = _findClass(result.targetClassId);

      if (isEdit) {
        await _firestore.updateAchievement(
          id: document!.id,
          title: result.title,
          description: result.description,
          category: result.category,
          targetClassId: result.targetClassId,
          targetClassName: selectedClass['name']!,
          points: result.points,
          active: result.active,
        );
      } else {
        await _firestore.addAchievement(
          title: result.title,
          description: result.description,
          category: result.category,
          targetClassId: result.targetClassId,
          targetClassName: selectedClass['name']!,
          points: result.points,
          active: result.active,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Achievement berhasil diperbarui'
                : 'Achievement berhasil ditambahkan',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan achievement: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // HAPUS
  // ============================================================

  Future<void> _deleteAchievement(
      String id,
      String title,
      ) async {
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Achievement'),
          content: Text('Hapus "$title"?'),
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
      await _firestore.deleteAchievement(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Achievement berhasil dihapus',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // HELPER CLASS
  // ============================================================

  Map<String, String> _findClass(String id) {
    return achievementClasses.firstWhere(
          (item) => item['id'] == id,
      orElse: () => achievementClasses.first,
    );
  }

  String _convertOldClassNameToId(String? className) {
    if (className == null || className.isEmpty) {
      return 'ALL';
    }

    final found = achievementClasses.firstWhere(
          (item) => item['name'] == className,
      orElse: () => achievementClasses.first,
    );

    return found['id']!;
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
        title: const Text(
          'Kelola Achievement',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),

      // ========================================================
      // FAB
      // ========================================================

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showAchievementDialog();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Achievement'),
      ),

      // ========================================================
      // FIRESTORE
      // ========================================================

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.getAchievements(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat achievement.\n\n'
                      '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada achievement.',
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              100,
            ),
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
            const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final title =
                  data['title']?.toString() ?? '-';

              final description =
                  data['description']?.toString() ?? '-';

              final category =
                  data['category']?.toString() ?? '-';

              final targetClassName =
                  data['targetClassName']?.toString() ??
                      data['targetClass']?.toString() ??
                      '-';

              final points =
                  data['points']?.toString() ?? '0';

              final active =
                  data['active'] != false;

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(
                      0.35,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // ==================================================
                    // ICON
                    // ==================================================

                    Icon(
                      Icons.emoji_events_rounded,
                      color: active
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      size: 32,
                    ),

                    const SizedBox(width: 14),

                    // ==================================================
                    // CONTENT
                    // ==================================================

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium
                                ?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            '$category • '
                                '$targetClassName • '
                                '$points poin',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(
                              color: colorScheme.primary,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(
                              color:
                              colorScheme.onSurfaceVariant,
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
                          _showAchievementDialog(
                            document: doc,
                          );
                        }

                        if (value == 'delete') {
                          _deleteAchievement(
                            doc.id,
                            title,
                          );
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Hapus'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ================================================================
// FORM RESULT
// ================================================================

class _AchievementFormResult {
  final String title;
  final String description;
  final String category;
  final String targetClassId;
  final int points;
  final bool active;

  const _AchievementFormResult({
    required this.title,
    required this.description,
    required this.category,
    required this.targetClassId,
    required this.points,
    required this.active,
  });
}

// ================================================================
// FORM DIALOG
// ================================================================

class _AchievementFormDialog extends StatefulWidget {
  final bool isEdit;

  final String initialTitle;
  final String initialDescription;
  final String? initialCategory;
  final String initialClassId;
  final String initialPoints;
  final bool initialActive;

  const _AchievementFormDialog({
    required this.isEdit,
    required this.initialTitle,
    required this.initialDescription,
    required this.initialCategory,
    required this.initialClassId,
    required this.initialPoints,
    required this.initialActive,
  });

  @override
  State<_AchievementFormDialog> createState() =>
      _AchievementFormDialogState();
}

class _AchievementFormDialogState
    extends State<_AchievementFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _pointsController;

  late String _selectedCategory;
  late String _selectedClassId;
  late bool _active;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.initialTitle,
    );

    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );

    _pointsController = TextEditingController(
      text: widget.initialPoints,
    );

    _selectedCategory =
    achievementCategories.contains(
      widget.initialCategory,
    )
        ? widget.initialCategory!
        : achievementCategories.first;

    final classExists = achievementClasses.any(
          (item) => item['id'] == widget.initialClassId,
    );

    _selectedClassId = classExists
        ? widget.initialClassId
        : 'ALL';

    _active = widget.initialActive;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();

    super.dispose();
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final points = int.tryParse(
      _pointsController.text.trim(),
    );

    if (points == null || points < 0) {
      return;
    }

    Navigator.of(context).pop(
      _AchievementFormResult(
        title: _titleController.text.trim(),
        description:
        _descriptionController.text.trim(),
        category: _selectedCategory,
        targetClassId: _selectedClassId,
        points: points,
        active: _active,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.isEdit
            ? 'Edit Achievement'
            : 'Tambah Achievement',
      ),

      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ==================================================
              // JUDUL
              // ==================================================

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Judul Achievement',
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Judul wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 12),

              // ==================================================
              // DESKRIPSI
              // ==================================================

              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi',
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // KATEGORI
              // ==================================================

              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                ),
                items: achievementCategories
                    .map(
                      (item) => DropdownMenuItem<String>(
                    value: item,
                    child: Text(item),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _selectedCategory = value;
                  });
                },
              ),

              const SizedBox(height: 12),

              // ==================================================
              // TARGET KELAS
              // ==================================================

              DropdownButtonFormField<String>(
                initialValue: _selectedClassId,
                decoration: const InputDecoration(
                  labelText: 'Target Kelas',
                ),
                items: achievementClasses
                    .map(
                      (item) => DropdownMenuItem<String>(
                    value: item['id'],
                    child: Text(item['name']!),
                  ),
                )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _selectedClassId = value;
                  });
                },
              ),

              const SizedBox(height: 12),

              // ==================================================
              // POIN
              // ==================================================

              TextFormField(
                controller: _pointsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Poin',
                ),
                validator: (value) {
                  final points = int.tryParse(
                    value?.trim() ?? '',
                  );

                  if (points == null || points < 0) {
                    return 'Poin harus berupa angka 0 atau lebih';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 4),

              // ==================================================
              // AKTIF
              // ==================================================

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif'),
                value: _active,
                onChanged: (value) {
                  setState(() {
                    _active = value;
                  });
                },
              ),
            ],
          ),
        ),
      ),

      // ==========================================================
      // ACTIONS
      // ==========================================================

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            widget.isEdit
                ? 'Simpan Perubahan'
                : 'Simpan',
          ),
        ),
      ],
    );
  }
}