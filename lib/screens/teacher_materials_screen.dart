
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
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _teacherName = 'Guru';
  String _teacherId = '';

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

  Future<Map<String, dynamic>?> _getTeacherProfile(User user) async {
    // Cara pertama: cari berdasarkan UID Firebase Authentication.
    final userDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      return userDoc.data();
    }

    // Cara kedua: cari berdasarkan email jika ID dokumen berbeda.
    if (user.email != null && user.email!.isNotEmpty) {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: user.email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.data();
      }
    }

    return null;
  }

  Future<void> _loadTeacherProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _teacherName = 'Guru';
        _teacherId = '';
        _loadingTeacher = false;
        _loadingMaterials = false;
        _items = [];
      });

      return;
    }

    try {
      final profileData = await _getTeacherProfile(user);

      final name = (
          profileData?['username'] ??
              profileData?['name'] ??
              profileData?['displayName'] ??
              user.displayName ??
              'Guru'
      ).toString().trim();

      final teacherId = (
          profileData?['teacherId'] ??
              profileData?['teacherDocId'] ??
              profileData?['idGuru'] ??
              ''
      ).toString().trim();

      debugPrint('========== PROFIL GURU MATERI ==========');
      debugPrint('Auth UID   : ${user.uid}');
      debugPrint('Email      : ${user.email}');
      debugPrint('Nama       : $name');
      debugPrint('Teacher ID : $teacherId');
      debugPrint('Profil     : $profileData');
      debugPrint('========================================');

      if (!mounted) return;

      setState(() {
        _teacherName = name.isEmpty ? 'Guru' : name;
        _teacherId = teacherId;
        _loadingTeacher = false;
      });

      await _loadAllMaterials();
    } catch (e) {
      debugPrint('Gagal memuat profil guru: $e');

      if (!mounted) return;

      setState(() {
        _teacherName = user.displayName ?? 'Guru';
        _teacherId = '';
        _loadingTeacher = false;
        _loadingMaterials = false;
        _items = [];
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat profil guru: $e')),
      );
    }
  }

  // ============================================================
  // LOAD MATERIALS USING FIRESTORE TEACHER ID
  // ============================================================

  Future<void> _loadAllMaterials() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _items = [];
        _loadingMaterials = false;
      });

      return;
    }

    if (mounted) {
      setState(() {
        _loadingMaterials = true;
      });
    }

    try {
      // Jika Teacher ID belum tersedia, muat ulang profil guru.
      String teacherId = _teacherId.trim();

      if (teacherId.isEmpty) {
        final profileData = await _getTeacherProfile(user);

        teacherId = (
            profileData?['teacherId'] ??
                profileData?['teacherDocId'] ??
                profileData?['idGuru'] ??
                ''
        ).toString().trim();

        if (teacherId.isNotEmpty && mounted) {
          setState(() {
            _teacherId = teacherId;
          });
        }
      }

      debugPrint('========== CEK MATERI GURU ==========');
      debugPrint('Auth UID   : ${user.uid}');
      debugPrint('Teacher ID : $teacherId');

      if (teacherId.isEmpty) {
        throw Exception(
          'teacherId tidak ditemukan pada profil guru di koleksi users.',
        );
      }

      final materialSnapshot = await _firestore
          .collection('materials')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      debugPrint(
        'Jumlah materi ditemukan: ${materialSnapshot.docs.length}',
      );

      final List<_MaterialItem> allItems = [];

      for (final materialDoc in materialSnapshot.docs) {
        final Map<String, dynamic> data =
        Map<String, dynamic>.from(materialDoc.data());

        final String materialId = materialDoc.id;

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

        debugPrint(
          'Materi: $materialTitle | ID: $materialId | '
              'Course: $courseId',
        );

        if (courseId.isNotEmpty) {
          final resolvedVideo = await _resolveVideoForMaterial(
            courseId: courseId,
            courseLessonId: courseLessonId,
            materialTitle: materialTitle,
          );

          if (resolvedVideo != null) {
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
                await _firestore
                    .collection('materials')
                    .doc(materialId)
                    .update({
                  'courseLessonId': resolvedVideo.lessonId,
                  'videoUrl': resolvedVideo.videoUrl,
                  'videoFileName': resolvedVideo.videoFileName,
                  'videoSize': resolvedVideo.videoSize,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                data.addAll({
                  'courseLessonId': resolvedVideo.lessonId,
                  'videoUrl': resolvedVideo.videoUrl,
                  'videoFileName': resolvedVideo.videoFileName,
                  'videoSize': resolvedVideo.videoSize,
                });
              } catch (e) {
                debugPrint(
                  'Gagal migrasi video material $materialId: $e',
                );

                // Materi tetap ditampilkan meskipun migrasi gagal.
                data['courseLessonId'] = resolvedVideo.lessonId;
                data['videoUrl'] = resolvedVideo.videoUrl;
                data['videoFileName'] =
                    resolvedVideo.videoFileName;
                data['videoSize'] = resolvedVideo.videoSize;
              }
            } else {
              data['courseLessonId'] = resolvedVideo.lessonId;
              data['videoUrl'] = resolvedVideo.videoUrl;
              data['videoFileName'] = resolvedVideo.videoFileName;
              data['videoSize'] = resolvedVideo.videoSize;
            }
          }
        }

        allItems.add(
          _MaterialItem(
            id: materialId,
            data: data,
          ),
        );
      }

      // ==========================================================
      // SORT MATERIALS
      // ==========================================================

      allItems.sort((a, b) {
        final aCreated = a.data['createdAt'];
        final bCreated = b.data['createdAt'];

        if (aCreated is Timestamp && bCreated is Timestamp) {
          return bCreated.compareTo(aCreated);
        }

        final aUpdated = a.data['updatedAt'];
        final bUpdated = b.data['updatedAt'];

        if (aUpdated is Timestamp && bUpdated is Timestamp) {
          return bUpdated.compareTo(aUpdated);
        }

        if (aCreated is Timestamp) return -1;
        if (bCreated is Timestamp) return 1;

        return 0;
      });

      debugPrint('Materi siap ditampilkan: ${allItems.length}');
      debugPrint('====================================');

      if (!mounted) return;

      setState(() {
        _items = allItems;
        _loadingMaterials = false;
      });
    } catch (e) {
      debugPrint('Gagal memuat materi: $e');

      if (!mounted) return;

      setState(() {
        _items = [];
        _loadingMaterials = false;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat materi: $e'),
        ),
      );
    }
  }

  // ============================================================
  // RESOLVE VIDEO
  // ============================================================

  Future<_ResolvedVideo?> _resolveVideoForMaterial({
    required String courseId,
    required String courseLessonId,
    required String materialTitle,
  }) async {
    try {
      // 1. Cari berdasarkan courseLessonId.
      if (courseLessonId.isNotEmpty) {
        final lessonDoc = await _firestore
            .collection('course_lessons')
            .doc(courseLessonId)
            .get();

        if (lessonDoc.exists) {
          final data = lessonDoc.data();

          if (data != null) {
            final videoUrl =
            (data['videoUrl'] ?? '').toString().trim();

            if (videoUrl.isNotEmpty) {
              return _ResolvedVideo(
                lessonId: lessonDoc.id,
                videoUrl: videoUrl,
                videoFileName:
                (data['videoFileName'] ?? '').toString().trim(),
                videoSize: _toInt(data['videoSize']),
              );
            }
          }
        }
      }

      // 2. Cari lesson pada course yang sama.
      final lessonSnapshot = await _firestore
          .collection('course_lessons')
          .where('courseId', isEqualTo: courseId)
          .get();

      final List<_ResolvedVideo> videos = [];

      for (final lessonDoc in lessonSnapshot.docs) {
        final data = lessonDoc.data();

        final videoUrl =
        (data['videoUrl'] ?? '').toString().trim();

        if (videoUrl.isEmpty) continue;

        videos.add(
          _ResolvedVideo(
            lessonId: lessonDoc.id,
            videoUrl: videoUrl,
            videoFileName:
            (data['videoFileName'] ?? '').toString().trim(),
            videoSize: _toInt(data['videoSize']),
          ),
        );
      }

      if (videos.isEmpty) return null;

      // 3. Cari berdasarkan judul materi.
      final normalizedMaterialTitle =
      materialTitle.trim().toLowerCase();

      if (normalizedMaterialTitle.isNotEmpty) {
        for (final lessonDoc in lessonSnapshot.docs) {
          final data = lessonDoc.data();

          final videoUrl =
          (data['videoUrl'] ?? '').toString().trim();

          if (videoUrl.isEmpty) continue;

          final lessonTitle = (
              data['title'] ??
                  data['lessonTitle'] ??
                  ''
          ).toString().trim().toLowerCase();

          if (lessonTitle == normalizedMaterialTitle) {
            return _ResolvedVideo(
              lessonId: lessonDoc.id,
              videoUrl: videoUrl,
              videoFileName:
              (data['videoFileName'] ?? '').toString().trim(),
              videoSize: _toInt(data['videoSize']),
            );
          }
        }
      }

      // 4. Jika hanya ada satu video, gunakan video tersebut.
      if (videos.length == 1) {
        return videos.first;
      }

      return null;
    } catch (e) {
      debugPrint('Gagal resolve video untuk course $courseId: $e');
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

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

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

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Materi berhasil dihapus.'),
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
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadAllMaterials,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Tambah Materi',
            onPressed: () => _openMaterialForm(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: _loadingTeacher || _loadingMaterials
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? _buildEmpty(theme)
          : RefreshIndicator(
        onRefresh: _loadAllMaterials,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            100,
          ),
          itemCount: _items.length,
          itemBuilder: (context, index) {
            final item = _items[index];
            return _buildMaterialCard(item.id, item.data);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openMaterialForm(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Materi'),
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

    final title = (data['title'] ?? 'Materi').toString();
    final subject = (data['subject'] ?? '').toString();

    final description = (
        data['description'] ??
            data['content'] ??
            ''
    ).toString();

    final content = (data['content'] ?? '').toString();

    final courseName = (
        data['courseName'] ??
            data['courseTitle'] ??
            ''
    ).toString();

    final classId = (data['classId'] ?? '').toString();
    final className = (data['className'] ?? '').toString();

    final displayClass = className.trim().isNotEmpty
        ? className
        : _classNameFromId(classId);

    final type = (data['type'] ?? 'Materi').toString();

    final videoUrl = (data['videoUrl'] ?? '').toString().trim();
    final videoFileName =
    (data['videoFileName'] ?? '').toString();
    final videoSize = data['videoSize'];

    final hasVideo = videoUrl.isNotEmpty;

    final attachmentUrl = (
        data['attachmentUrl'] ??
            data['fileUrl'] ??
            ''
    ).toString().trim();

    final hasAttachment = attachmentUrl.isNotEmpty;

    final courseLessonId =
    (data['courseLessonId'] ?? '').toString().trim();

    IconData typeIcon;

    switch (type) {
      case 'Video':
        typeIcon = Icons.play_circle_outline;
        break;
      case 'PDF':
        typeIcon = Icons.picture_as_pdf_outlined;
        break;
      case 'Dokumen':
        typeIcon = Icons.description_outlined;
        break;
      case 'Link':
        typeIcon = Icons.link_rounded;
        break;
      default:
        typeIcon = Icons.menu_book_outlined;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    typeIcon,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subject.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openMaterialForm(
                        materialId: materialId,
                        data: data,
                      );
                    } else if (value == 'delete') {
                      _openDeleteMaterial(materialId, title);
                    }
                  },
                  itemBuilder: (context) => const [
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
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 10),
                          Text(
                            'Hapus',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (courseName.trim().isNotEmpty ||
                displayClass.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (courseName.trim().isNotEmpty)
                    _buildInfoChip(
                      icon: Icons.school_outlined,
                      text: courseName,
                    ),
                  if (displayClass.trim().isNotEmpty)
                    _buildInfoChip(
                      icon: Icons.class_outlined,
                      text: displayClass,
                    ),
                ],
              ),
            ],

            if (description.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],

            if (content.trim().isNotEmpty &&
                content.trim() != description.trim()) ...[
              const SizedBox(height: 8),
              Text(
                'Isi: $content',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip(
                  icon: Icons.attach_file_outlined,
                  text: type,
                ),
                if (hasAttachment)
                  _buildInfoChip(
                    icon: Icons.attachment_outlined,
                    text: 'URL materi tersedia',
                  ),
                if (hasVideo)
                  _buildInfoChip(
                    icon: Icons.video_library_outlined,
                    text: 'Video tersedia',
                  ),
                if (courseLessonId.isNotEmpty)
                  _buildInfoChip(
                    icon: Icons.play_circle_outline,
                    text: 'Lesson terhubung',
                  ),
              ],
            ),

            if (hasAttachment) ...[
              const SizedBox(height: 14),
              _buildUrlContainer(attachmentUrl),
            ],

            if (hasVideo) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(
                    alpha: 0.06,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(
                      alpha: 0.15,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.video_library_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Video terlampir',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (videoFileName.trim().isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              videoFileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                          if (videoSize is num && videoSize > 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              _formatFileSize(videoSize.toInt()),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
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
              _buildUrlContainer(videoUrl),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: Colors.green,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Video tersedia',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _openMaterialForm(
                        materialId: materialId,
                        data: data,
                      );
                    },
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                    ),
                    label: const Text('Edit'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(
                        color: Colors.red.withValues(alpha: 0.5),
                      ),
                    ),
                    onPressed: () {
                      _openDeleteMaterial(materialId, title);
                    },
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                    ),
                    label: const Text('Hapus'),
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
  // URL CONTAINER
  // ============================================================

  Widget _buildUrlContainer(String url) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.link, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
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
        return classId.isEmpty ? '' : classId;
    }
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(
                  alpha: 0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_outlined,
                size: 44,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum Ada Materi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada materi pembelajaran yang ditambahkan.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => _openMaterialForm(),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Materi'),
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
    if (bytes <= 0) return '0 B';

    const units = ['B', 'KB', 'MB', 'GB'];

    double size = bytes.toDouble();
    int unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} '
        '${units[unitIndex]}';
  }

  // ============================================================
  // HELPERS
  // ============================================================

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  bool _hasValidVideoSize(dynamic value) {
    return _toInt(value) > 0;
  }

  bool _sameNumber(dynamic first, int second) {
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
// MATERIAL MODEL
// ================================================================

class _MaterialItem {
  final String id;
  final Map<String, dynamic> data;

  const _MaterialItem({
    required this.id,
    required this.data,
  });
}
