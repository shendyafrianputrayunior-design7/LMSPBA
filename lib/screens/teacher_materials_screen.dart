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
  String? _teacherId;

  bool _loadingTeacher = true;
  bool _loadingMaterials = true;

  List<_MaterialItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadTeacherProfile();
  }

  // ============================================================
  // RESOLVE TEACHER DOCUMENT ID
  // ============================================================

  Future<String?> _getTeacherDocumentId() async {
    final user = _auth.currentUser;

    if (user == null) return null;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();

      final teacherId = userData?['teacherId']?.toString().trim();

      if (teacherId != null && teacherId.isNotEmpty) {
        return teacherId;
      }

      final email = user.email?.trim();

      if (email != null && email.isNotEmpty) {
        final teacherQuery = await _firestore
            .collection('teachers')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (teacherQuery.docs.isNotEmpty) {
          return teacherQuery.docs.first.id;
        }
      }
    } catch (_) {}

    return null;
  }

  // ============================================================
  // LOAD TEACHER PROFILE
  // ============================================================

  Future<void> _loadTeacherProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingTeacher = false;
          _loadingMaterials = false;
        });
      }
      return;
    }

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      String teacherName = user.displayName ?? 'Guru';
      String? teacherId;

      if (snapshot.exists) {
        final data = snapshot.data() ?? {};

        teacherName = (data['name'] ??
            data['username'] ??
            data['displayName'] ??
            user.displayName ??
            'Guru')
            .toString();

        final storedTeacherId = data['teacherId']?.toString().trim();

        if (storedTeacherId != null && storedTeacherId.isNotEmpty) {
          teacherId = storedTeacherId;
        }
      }

      // Fallback berdasarkan email
      if (teacherId == null || teacherId.isEmpty) {
        teacherId = await _getTeacherDocumentId();
      }

      if (!mounted) return;

      setState(() {
        _teacherName = teacherName.isEmpty ? 'Guru' : teacherName;
        _teacherId = teacherId;
        _loadingTeacher = false;
      });

      await _loadAllMaterials();
    } catch (_) {
      final fallbackTeacherId = await _getTeacherDocumentId();

      if (!mounted) return;

      setState(() {
        _teacherName = user.displayName ?? 'Guru';
        _teacherId = fallbackTeacherId;
        _loadingTeacher = false;
      });

      await _loadAllMaterials();
    }
  }

  // ============================================================
  // LOAD MATERIALS + COURSE LESSON VIDEOS
  // ============================================================

  Future<void> _loadAllMaterials() async {
    if (_teacherId == null || _teacherId!.isEmpty) {
      if (mounted) {
        setState(() {
          _items = [];
          _loadingMaterials = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loadingMaterials = true;
      });
    }

    try {
      final List<_MaterialItem> allItems = [];

      // ----------------------------------------------------------
      // 1. MATERIALS BIASA
      // ----------------------------------------------------------

      final materialSnapshot = await _firestore
          .collection('materials')
          .where(
        'teacherId',
        isEqualTo: _teacherId,
      )
          .get();

      for (final doc in materialSnapshot.docs) {
        final data = doc.data();

        allItems.add(
          _MaterialItem(
            id: doc.id,
            data: data,
            isCourseLesson: false,
          ),
        );
      }

      // ----------------------------------------------------------
      // 2. COURSE LESSONS
      // ----------------------------------------------------------

      final lessonSnapshot = await _firestore
          .collection('course_lessons')
          .where(
        'teacherId',
        isEqualTo: _teacherId,
      )
          .get();

      for (final doc in lessonSnapshot.docs) {
        final data = doc.data();

        final videoUrl = (data['videoUrl'] ?? '').toString().trim();

        // Hanya tampilkan lesson yang memang memiliki video
        if (videoUrl.isEmpty) {
          continue;
        }

        allItems.add(
          _MaterialItem(
            id: doc.id,
            data: data,
            isCourseLesson: true,
          ),
        );
      }

      // ----------------------------------------------------------
      // SORT BERDASARKAN CREATED AT
      // ----------------------------------------------------------

      allItems.sort((a, b) {
        final aTimestamp = a.data['createdAt'];
        final bTimestamp = b.data['createdAt'];

        if (aTimestamp is Timestamp && bTimestamp is Timestamp) {
          return bTimestamp.compareTo(aTimestamp);
        }

        final aUpdated = a.data['updatedAt'];
        final bUpdated = b.data['updatedAt'];

        if (aUpdated is Timestamp && bUpdated is Timestamp) {
          return bUpdated.compareTo(aUpdated);
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
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
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
          ? const Center(
        child: CircularProgressIndicator(),
      )
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

            return _buildMaterialCard(
              item.id,
              item.data,
              item.isCourseLesson,
            );
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
      bool isCourseLesson,
      ) {
    final theme = Theme.of(context);

    // ----------------------------------------------------------
    // DATA
    // ----------------------------------------------------------

    final title = isCourseLesson
        ? (data['title'] ??
        data['lessonTitle'] ??
        data['name'] ??
        'Video Pembelajaran')
        .toString()
        : (data['title'] ?? 'Materi').toString();

    final description = (data['description'] ?? '').toString();

    final courseName = (data['courseName'] ??
        data['courseTitle'] ??
        '')
        .toString();

    final className = (data['className'] ?? '').toString();

    final classId = (data['classId'] ?? '').toString();

    final videoUrl = (data['videoUrl'] ?? '').toString().trim();

    final videoFileName = (data['videoFileName'] ?? '').toString();

    final videoSize = data['videoSize'];

    final attachmentUrl = (data['attachmentUrl'] ??
        data['fileUrl'] ??
        '')
        .toString()
        .trim();

    // ----------------------------------------------------------
    // COURSE LESSON VIDEO
    // ----------------------------------------------------------

    if (isCourseLesson) {
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
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.play_circle_outline,
                      color: Colors.red,
                      size: 30,
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
                        const SizedBox(height: 5),
                        const Text(
                          'Video Course',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (courseName.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildInfoChip(
                  icon: Icons.school_outlined,
                  text: courseName,
                ),
              ],

              if (className.isNotEmpty || classId.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildInfoChip(
                  icon: Icons.class_outlined,
                  text: className.isNotEmpty ? className : classId,
                ),
              ],

              if (description.isNotEmpty) ...[
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

              const SizedBox(height: 14),

              // ------------------------------------------------
              // VIDEO INFORMATION
              // ------------------------------------------------

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
                        crossAxisAlignment:
                        CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Video terlampir',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (videoFileName.isNotEmpty) ...[
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
                          if (videoSize is num &&
                              videoSize > 0) ...[
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

              const SizedBox(height: 14),

              // ------------------------------------------------
              // VIDEO URL
              // ------------------------------------------------

              if (videoUrl.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
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
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 14),

              // ------------------------------------------------
              // STATUS
              // ------------------------------------------------

              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
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
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // ==========================================================
    // MATERIAL BIASA
    // ==========================================================

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.menu_book_outlined,
                    color: theme.colorScheme.primary,
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
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                      if (courseName.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          courseName,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                            Colors.grey.shade600,
                            fontWeight:
                            FontWeight.w500,
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

            if (description.isNotEmpty) ...[
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

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (classId.isNotEmpty)
                  _buildInfoChip(
                    icon:
                    Icons.class_outlined,
                    text: classId,
                  ),
                if (courseName.isNotEmpty)
                  _buildInfoChip(
                    icon:
                    Icons.school_outlined,
                    text: courseName,
                  ),
                if (attachmentUrl.isNotEmpty)
                  _buildInfoChip(
                    icon:
                    Icons.attach_file_outlined,
                    text: 'Lampiran tersedia',
                  ),
                if (videoUrl.isNotEmpty)
                  _buildInfoChip(
                    icon:
                    Icons.video_library_outlined,
                    text: 'Video tersedia',
                  ),
              ],
            ),

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
                        color: Colors.red.withValues(
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
        color: Colors.grey.withValues(
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
              color: Colors.grey.shade700,
              fontWeight:
              FontWeight.w500,
            ),
          ),
        ],
      ),
    );
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
                    .withValues(alpha: 0.08),
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
              'Belum ada materi atau video pembelajaran yang ditambahkan.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () =>
                  _openMaterialForm(),
              icon:
              const Icon(Icons.add),
              label: const Text(
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
    if (bytes <= 0) return '0 B';

    const units = [
      'B',
      'KB',
      'MB',
      'GB',
    ];

    double size = bytes.toDouble();
    int unitIndex = 0;

    while (size >= 1024 &&
        unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(size >= 10 ? 0 : 1)} ${units[unitIndex]}';
  }
}

// ================================================================
// MODEL INTERNAL
// ================================================================

class _MaterialItem {
  final String id;
  final Map<String, dynamic> data;
  final bool isCourseLesson;

  const _MaterialItem({
    required this.id,
    required this.data,
    required this.isCourseLesson,
  });
}