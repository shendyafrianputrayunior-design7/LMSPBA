import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class AdminAnnouncementsScreen extends StatefulWidget {
  const AdminAnnouncementsScreen({super.key});

  @override
  State<AdminAnnouncementsScreen> createState() =>
      _AdminAnnouncementsScreenState();
}

class _AdminAnnouncementsScreenState
    extends State<AdminAnnouncementsScreen> {
  final FirestoreService _firestore =
      FirestoreService.instance;

  // ============================================================
  // KATEGORI
  // ============================================================

  static const List<String> categories = [
    'Akademik',
    'Tugas',
    'Informasi',
    'Kegiatan',
    'Ujian',
  ];

  // ============================================================
  // KELAS
  //
  // ID = RELASI UTAMA
  // NAME = TAMPILAN
  // ============================================================

  static const List<Map<String, String>> classes = [
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

  // ============================================================
  // CARI ID KELAS BERDASARKAN NAMA LAMA
  // ============================================================

  String _classIdFromName(String? className) {
    if (className == null || className.trim().isEmpty) {
      return 'ALL';
    }

    final normalized =
    className.trim().toLowerCase();

    for (final item in classes) {
      final name =
      item['name']!.toLowerCase();

      if (name == normalized) {
        return item['id']!;
      }
    }

    return 'ALL';
  }

  // ============================================================
  // CARI NAMA KELAS
  // ============================================================

  String _classNameFromId(String? classId) {
    if (classId == null ||
        classId.trim().isEmpty) {
      return 'Semua Kelas';
    }

    for (final item in classes) {
      if (item['id'] == classId) {
        return item['name']!;
      }
    }

    return 'Semua Kelas';
  }

  // ============================================================
  // TAMBAH / EDIT PENGUMUMAN
  // ============================================================

  Future<void> _showAnnouncementDialog({
    DocumentSnapshot<Map<String, dynamic>>?
    document,
  }) async {
    if (!mounted) return;

    final data = document?.data();
    final isEdit = document != null;

    // ==========================================================
    // CATEGORY LAMA
    // ==========================================================

    final savedCategory =
    data?['category']?.toString();

    final selectedCategory =
    categories.contains(savedCategory)
        ? savedCategory!
        : categories.first;

    // ==========================================================
    // KELAS
    //
    // Prioritas:
    // 1. targetClassId baru
    // 2. targetClass lama
    // ==========================================================

    String selectedClassId;

    final savedClassId =
    data?['targetClassId']?.toString();

    final savedClassName =
    data?['targetClassName']?.toString();

    final savedOldClass =
    data?['targetClass']?.toString();

    if (savedClassId != null &&
        classes.any(
              (item) =>
          item['id'] == savedClassId,
        )) {
      selectedClassId = savedClassId;
    } else if (savedClassName != null &&
        savedClassName.isNotEmpty) {
      selectedClassId =
          _classIdFromName(savedClassName);
    } else {
      selectedClassId =
          _classIdFromName(savedOldClass);
    }

    final selectedClassName =
    _classNameFromId(
      selectedClassId,
    );

    // ==========================================================
    // DIALOG
    // ==========================================================

    final result =
    await showDialog<_AnnouncementFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return _AnnouncementFormDialog(
          isEdit: isEdit,
          initialTitle:
          data?['title']?.toString() ??
              '',
          initialContent:
          data?['content']?.toString() ??
              '',
          initialDate:
          data?['date']?.toString() ??
              '',
          initialCategory:
          selectedCategory,
          initialClassId:
          selectedClassId,
          initialClassName:
          selectedClassName,
          initialImportant:
          data?['important'] == true,
          categories: categories,
          classes: classes,
        );
      },
    );

    if (result == null) return;
    if (!mounted) return;

    // ==========================================================
    // SIMPAN
    // ==========================================================

    try {
      if (isEdit) {
        await _firestore.updateAnnouncement(
          id: document!.id,
          title: result.title,
          content: result.content,
          category: result.category,

          // ID KELAS BARU
          targetClassId:
          result.targetClassId,

          // NAMA KELAS
          targetClassName:
          result.targetClassName,

          // LEGACY
          targetClass:
          result.targetClassName,

          date: result.date,
          important: result.important,
        );
      } else {
        await _firestore.addAnnouncement(
          title: result.title,
          content: result.content,
          category: result.category,

          // ID KELAS BARU
          targetClassId:
          result.targetClassId,

          // NAMA KELAS
          targetClassName:
          result.targetClassName,

          // LEGACY
          targetClass:
          result.targetClassName,

          date: result.date,
          important: result.important,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Pengumuman berhasil diperbarui'
                : 'Pengumuman berhasil ditambahkan',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan pengumuman: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // HAPUS
  // ============================================================

  Future<void> _deleteAnnouncement(
      String id,
      String title,
      ) async {
    if (!mounted) return;

    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Hapus Pengumuman',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Apakah kamu yakin ingin '
                'menghapus "$title"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(false);
              },
              child: const Text(
                'Batal',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(true);
              },
              child: const Text(
                'Hapus',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    try {
      await _firestore.deleteAnnouncement(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pengumuman berhasil dihapus',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus pengumuman: $e',
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

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        title: const Text(
          'Kelola Pengumuman',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
        theme.scaffoldBackgroundColor,
      ),

      // ==========================================================
      // TAMBAH
      // ==========================================================

      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: () {
          _showAnnouncementDialog();
        },
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Tambah Pengumuman',
        ),
      ),

      // ==========================================================
      // DATA
      // ==========================================================

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream:
        _firestore.getAnnouncements(),
        builder: (
            context,
            snapshot,
            ) {
          // ========================================================
          // LOADING
          // ========================================================

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
              CircularProgressIndicator(),
            );
          }

          // ========================================================
          // ERROR
          // ========================================================

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat pengumuman.\n\n'
                      '${snapshot.error}',
                  textAlign:
                  TextAlign.center,
                ),
              ),
            );
          }

          final docs =
              snapshot.data?.docs ?? [];

          // ========================================================
          // KOSONG
          // ========================================================

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada pengumuman.',
              ),
            );
          }

          // ========================================================
          // LIST
          // ========================================================

          return ListView.separated(
            padding:
            const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              100,
            ),
            itemCount: docs.length,
            separatorBuilder: (
                _,
                __,
                ) {
              return const SizedBox(
                height: 12,
              );
            },
            itemBuilder: (
                context,
                index,
                ) {
              final doc = docs[index];
              final data = doc.data();

              final title =
                  data['title']
                      ?.toString() ??
                      '-';

              final content =
                  data['content']
                      ?.toString() ??
                      '-';

              final category =
                  data['category']
                      ?.toString() ??
                      '-';

              // ====================================================
              // NAMA KELAS
              //
              // Prioritas:
              // targetClassName
              // targetClass
              // targetClassId
              // ====================================================

              String target;

              final targetClassName =
              data['targetClassName']
                  ?.toString();

              final targetClass =
              data['targetClass']
                  ?.toString();

              final targetClassId =
              data['targetClassId']
                  ?.toString();

              if (targetClassName != null &&
                  targetClassName
                      .isNotEmpty) {
                target = targetClassName;
              } else if (targetClass != null &&
                  targetClass.isNotEmpty) {
                target = targetClass;
              } else {
                target =
                    _classNameFromId(
                      targetClassId,
                    );
              }

              final important =
                  data['important'] == true;

              return Container(
                padding:
                const EdgeInsets.all(16),
                decoration:
                BoxDecoration(
                  color:
                  colorScheme.surface,
                  borderRadius:
                  BorderRadius.circular(
                    18,
                  ),
                  border: Border.all(
                    color: colorScheme
                        .outline
                        .withOpacity(
                      0.35,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // ==============================================
                    // ICON
                    // ==============================================

                    Container(
                      width: 52,
                      height: 52,
                      decoration:
                      BoxDecoration(
                        color: (important
                            ? colorScheme
                            .error
                            : colorScheme
                            .primary)
                            .withOpacity(
                          0.12,
                        ),
                        borderRadius:
                        BorderRadius
                            .circular(
                          14,
                        ),
                      ),
                      child: Icon(
                        important
                            ? Icons
                            .priority_high_rounded
                            : Icons
                            .campaign_outlined,
                        color: important
                            ? colorScheme
                            .error
                            : colorScheme
                            .primary,
                        size: 30,
                      ),
                    ),

                    const SizedBox(
                      width: 14,
                    ),

                    // ==============================================
                    // DATA
                    // ==============================================

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(
                            title,
                            maxLines: 2,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style: theme
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                              fontWeight:
                              FontWeight
                                  .w800,
                            ),
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          Text(
                            '$category • $target',
                            maxLines: 1,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color:
                              colorScheme
                                  .primary,
                              fontWeight:
                              FontWeight
                                  .w600,
                            ),
                          ),

                          const SizedBox(
                            height: 5,
                          ),

                          Text(
                            content,
                            maxLines: 2,
                            overflow:
                            TextOverflow
                                .ellipsis,
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    // ==============================================
                    // MENU
                    // ==============================================

                    PopupMenuButton<String>(
                      onSelected: (
                          value,
                          ) {
                        if (value ==
                            'edit') {
                          _showAnnouncementDialog(
                            document: doc,
                          );
                        } else if (value ==
                            'delete') {
                          _deleteAnnouncement(
                            doc.id,
                            title,
                          );
                        }
                      },
                      itemBuilder: (_) {
                        return const [
                          PopupMenuItem<String>(
                            value: 'edit',
                            child: Text(
                              'Edit',
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Text(
                              'Hapus',
                            ),
                          ),
                        ];
                      },
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

// ==================================================================
// MODEL HASIL FORM
// ==================================================================

class _AnnouncementFormResult {
  final String title;
  final String content;
  final String category;

  final String targetClassId;
  final String targetClassName;

  final String date;
  final bool important;

  const _AnnouncementFormResult({
    required this.title,
    required this.content,
    required this.category,
    required this.targetClassId,
    required this.targetClassName,
    required this.date,
    required this.important,
  });
}

// ==================================================================
// DIALOG FORM
// ==================================================================

class _AnnouncementFormDialog
    extends StatefulWidget {
  final bool isEdit;

  final String initialTitle;
  final String initialContent;
  final String initialDate;
  final String initialCategory;

  final String initialClassId;
  final String initialClassName;

  final bool initialImportant;

  final List<String> categories;
  final List<Map<String, String>> classes;

  const _AnnouncementFormDialog({
    required this.isEdit,
    required this.initialTitle,
    required this.initialContent,
    required this.initialDate,
    required this.initialCategory,
    required this.initialClassId,
    required this.initialClassName,
    required this.initialImportant,
    required this.categories,
    required this.classes,
  });

  @override
  State<_AnnouncementFormDialog> createState() =>
      _AnnouncementFormDialogState();
}

class _AnnouncementFormDialogState
    extends State<_AnnouncementFormDialog> {
  late final TextEditingController
  titleController;

  late final TextEditingController
  contentController;

  late final TextEditingController
  dateController;

  late String selectedCategory;
  late String selectedClassId;
  late bool important;

  final formKey =
  GlobalKey<FormState>();

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    titleController =
        TextEditingController(
          text: widget.initialTitle,
        );

    contentController =
        TextEditingController(
          text: widget.initialContent,
        );

    dateController =
        TextEditingController(
          text: widget.initialDate,
        );

    selectedCategory =
    widget.categories.contains(
      widget.initialCategory,
    )
        ? widget.initialCategory
        : widget.categories.first;

    final validClass =
    widget.classes.any(
          (item) =>
      item['id'] ==
          widget.initialClassId,
    );

    selectedClassId =
    validClass
        ? widget.initialClassId
        : widget.classes.first['id']!;

    important =
        widget.initialImportant;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    dateController.dispose();

    super.dispose();
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  void _submit() {
    if (!formKey.currentState!
        .validate()) {
      return;
    }

    String selectedClassName =
        'Semua Kelas';

    for (final item in widget.classes) {
      if (item['id'] ==
          selectedClassId) {
        selectedClassName =
            item['name'] ?? 'Semua Kelas';
        break;
      }
    }

    Navigator.of(context).pop(
      _AnnouncementFormResult(
        title:
        titleController.text.trim(),
        content:
        contentController.text.trim(),
        category:
        selectedCategory,
        targetClassId:
        selectedClassId,
        targetClassName:
        selectedClassName,
        date:
        dateController.text.trim(),
        important:
        important,
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
            ? 'Edit Pengumuman'
            : 'Tambah Pengumuman',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: formKey,
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
                  titleController,
                  decoration:
                  const InputDecoration(
                    labelText: 'Judul',
                    prefixIcon: Icon(
                      Icons
                          .campaign_outlined,
                    ),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value
                            .trim()
                            .isEmpty) {
                      return 'Judul wajib diisi';
                    }

                    return null;
                  },
                ),

                const SizedBox(
                  height: 12,
                ),

                // ==================================================
                // ISI
                // ==================================================

                TextFormField(
                  controller:
                  contentController,
                  maxLines: 4,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Isi Pengumuman',
                    prefixIcon: Icon(
                      Icons
                          .description_outlined,
                    ),
                    alignLabelWithHint:
                    true,
                  ),
                  validator: (value) {
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
                  height: 12,
                ),

                // ==================================================
                // KATEGORI
                // ==================================================

                DropdownButtonFormField<
                    String>(
                  initialValue:
                  selectedCategory,
                  isExpanded: true,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Kategori',
                    prefixIcon: Icon(
                      Icons
                          .category_outlined,
                    ),
                  ),
                  items: widget
                      .categories
                      .map(
                        (category) {
                      return DropdownMenuItem<
                          String>(
                        value:
                        category,
                        child: Text(
                          category,
                        ),
                      );
                    },
                  ).toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      selectedCategory =
                          value;
                    });
                  },
                ),

                const SizedBox(
                  height: 12,
                ),

                // ==================================================
                // TARGET KELAS
                // ==================================================

                DropdownButtonFormField<
                    String>(
                  initialValue:
                  selectedClassId,
                  isExpanded: true,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Target Kelas',
                    prefixIcon: Icon(
                      Icons
                          .class_outlined,
                    ),
                  ),
                  items: widget.classes
                      .map(
                        (item) {
                      return DropdownMenuItem<
                          String>(
                        value:
                        item['id'],
                        child: Text(
                          item['name'] ??
                              '-',
                        ),
                      );
                    },
                  ).toList(),
                  onChanged: (value) {
                    if (value == null) {
                      return;
                    }

                    setState(() {
                      selectedClassId =
                          value;
                    });
                  },
                ),

                const SizedBox(
                  height: 12,
                ),

                // ==================================================
                // TANGGAL
                // ==================================================

                TextFormField(
                  controller:
                  dateController,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'Tanggal',
                    hintText:
                    '03 Oktober 2026',
                    prefixIcon: Icon(
                      Icons
                          .calendar_today_outlined,
                    ),
                  ),
                ),

                // ==================================================
                // PENTING
                // ==================================================

                SwitchListTile(
                  contentPadding:
                  EdgeInsets.zero,
                  title: const Text(
                    'Penting',
                  ),
                  value: important,
                  onChanged: (value) {
                    setState(() {
                      important =
                          value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),

      // ==========================================================
      // ACTION
      // ==========================================================

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text(
            'Batal',
          ),
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