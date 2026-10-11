import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'teacher_material_form_screen.dart';
import 'teacher_material_delete_screen.dart';

class TeacherMaterialsScreen extends StatefulWidget {
  const TeacherMaterialsScreen({super.key});

  @override
  State<TeacherMaterialsScreen> createState() =>
      _TeacherMaterialsScreenState();
}

class _TeacherMaterialsScreenState extends State<TeacherMaterialsScreen> {
  // ============================================================
  // FIXED TEACHER ID
  // ============================================================

  static const String _fixedTeacherId = 'teacher_001';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _teacherName = 'Guru';

  bool _loadingTeacher = true;
  bool _loadingMaterials = true;

  List<_MaterialItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadTeacherProfile();
  }

  // ============================================================
  // LOAD TEACHER PROFILE
  // ============================================================

  Future<void> _loadTeacherProfile() async {
    final user = _auth.currentUser;

    String teacherName = 'Guru';

    if (user != null) {
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (snapshot.exists) {
          final data = snapshot.data() ?? {};

          teacherName = (
              data['name'] ??
                  data['username'] ??
                  data['displayName'] ??
                  user.displayName ??
                  'Guru'
          ).toString();
        } else {
          teacherName = user.displayName ?? 'Guru';
        }
      } catch (_) {
        teacherName = user.displayName ?? 'Guru';
      }
    }

    if (!mounted) return;

    setState(() {
      _teacherName =
      teacherName.trim().isEmpty ? 'Guru' : teacherName.trim();

      _loadingTeacher = false;
    });

    await _loadAllMaterials();
  }

  // ============================================================
  // LOAD ALL MATERIALS
  //
  // PENTING:
  //
  // COLLECTION "materials" ADALAH SUMBER UTAMA CARD/MENU.
  //
  // course_lessons HANYA DIGUNAKAN UNTUK MENCARI VIDEO
  // YANG TERHUBUNG DENGAN MATERIAL.
  //
  // course_lessons TIDAK AKAN DIBUAT MENJADI CARD SENDIRI.
  //
  // HASIL:
  //
  // 1 MATERIAL
  // ├── URL materi
  // └── Video
  //
  // menjadi 1 card.
  // ============================================================

  Future<void> _loadAllMaterials() async {
    if (mounted) {
      setState(() {
        _loadingMaterials = true;
      });
    }

    try {
      final materialSnapshot = await _firestore
          .collection('materials')
          .where(
        'teacherId',
        isEqualTo: _fixedTeacherId,
      )
          .get();

      final List<_MaterialItem> allItems = [];

      // ==========================================================
      // LOAD MATERIALS
      // ==========================================================

      for (final materialDoc in materialSnapshot.docs) {
        final Map<String, dynamic> data =
        Map<String, dynamic>.from(materialDoc.data());

        final String materialId = materialDoc.id;

        // --------------------------------------------------------
        // FIELD MATERIAL
        // --------------------------------------------------------

        final String courseId =
        (data['courseId'] ?? '').toString().trim();

        final String courseLessonId =
        (data['courseLessonId'] ?? '').toString().trim();

        final String materialTitle =
        (data['title'] ?? '').toString().trim();

        String videoUrl =
        (data['videoUrl'] ?? '').toString().trim();

        String videoFileName =
        (data['videoFileName'] ?? '').toString().trim();

        dynamic videoSize = data['videoSize'] ?? 0;

        String resolvedCourseLessonId = courseLessonId;

        // ========================================================
        // CARI VIDEO YANG TERHUBUNG
        // ========================================================

        if (courseId.isNotEmpty) {
          final _ResolvedVideo? resolvedVideo =
          await _resolveVideoForMaterial(
            courseId: courseId,
            courseLessonId: courseLessonId,
            materialTitle: materialTitle,
          );

          if (resolvedVideo != null) {
            // ----------------------------------------------------
            // Kalau material belum mempunyai video,
            // gunakan video dari course_lessons.
            // ----------------------------------------------------

            if (videoUrl.isEmpty) {
              videoUrl = resolvedVideo.videoUrl;
            }

            if (videoFileName.isEmpty) {
              videoFileName = resolvedVideo.videoFileName;
            }

            if (!_hasValidVideoSize(videoSize) &&
                resolvedVideo.videoSize > 0) {
              videoSize = resolvedVideo.videoSize;
            }

            resolvedCourseLessonId =
                resolvedVideo.lessonId;

            // ----------------------------------------------------
            // UPDATE MATERIAL
            //
            // Ini penting supaya hubungan material -> video
            // tersimpan permanen.
            // ----------------------------------------------------

            final bool needsMigration =
                courseLessonId != resolvedVideo.lessonId ||
                    (data['videoUrl'] ?? '').toString().trim() !=
                        resolvedVideo.videoUrl ||
                    (data['videoFileName'] ?? '').toString().trim() !=
                        resolvedVideo.videoFileName ||
                    !_sameNumber(
                      data['videoSize'],
                      resolvedVideo.videoSize,
                    );

            if (needsMigration) {
              try {
                final Map<String, dynamic> migrationData = {
                  'courseLessonId': resolvedVideo.lessonId,
                  'videoUrl': resolvedVideo.videoUrl,
                  'videoFileName': resolvedVideo.videoFileName,
                  'videoSize': resolvedVideo.videoSize,
                  'updatedAt': FieldValue.serverTimestamp(),
                };

                await _firestore
                    .collection('materials')
                    .doc(materialId)
                    .update(migrationData);

                // Update data lokal juga.
                data.addAll({
                  'courseLessonId':
                  resolvedVideo.lessonId,
                  'videoUrl':
                  resolvedVideo.videoUrl,
                  'videoFileName':
                  resolvedVideo.videoFileName,
                  'videoSize':
                  resolvedVideo.videoSize,
                });
              } catch (e) {
                debugPrint(
                  'Gagal migrasi video material '
                      '$materialId: $e',
                );

                // Walaupun migrasi gagal, data tetap
                // ditampilkan menggunakan hasil resolver.
                data['courseLessonId'] =
                    resolvedVideo.lessonId;
                data['videoUrl'] =
                    resolvedVideo.videoUrl;
                data['videoFileName'] =
                    resolvedVideo.videoFileName;
                data['videoSize'] =
                    resolvedVideo.videoSize;
              }
            } else {
              data['courseLessonId'] =
                  resolvedVideo.lessonId;
              data['videoUrl'] =
                  resolvedVideo.videoUrl;
              data['videoFileName'] =
                  resolvedVideo.videoFileName;
              data['videoSize'] =
                  resolvedVideo.videoSize;
            }
          }
        }

        // ========================================================
        // MASUKKAN SATU CARD MATERIAL
        // ========================================================

        allItems.add(
          _MaterialItem(
            id: materialId,
            data: data,
          ),
        );
      }

      // ==========================================================
      // SORT
      // ==========================================================

      allItems.sort((a, b) {
        final aCreated = a.data['createdAt'];
        final bCreated = b.data['createdAt'];

        if (aCreated is Timestamp &&
            bCreated is Timestamp) {
          return bCreated.compareTo(aCreated);
        }

        final aUpdated = a.data['updatedAt'];
        final bUpdated = b.data['updatedAt'];

        if (aUpdated is Timestamp &&
            bUpdated is Timestamp) {
          return bUpdated.compareTo(aUpdated);
        }

        if (aCreated is Timestamp) {
          return -1;
        }

        if (bCreated is Timestamp) {
          return 1;
        }

        return 0;
      });

      if (!mounted) return;

      setState(() {
        _items = allItems;
        _loadingMaterials = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingMaterials = false;
      });

      ScaffoldMessenger.of(context)
          .hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memuat materi: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // RESOLVE VIDEO
  //
  // URUTAN PENCARIAN:
  //
  // 1. courseLessonId
  // 2. title material == title lesson
  // 3. hanya ada satu video pada course
  //
  // Dengan cara ini video lama yang courseLessonId-nya kosong
  // tetap bisa ditemukan.
  // ============================================================

  Future<_ResolvedVideo?> _resolveVideoForMaterial({
    required String courseId,
    required String courseLessonId,
    required String materialTitle,
  }) async {
    try {
      // ========================================================
      // 1. EXACT COURSE LESSON ID
      // ========================================================

      if (courseLessonId.isNotEmpty) {
        final lessonDoc = await _firestore
            .collection('course_lessons')
            .doc(courseLessonId)
            .get();

        if (lessonDoc.exists) {
          final data = lessonDoc.data();

          if (data != null) {
            final String videoUrl =
            (data['videoUrl'] ?? '').toString().trim();

            if (videoUrl.isNotEmpty) {
              return _ResolvedVideo(
                lessonId: lessonDoc.id,
                videoUrl: videoUrl,
                videoFileName:
                (data['videoFileName'] ?? '')
                    .toString()
                    .trim(),
                videoSize: _toInt(
                  data['videoSize'],
                ),
              );
            }
          }
        }
      }

      // ========================================================
      // 2. AMBIL SEMUA LESSON DALAM COURSE
      // ========================================================

      final lessonSnapshot = await _firestore
          .collection('course_lessons')
          .where(
        'courseId',
        isEqualTo: courseId,
      )
          .get();

      final List<_ResolvedVideo> videos = [];

      for (final lessonDoc in lessonSnapshot.docs) {
        final data = lessonDoc.data();

        final String videoUrl =
        (data['videoUrl'] ?? '').toString().trim();

        if (videoUrl.isEmpty) {
          continue;
        }

        videos.add(
          _ResolvedVideo(
            lessonId: lessonDoc.id,
            videoUrl: videoUrl,
            videoFileName:
            (data['videoFileName'] ?? '')
                .toString()
                .trim(),
            videoSize: _toInt(
              data['videoSize'],
            ),
          ),
        );
      }

      if (videos.isEmpty) {
        return null;
      }

      // ========================================================
      // 3. CARI BERDASARKAN TITLE
      // ========================================================

      final String normalizedMaterialTitle =
      materialTitle.trim().toLowerCase();

      if (normalizedMaterialTitle.isNotEmpty) {
        for (final lessonDoc in lessonSnapshot.docs) {
          final data = lessonDoc.data();

          final String videoUrl =
          (data['videoUrl'] ?? '').toString().trim();

          if (videoUrl.isEmpty) {
            continue;
          }

          final String lessonTitle =
          (
              data['title'] ??
                  data['lessonTitle'] ??
                  ''
          ).toString().trim().toLowerCase();

          if (lessonTitle.isNotEmpty &&
              lessonTitle == normalizedMaterialTitle) {
            return _ResolvedVideo(
              lessonId: lessonDoc.id,
              videoUrl: videoUrl,
              videoFileName:
              (data['videoFileName'] ?? '')
                  .toString()
                  .trim(),
              videoSize: _toInt(
                data['videoSize'],
              ),
            );
          }
        }
      }

      // ========================================================
      // 4. JIKA HANYA ADA SATU VIDEO
      //
      // Ini khusus untuk data lama yang courseLessonId-nya
      // belum tersimpan.
      // ========================================================

      if (videos.length == 1) {
        return videos.first;
      }

      // ========================================================
      // Jika lebih dari satu video dan tidak ada title yang
      // cocok, jangan memilih secara sembarangan.
      // ========================================================

      return null;
    } catch (e) {
      debugPrint(
        'Gagal resolve video untuk course $courseId: $e',
      );

      return null;
    }
  }

  // ============================================================
  // OPEN MATERIAL FORM
  // ============================================================

  Future<void> _openMaterialForm({
    String? materialId,
    Map<String, dynamic>? data,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherMaterialFormScreen(
          materialId: materialId,
          materialData: data,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadAllMaterials();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            materialId == null
                ? 'Materi berhasil ditambahkan.'
                : 'Materi berhasil diperbarui.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DELETE MATERIAL
  // ============================================================

  Future<void> _openDeleteMaterial(
      String materialId,
      String title,
      ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherMaterialDeleteScreen(
          materialId: materialId,
          title: title,
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadAllMaterials();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Materi berhasil dihapus.',
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Materi Pembelajaran',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadAllMaterials,
            icon: const Icon(
              Icons.refresh,
            ),
          ),
          IconButton(
            tooltip: 'Tambah Materi',
            onPressed: () => _openMaterialForm(),
            icon: const Icon(
              Icons.add,
            ),
          ),
        ],
      ),
      body: _loadingTeacher || _loadingMaterials
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _items.isEmpty
          ? _buildEmpty(theme)
          : RefreshIndicator(
        onRefresh: _loadAllMaterials,
        child: ListView.builder(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            100,
          ),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];

            return _buildMaterialCard(
              item.id,
              item.data,
            );
          },
        ),
      ),
      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: () => _openMaterialForm(),
        icon: const Icon(
          Icons.add,
        ),
        label: const Text(
          'Tambah Materi',
        ),
      ),
    );
  }

  // ============================================================
  // MATERIAL CARD
  // ============================================================

  Widget _buildMaterialCard(
      String materialId,
      Map<String, dynamic> data,
      ) {
    final theme = Theme.of(context);

    final title =
    (data['title'] ?? 'Materi').toString();

    final subject =
    (data['subject'] ?? '').toString();

    final description =
    (
        data['description'] ??
            data['content'] ??
            ''
    ).toString();

    final content =
    (data['content'] ?? '').toString();

    final courseName =
    (
        data['courseName'] ??
            data['courseTitle'] ??
            ''
    ).toString();

    final classId =
    (data['classId'] ?? '').toString();

    final className =
    (data['className'] ?? '').toString();

    final displayClass =
    className.trim().isNotEmpty
        ? className
        : _classNameFromId(classId);

    final type =
    (data['type'] ?? 'Materi').toString();

    final videoUrl =
    (data['videoUrl'] ?? '')
        .toString()
        .trim();

    final videoFileName =
    (data['videoFileName'] ?? '')
        .toString();

    final videoSize =
    data['videoSize'];

    final bool hasVideo =
        videoUrl.isNotEmpty;

    final attachmentUrl =
    (
        data['attachmentUrl'] ??
            data['fileUrl'] ??
            ''
    ).toString().trim();

    final bool hasAttachment =
        attachmentUrl.isNotEmpty;

    final courseLessonId =
    (data['courseLessonId'] ?? '')
        .toString()
        .trim();

    IconData typeIcon;

    switch (type) {
      case 'Video':
        typeIcon =
            Icons.play_circle_outline;
        break;

      case 'PDF':
        typeIcon =
            Icons.picture_as_pdf_outlined;
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
            Icons.menu_book_outlined;
    }

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: theme
                        .colorScheme
                        .primary
                        .withValues(
                      alpha: 0.1,
                    ),
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                  child: Icon(
                    typeIcon,
                    color:
                    theme.colorScheme.primary,
                  ),
                ),

                const SizedBox(width: 12),

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
                        style:
                        const TextStyle(
                          fontSize: 17,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      if (subject
                          .trim()
                          .isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          subject,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme
                                .colorScheme
                                .primary,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ==================================================
                // MENU
                // ==================================================

                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openMaterialForm(
                        materialId: materialId,
                        data: data,
                      );
                    }

                    if (value == 'delete') {
                      _openDeleteMaterial(
                        materialId,
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
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Hapus',
                              style: TextStyle(
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),

            // ==================================================
            // COURSE + CLASS
            // ==================================================

            if (courseName
                .trim()
                .isNotEmpty ||
                displayClass
                    .trim()
                    .isNotEmpty) ...[
              const SizedBox(height: 14),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (courseName
                      .trim()
                      .isNotEmpty)
                    _buildInfoChip(
                      icon:
                      Icons.school_outlined,
                      text: courseName,
                    ),

                  if (displayClass
                      .trim()
                      .isNotEmpty)
                    _buildInfoChip(
                      icon:
                      Icons.class_outlined,
                      text: displayClass,
                    ),
                ],
              ),
            ],

            // ==================================================
            // DESCRIPTION
            // ==================================================

            if (description
                .trim()
                .isNotEmpty) ...[
              const SizedBox(height: 14),

              Text(
                description,
                maxLines: 3,
                overflow:
                TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],

            // ==================================================
            // CONTENT
            // ==================================================

            if (content
                .trim()
                .isNotEmpty &&
                content.trim() !=
                    description.trim()) ...[
              const SizedBox(height: 8),

              Text(
                'Isi: $content',
                maxLines: 2,
                overflow:
                TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color:
                  Colors.grey.shade600,
                ),
              ),
            ],

            const SizedBox(height: 14),

            const Divider(height: 1),

            const SizedBox(height: 14),

            // ==================================================
            // INFORMATION CHIPS
            // ==================================================

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  icon:
                  Icons.attach_file_outlined,
                  text: type,
                ),

                if (hasAttachment)
                  _buildInfoChip(
                    icon:
                    Icons.attachment_outlined,
                    text:
                    'URL materi tersedia',
                  ),

                if (hasVideo)
                  _buildInfoChip(
                    icon:
                    Icons.video_library_outlined,
                    text:
                    'Video tersedia',
                  ),

                if (courseLessonId
                    .isNotEmpty)
                  _buildInfoChip(
                    icon:
                    Icons.play_circle_outline,
                    text:
                    'Lesson terhubung',
                  ),
              ],
            ),

            // ==================================================
            // URL MATERI
            // ==================================================

            if (hasAttachment) ...[
              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                  Colors.grey.withValues(
                    alpha: 0.06,
                  ),
                  borderRadius:
                  BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link,
                      size: 18,
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        attachmentUrl,
                        maxLines: 2,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                          Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ==================================================
            // VIDEO
            // ==================================================

            if (hasVideo) ...[
              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme
                      .colorScheme
                      .primary
                      .withValues(
                    alpha: 0.06,
                  ),
                  borderRadius:
                  BorderRadius.circular(12),
                  border: Border.all(
                    color: theme
                        .colorScheme
                        .primary
                        .withValues(
                      alpha: 0.15,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons
                          .video_library_outlined,
                      color:
                      theme.colorScheme.primary,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Video terlampir',
                            style: TextStyle(
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),

                          if (videoFileName
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 3),

                            Text(
                              videoFileName,
                              maxLines: 1,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors
                                    .grey
                                    .shade600,
                              ),
                            ),
                          ],

                          if (videoSize is num &&
                              videoSize > 0) ...[
                            const SizedBox(height: 2),

                            Text(
                              _formatFileSize(
                                videoSize.toInt(),
                              ),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors
                                    .grey
                                    .shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                  Colors.grey.withValues(
                    alpha: 0.06,
                  ),
                  borderRadius:
                  BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link,
                      size: 18,
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        videoUrl,
                        maxLines: 2,
                        overflow:
                        TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                          Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.symmetric(
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color:
                  Colors.green.withValues(
                    alpha: 0.08,
                  ),
                  borderRadius:
                  BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons
                          .check_circle_outline,
                      size: 18,
                      color: Colors.green,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Video tersedia',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ==================================================
            // ACTION BUTTON
            // ==================================================

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child:
                  OutlinedButton.icon(
                    onPressed: () {
                      _openMaterialForm(
                        materialId:
                        materialId,
                        data: data,
                      );
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                    ),
                    label:
                    const Text('Edit'),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child:
                  OutlinedButton.icon(
                    style:
                    OutlinedButton.styleFrom(
                      foregroundColor:
                      Colors.red,
                      side: BorderSide(
                        color: Colors.red
                            .withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    onPressed: () {
                      _openDeleteMaterial(
                        materialId,
                        title,
                      );
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                    ),
                    label:
                    const Text('Hapus'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INFO CHIP
  // ============================================================

  Widget _buildInfoChip({
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color:
        Colors.grey.withValues(
          alpha: 0.08,
        ),
        borderRadius:
        BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey.shade700,
          ),

          const SizedBox(width: 6),

          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color:
              Colors.grey.shade700,
              fontWeight:
              FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CLASS NAME
  // ============================================================

  String _classNameFromId(String classId) {
    switch (classId) {
      case 'X_RPL_1':
        return 'X RPL 1';

      case 'XI_RPL_1':
        return 'XI RPL 1';

      case 'XI_RPL_2':
        return 'XI RPL 2';

      case 'XII_RPL_1':
        return 'XII RPL 1';

      default:
        return classId.isEmpty
            ? ''
            : classId;
    }
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: theme
                    .colorScheme
                    .primary
                    .withValues(
                  alpha: 0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_outlined,
                size: 44,
                color:
                theme.colorScheme.primary,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Belum Ada Materi',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Belum ada materi pembelajaran yang ditambahkan.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 22),

            FilledButton.icon(
              onPressed:
                  () => _openMaterialForm(),
              icon: const Icon(
                Icons.add,
              ),
              label:
              const Text(
                'Tambah Materi',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FILE SIZE
  // ============================================================

  String _formatFileSize(int bytes) {
    if (bytes <= 0) {
      return '0 B';
    }

    const units = [
      'B',
      'KB',
      'MB',
      'GB',
    ];

    double size =
    bytes.toDouble();

    int unitIndex = 0;

    while (size >= 1024 &&
        unitIndex <
            units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(
      size >= 10 ? 0 : 1,
    )} ${units[unitIndex]}';
  }

  // ============================================================
  // HELPERS
  // ============================================================

  int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }

  bool _hasValidVideoSize(dynamic value) {
    return _toInt(value) > 0;
  }

  bool _sameNumber(
      dynamic first,
      int second,
      ) {
    return _toInt(first) == second;
  }
}

// ================================================================
// RESOLVED VIDEO
// ================================================================

class _ResolvedVideo {
  final String lessonId;
  final String videoUrl;
  final String videoFileName;
  final int videoSize;

  const _ResolvedVideo({
    required this.lessonId,
    required this.videoUrl,
    required this.videoFileName,
    required this.videoSize,
  });
}

// ================================================================
// MODEL INTERNAL
// ================================================================

class _MaterialItem {
  final String id;
  final Map<String, dynamic> data;

  const _MaterialItem({
    required this.id,
    required this.data,
  });
}