import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'teacher_announcement_form_screen.dart';
import 'teacher_announcement_delete_screen.dart';

class TeacherAnnouncementsScreen extends StatefulWidget {
  const TeacherAnnouncementsScreen({super.key});

  @override
  State<TeacherAnnouncementsScreen> createState() =>
      _TeacherAnnouncementsScreenState();
}

class _TeacherAnnouncementsScreenState
    extends State<TeacherAnnouncementsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _teacherName = 'Guru';
  String? _teacherId;
  bool _loadingTeacher = true;

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

    if (user == null) {
      return null;
    }

    try {
      // ========================================================
      // 1. CEK users/{uid}.teacherId
      // ========================================================

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();

      final savedTeacherId =
      userData?['teacherId']?.toString().trim();

      if (savedTeacherId != null &&
          savedTeacherId.isNotEmpty) {
        // Pastikan document teachers memang ada.
        final teacherDoc = await _firestore
            .collection('teachers')
            .doc(savedTeacherId)
            .get();

        if (teacherDoc.exists) {
          return savedTeacherId;
        }
      }

      // ========================================================
      // 2. FALLBACK BERDASARKAN EMAIL
      // ========================================================

      final email = user.email?.trim();

      if (email != null && email.isNotEmpty) {
        final teacherQuery = await _firestore
            .collection('teachers')
            .where(
          'email',
          isEqualTo: email,
        )
            .limit(1)
            .get();

        if (teacherQuery.docs.isNotEmpty) {
          return teacherQuery.docs.first.id;
        }
      }
    } catch (_) {
      // Jangan crash jika proses resolver gagal.
    }

    return null;
  }

  // ============================================================
  // LOAD PROFILE GURU
  // ============================================================

  Future<void> _loadTeacherProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _teacherName = 'Guru';
          _teacherId = null;
          _loadingTeacher = false;
        });
      }

      return;
    }

    try {
      // ========================================================
      // PROFILE USER
      // ========================================================

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      String teacherName = user.displayName ?? 'Guru';

      if (snapshot.exists) {
        final data = snapshot.data() ?? {};

        teacherName = (
            data['name'] ??
                data['username'] ??
                data['displayName'] ??
                user.displayName ??
                'Guru'
        ).toString();
      }

      // ========================================================
      // RESOLVE TEACHER ID CANONICAL
      // ========================================================

      final teacherId = await _getTeacherDocumentId();

      if (!mounted) return;

      setState(() {
        _teacherName =
        teacherName.isEmpty ? 'Guru' : teacherName;

        _teacherId = teacherId;

        _loadingTeacher = false;
      });
    } catch (_) {
      final teacherId = await _getTeacherDocumentId();

      if (!mounted) return;

      setState(() {
        _teacherName = user.displayName ?? 'Guru';
        _teacherId = teacherId;
        _loadingTeacher = false;
      });
    }
  }

  // ============================================================
  // STREAM PENGUMUMAN
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> _announcementStream() {
    final user = _auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    final teacherId = _teacherId;

    if (teacherId == null || teacherId.isEmpty) {
      return const Stream.empty();
    }

    // ==========================================================
    // teacherId utama = ID document teachers
    //
    // Auth UID juga dimasukkan agar pengumuman lama yang
    // terlanjur tersimpan menggunakan UID tetap dapat terlihat.
    // ==========================================================

    final teacherIds = <String>{
      teacherId,
      user.uid,
    }.toList();

    return _firestore
        .collection('announcements')
        .where(
      'teacherId',
      whereIn: teacherIds,
    )
        .snapshots();
  }

  // ============================================================
  // FORM TAMBAH / EDIT
  // ============================================================

  Future<void> _openAnnouncementForm({
    String? announcementId,
    Map<String, dynamic>? data,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherAnnouncementFormScreen(
          announcementId: announcementId,
          announcementData: data,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            announcementId == null
                ? 'Pengumuman berhasil ditambahkan.'
                : 'Pengumuman berhasil diperbarui.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _openDeleteAnnouncement(
      String announcementId,
      String title,
      ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherAnnouncementDeleteScreen(
          announcementId: announcementId,
          title: title,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pengumuman berhasil dihapus.',
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pengumuman',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Tambah Pengumuman',
            onPressed: () => _openAnnouncementForm(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),

      body: _loadingTeacher
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _announcementStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildError(
              snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs =
              snapshot.data?.docs.toList() ?? [];

          // Pengumuman terbaru di atas.
          docs.sort((a, b) {
            final aTimestamp =
            a.data()['createdAt'];

            final bTimestamp =
            b.data()['createdAt'];

            if (aTimestamp is Timestamp &&
                bTimestamp is Timestamp) {
              return bTimestamp.compareTo(
                aTimestamp,
              );
            }

            return 0;
          });

          if (docs.isEmpty) {
            return _buildEmpty();
          }

          return RefreshIndicator(
            onRefresh: () async {
              await _loadTeacherProfile();
            },
            child: ListView.builder(
              physics:
              const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                100,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];

                return _buildAnnouncementCard(
                  doc.id,
                  doc.data(),
                );
              },
            ),
          );
        },
      ),

      floatingActionButton:
      FloatingActionButton.extended(
        onPressed: () => _openAnnouncementForm(),
        icon: const Icon(Icons.add),
        label: const Text(
          'Tambah Pengumuman',
        ),
      ),
    );
  }

  // ============================================================
  // ANNOUNCEMENT CARD
  // ============================================================

  Widget _buildAnnouncementCard(
      String announcementId,
      Map<String, dynamic> data,
      ) {
    final title =
    (data['title'] ?? 'Pengumuman').toString();

    final content =
    (data['content'] ??
        data['description'] ??
        '')
        .toString();

    final classId =
    (data['classId'] ?? '').toString();

    final courseName =
    (data['courseName'] ??
        data['courseTitle'] ??
        '')
        .toString();

    final priority =
    (data['priority'] ?? 'Normal').toString();

    final priorityColor =
    _priorityColor(priority);

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
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color:
                    priorityColor.withValues(
                      alpha: 0.1,
                    ),
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.campaign_outlined,
                    color: priorityColor,
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
                      const SizedBox(height: 5),
                      Text(
                        _teacherName,
                        style: TextStyle(
                          color:
                          Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),

                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openAnnouncementForm(
                        announcementId:
                        announcementId,
                        data: data,
                      );
                    }

                    if (value == 'delete') {
                      _openDeleteAnnouncement(
                        announcementId,
                        title,
                      );
                    }
                  },
                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem<String>(
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
                      PopupMenuItem<String>(
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

            const SizedBox(height: 14),

            Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color:
                priorityColor.withValues(
                  alpha: 0.1,
                ),
                borderRadius:
                BorderRadius.circular(8),
              ),
              child: Text(
                'Prioritas: $priority',
                style: TextStyle(
                  color: priorityColor,
                  fontSize: 12,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),

            if (content.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                content,
                maxLines: 4,
                overflow:
                TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                  Colors.grey.shade700,
                  height: 1.45,
                ),
              ),
            ],

            const SizedBox(height: 14),

            const Divider(
              height: 1,
            ),

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
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child:
                  OutlinedButton.icon(
                    onPressed: () {
                      _openAnnouncementForm(
                        announcementId:
                        announcementId,
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
                        color:
                        Colors.red.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    onPressed: () {
                      _openDeleteAnnouncement(
                        announcementId,
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
  // PRIORITY COLOR
  // ============================================================

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Tinggi':
        return Colors.red;

      case 'Rendah':
        return Colors.blue;

      case 'Normal':
      default:
        return Colors.orange;
    }
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
            color:
            Colors.grey.shade700,
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
  // EMPTY
  // ============================================================

  Widget _buildEmpty() {
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
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(
                  alpha: 0.08,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.campaign_outlined,
                size: 44,
                color: Theme.of(context)
                    .colorScheme
                    .primary,
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Belum Ada Pengumuman',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Belum ada pengumuman yang dibuat.',
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
                  _openAnnouncementForm(),
              icon: const Icon(
                Icons.add,
              ),
              label: const Text(
                'Tambah Pengumuman',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 52,
              color:
              Colors.red.shade400,
            ),

            const SizedBox(height: 16),

            const Text(
              'Gagal Memuat Pengumuman',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              error,
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: () {
                _loadTeacherProfile();
              },
              icon: const Icon(
                Icons.refresh,
              ),
              label: const Text(
                'Coba Lagi',
              ),
            ),
          ],
        ),
      ),
    );
  }
}