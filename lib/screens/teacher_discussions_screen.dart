import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'teacher_discussion_form_screen.dart';
import 'teacher_discussion_delete_screen.dart';
import 'teacher_discussion_detail_screen.dart';

class TeacherDiscussionsScreen extends StatefulWidget {
  const TeacherDiscussionsScreen({super.key});

  @override
  State<TeacherDiscussionsScreen> createState() =>
      _TeacherDiscussionsScreenState();
}

class _TeacherDiscussionsScreenState
    extends State<TeacherDiscussionsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _teacherName = 'Guru';

  String? _authUid;
  String? _teacherDocumentId;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  // ============================================================
  // GET TEACHER DOCUMENT ID
  // ============================================================

  Future<String?> _getTeacherDocumentId() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    // ----------------------------------------------------------
    // 1. users/{uid}.teacherId
    // ----------------------------------------------------------

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data();

      final teacherId = data?['teacherId']?.toString().trim();

      debugPrint(
        'users/${user.uid} teacherId = $teacherId',
      );

      if (teacherId != null && teacherId.isNotEmpty) {
        final teacherDoc = await _firestore
            .collection('teachers')
            .doc(teacherId)
            .get();

        debugPrint(
          'teachers/$teacherId exists = ${teacherDoc.exists}',
        );

        if (teacherDoc.exists) {
          return teacherId;
        }
      }
    } catch (e) {
      debugPrint(
        'ERROR GET TEACHER ID FROM USER: $e',
      );
    }

    // ----------------------------------------------------------
    // 2. FALLBACK EMAIL
    // ----------------------------------------------------------

    try {
      final email = user.email?.trim();

      if (email != null && email.isNotEmpty) {
        final result = await _firestore
            .collection('teachers')
            .where(
          'email',
          isEqualTo: email,
        )
            .limit(1)
            .get();

        if (result.docs.isNotEmpty) {
          return result.docs.first.id;
        }
      }
    } catch (e) {
      debugPrint(
        'ERROR FIND TEACHER BY EMAIL: $e',
      );
    }

    return null;
  }

  // ============================================================
  // LOAD TEACHER DATA
  // ============================================================

  Future<void> _loadTeacherData() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }

      return;
    }

    _authUid = user.uid;

    debugPrint('');
    debugPrint('==========================================');
    debugPrint('TEACHER DISCUSSIONS');
    debugPrint('==========================================');
    debugPrint('AUTH UID : ${user.uid}');
    debugPrint('EMAIL    : ${user.email}');

    try {
      // --------------------------------------------------------
      // LOAD USER
      // --------------------------------------------------------

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};

        _teacherName = (
            data['name'] ??
                data['username'] ??
                data['displayName'] ??
                user.displayName ??
                'Guru'
        ).toString().trim();
      } else {
        _teacherName = user.displayName?.trim() ?? 'Guru';
      }

      if (_teacherName.isEmpty) {
        _teacherName = 'Guru';
      }

      // --------------------------------------------------------
      // LOAD TEACHER DOCUMENT ID
      // --------------------------------------------------------

      _teacherDocumentId = await _getTeacherDocumentId();

      debugPrint(
        'TEACHER DOCUMENT ID : $_teacherDocumentId',
      );

      debugPrint(
        'TEACHER NAME        : $_teacherName',
      );
    } catch (e) {
      debugPrint(
        'ERROR LOAD TEACHER DATA: $e',
      );
    }

    debugPrint('==========================================');
    debugPrint('');

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  // ============================================================
  // GET TEACHER CLASS IDS
  //
  // Kelas diambil dari courses milik guru.
  //
  // Diskusi siswa hanya menyimpan classId,
  // sehingga classId digunakan untuk mencari diskusi siswa.
  // ============================================================

  Future<Set<String>> _getTeacherClassIds() async {
    final Set<String> classIds = {};

    final teacherId = _teacherDocumentId;
    final authUid = _authUid;

    debugPrint('');
    debugPrint('==========================================');
    debugPrint('LOAD TEACHER CLASS IDS');
    debugPrint('==========================================');

    // ----------------------------------------------------------
    // QUERY COURSES DENGAN TEACHER DOCUMENT ID
    // ----------------------------------------------------------

    if (teacherId != null && teacherId.isNotEmpty) {
      try {
        final snapshot = await _firestore
            .collection('courses')
            .where(
          'teacherId',
          isEqualTo: teacherId,
        )
            .get();

        debugPrint(
          'Courses teacherId=$teacherId : '
              '${snapshot.docs.length}',
        );

        for (final doc in snapshot.docs) {
          final data = doc.data();

          final classId = data['classId']?.toString().trim();

          if (classId != null && classId.isNotEmpty) {
            classIds.add(classId);
          }
        }
      } catch (e) {
        debugPrint(
          'ERROR GET COURSES BY TEACHER ID: $e',
        );
      }
    }

    // ----------------------------------------------------------
    // QUERY LEGACY COURSES DENGAN AUTH UID
    //
    // Untuk data lama yang mungkin masih menggunakan UID.
    // ----------------------------------------------------------

    if (authUid != null && authUid.isNotEmpty) {
      try {
        final snapshot = await _firestore
            .collection('courses')
            .where(
          'teacherId',
          isEqualTo: authUid,
        )
            .get();

        debugPrint(
          'Courses teacherId=$authUid : '
              '${snapshot.docs.length}',
        );

        for (final doc in snapshot.docs) {
          final data = doc.data();

          final classId = data['classId']?.toString().trim();

          if (classId != null && classId.isNotEmpty) {
            classIds.add(classId);
          }
        }
      } catch (e) {
        debugPrint(
          'ERROR GET LEGACY COURSES: $e',
        );
      }
    }

    debugPrint(
      'TOTAL KELAS GURU: ${classIds.length}',
    );

    for (final classId in classIds) {
      debugPrint(
        'KELAS GURU: $classId',
      );
    }

    debugPrint('==========================================');
    debugPrint('');

    return classIds;
  }

  // ============================================================
  // GET DISCUSSIONS
  //
  // Guru membaca:
  //
  // 1. Diskusi yang dibuat guru sendiri
  // 2. Diskusi siswa berdasarkan classId kelas yang diajar
  //
  // Data lama tanpa teacherId tetap bisa terbaca.
  // ============================================================

  Future<List<
      QueryDocumentSnapshot<Map<String, dynamic>>>> _getDiscussions() async {
    final user = _auth.currentUser;

    if (user == null) {
      return [];
    }

    final Map<
        String,
        QueryDocumentSnapshot<Map<String, dynamic>>> discussions = {};

    debugPrint('');
    debugPrint('==========================================');
    debugPrint('LOAD DISCUSSIONS');
    debugPrint('==========================================');
    debugPrint('Auth UID   : ${user.uid}');
    debugPrint('Teacher ID : $_teacherDocumentId');

    // ==========================================================
    // QUERY 1
    // Diskusi yang dibuat oleh guru
    // ==========================================================

    if (_teacherDocumentId != null &&
        _teacherDocumentId!.isNotEmpty) {
      try {
        final snapshot = await _firestore
            .collection('discussions')
            .where(
          'teacherId',
          isEqualTo: _teacherDocumentId,
        )
            .get();

        debugPrint(
          'QUERY teacherId hasil: '
              '${snapshot.docs.length}',
        );

        for (final doc in snapshot.docs) {
          discussions[doc.id] = doc;
        }
      } catch (e) {
        debugPrint(
          'ERROR QUERY teacherId: $e',
        );
      }
    }

    // ==========================================================
    // QUERY 2
    // Diskusi yang dibuat guru dengan Auth UID
    //
    // Untuk kompatibilitas data lama.
    // ==========================================================

    try {
      final snapshot = await _firestore
          .collection('discussions')
          .where(
        'userId',
        isEqualTo: user.uid,
      )
          .get();

      debugPrint(
        'QUERY userId hasil: '
            '${snapshot.docs.length}',
      );

      for (final doc in snapshot.docs) {
        discussions[doc.id] = doc;
      }
    } catch (e) {
      debugPrint(
        'ERROR QUERY userId: $e',
      );
    }

    // ==========================================================
    // QUERY 3
    // DISKUSI SISWA BERDASARKAN KELAS GURU
    // ==========================================================

    final teacherClassIds = await _getTeacherClassIds();

    if (teacherClassIds.isNotEmpty) {
      final classList = teacherClassIds.toList();

      // Firestore whereIn memiliki batas jumlah item.
      // Kita pecah menjadi beberapa batch.
      const int batchSize = 30;

      for (
      int start = 0;
      start < classList.length;
      start += batchSize
      ) {
        final end =
        (start + batchSize < classList.length)
            ? start + batchSize
            : classList.length;

        final batch = classList.sublist(start, end);

        try {
          final snapshot = await _firestore
              .collection('discussions')
              .where(
            'classId',
            whereIn: batch,
          )
              .get();

          debugPrint(
            'QUERY classId [$batch] hasil: '
                '${snapshot.docs.length}',
          );

          for (final doc in snapshot.docs) {
            discussions[doc.id] = doc;
          }
        } catch (e) {
          debugPrint(
            'ERROR QUERY classId [$batch]: $e',
          );
        }
      }
    } else {
      debugPrint(
        'TIDAK ADA CLASS ID YANG DITEMUKAN UNTUK GURU.',
      );
    }

    // ==========================================================
    // SORT BERDASARKAN CREATED AT
    // ==========================================================

    final result = discussions.values.toList();

    result.sort((a, b) {
      final aCreated = a.data()['createdAt'];
      final bCreated = b.data()['createdAt'];

      if (aCreated is Timestamp && bCreated is Timestamp) {
        return bCreated.compareTo(aCreated);
      }

      if (aCreated is Timestamp) {
        return -1;
      }

      if (bCreated is Timestamp) {
        return 1;
      }

      return 0;
    });

    // ==========================================================
    // DEBUG
    // ==========================================================

    debugPrint('');
    debugPrint(
      'TOTAL DISKUSI GURU + SISWA: ${result.length}',
    );

    for (final doc in result) {
      final data = doc.data();

      debugPrint(
        '------------------------------------------',
      );

      debugPrint(
        'Document ID : ${doc.id}',
      );

      debugPrint(
        'userId      : ${data['userId']}',
      );

      debugPrint(
        'teacherId   : ${data['teacherId']}',
      );

      debugPrint(
        'username    : ${data['username']}',
      );

      debugPrint(
        'title       : ${data['title']}',
      );

      debugPrint(
        'subject     : ${data['subject']}',
      );

      debugPrint(
        'classId     : ${data['classId']}',
      );

      debugPrint(
        'className   : ${data['className']}',
      );
    }

    debugPrint('==========================================');
    debugPrint('');

    return result;
  }

  // ============================================================
  // OPEN DISCUSSION DETAIL
  //
  // Khususnya digunakan untuk membuka diskusi siswa.
  // Guru dapat membalas melalui komentar.
  // ============================================================

  Future<void> _openDiscussionDetail(
      String discussionId,
      Map<String, dynamic> data,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherDiscussionDetailScreen(
          discussionId: discussionId,
          discussionData: data,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    setState(() {});
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    await _loadTeacherData();

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // OPEN FORM
  // ============================================================

  Future<void> _openDiscussionForm({
    String? discussionId,
    Map<String, dynamic>? discussionData,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherDiscussionFormScreen(
          discussionId: discussionId,
          discussionData: discussionData,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result == true) {
      setState(() {});

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              discussionId == null
                  ? 'Diskusi berhasil ditambahkan.'
                  : 'Diskusi berhasil diperbarui.',
            ),
          ),
        );
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _openDeleteDiscussion(
      String discussionId,
      String title,
      ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherDiscussionDeleteScreen(
          discussionId: discussionId,
          title: title,
        ),
      ),
    );

    if (!mounted) {
      return;
    }

    if (result == true) {
      setState(() {});

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Diskusi berhasil dihapus.',
            ),
          ),
        );
    }
  }

  // ============================================================
  // FORMAT DATE
  // ============================================================

  String _formatDate(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) {
      return '-';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Diskusi'),
        ),
        body: const Center(
          child: Text(
            'User belum login.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diskusi'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading
                ? null
                : () async {
              setState(() {
                _loading = true;
              });

              await _loadTeacherData();

              if (mounted) {
                setState(() {
                  _loading = false;
                });
              }
            },
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      // ========================================================
      // FAB
      // ========================================================

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading
            ? null
            : () {
          _openDiscussionForm();
        },
        icon: const Icon(
          Icons.add_comment_rounded,
        ),
        label: const Text(
          'Tambah Diskusi',
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : FutureBuilder<
          List<
              QueryDocumentSnapshot<Map<String, dynamic>>>>(
        future: _getDiscussions(),
        builder: (
            context,
            snapshot,
            ) {
          // ------------------------------------------------
          // LOADING
          // ------------------------------------------------

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // ------------------------------------------------
          // ERROR
          // ------------------------------------------------

          if (snapshot.hasError) {
            return _buildErrorState(
              snapshot.error.toString(),
            );
          }

          // ------------------------------------------------
          // DATA
          // ------------------------------------------------

          final docs = snapshot.data ?? [];

          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          // ------------------------------------------------
          // LIST
          // ------------------------------------------------

          return RefreshIndicator(
            onRefresh: _refresh,
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
              itemBuilder: (
                  context,
                  index,
                  ) {
                final doc = docs[index];

                return _buildDiscussionCard(
                  doc.id,
                  doc.data(),
                );
              },
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Gagal memuat diskusi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {});
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

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum ada diskusi',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada diskusi pada kelas '
                  'yang diajar oleh guru ini.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            if (_teacherDocumentId != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Teacher ID: $_teacherDocumentId',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                _openDiscussionForm();
              },
              icon: const Icon(
                Icons.add_comment_rounded,
              ),
              label: const Text(
                'Buat Diskusi',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DISCUSSION CARD
  // ============================================================

  Widget _buildDiscussionCard(
      String discussionId,
      Map<String, dynamic> data,
      ) {
    final title = data['title']?.toString().trim();

    final content = data['content']?.toString().trim();

    final subject = data['subject']?.toString().trim();

    final className = data['className']?.toString().trim();

    final classId = data['classId']?.toString().trim();

    final username = data['username']?.toString().trim();

    final userId = data['userId']?.toString().trim();

    final teacherId = data['teacherId']?.toString().trim();

    final createdAt = _formatDate(
      data['createdAt'],
    );

    final displayTitle =
    title == null || title.isEmpty
        ? 'Tanpa Judul'
        : title;

    final displayContent =
    content == null || content.isEmpty
        ? 'Tidak ada isi diskusi.'
        : content;

    final displaySubject =
    subject == null || subject.isEmpty
        ? '-'
        : subject;

    final displayClass =
    className != null && className.isNotEmpty
        ? className
        : classId != null && classId.isNotEmpty
        ? classId
        : '-';

    final displayUsername =
    username != null && username.isNotEmpty
        ? username
        : _teacherName;

    // ----------------------------------------------------------
    // CEK APAKAH DISKUSI DARI GURU ATAU SISWA
    // ----------------------------------------------------------

    final isTeacherDiscussion =
        teacherId != null &&
            teacherId.isNotEmpty &&
            teacherId == _teacherDocumentId;

    final isOwnDiscussion =
        userId != null &&
            userId.isNotEmpty &&
            userId == _authUid;

    final isStudentDiscussion =
    !isTeacherDiscussion;

    final theme = Theme.of(context);

    // ==========================================================
    // CARD
    //
    // Jika diskusi siswa:
    // seluruh card bisa ditekan untuk membuka detail.
    //
    // Jika diskusi guru:
    // tetap berupa card biasa karena edit/hapus menggunakan menu.
    // ==========================================================

    final card = Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // ====================================================
            // HEADER
            // ====================================================

            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme
                        .colorScheme
                        .primary
                        .withValues(
                      alpha: 0.12,
                    ),
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isStudentDiscussion
                        ? Icons.person_rounded
                        : Icons.forum_rounded,
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
                        displayTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        displayUsername,
                        style: TextStyle(
                          color:
                          Colors.grey.shade700,
                          fontWeight:
                          FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        displaySubject,
                        style: TextStyle(
                          color:
                          Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Kelas: $displayClass',
                        style: TextStyle(
                          color:
                          Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                // =================================================
                // MENU
                //
                // Guru tetap bisa edit/hapus
                // diskusi buatannya.
                //
                // Diskusi siswa tidak diberikan
                // menu edit/hapus.
                // =================================================

                if (isTeacherDiscussion ||
                    isOwnDiscussion)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openDiscussionForm(
                          discussionId:
                          discussionId,
                          discussionData:
                          data,
                        );
                      }

                      if (value == 'delete') {
                        _openDeleteDiscussion(
                          discussionId,
                          displayTitle,
                        );
                      }
                    },
                    itemBuilder:
                        (context) => const [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_rounded,
                            ),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_rounded,
                              color: Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text('Hapus'),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // ====================================================
            // LABEL SISWA / GURU
            // ====================================================

            if (isStudentDiscussion)
              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                  Colors.orange.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius:
                  BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.school_rounded,
                      size: 16,
                      color:
                      Colors.orange.shade700,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Diskusi Siswa',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                        FontWeight.w600,
                        color:
                        Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme
                      .colorScheme
                      .primary
                      .withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                  BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 16,
                      color: theme
                          .colorScheme
                          .primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Diskusi Guru',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                        FontWeight.w600,
                        color: theme
                            .colorScheme
                            .primary,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),

            // ====================================================
            // CONTENT
            // ====================================================

            Text(
              displayContent,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 14),

            // ====================================================
            // INFO
            // ====================================================

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(
                  Icons.class_rounded,
                  displayClass,
                ),
                _infoChip(
                  Icons.menu_book_rounded,
                  displaySubject,
                ),
                _infoChip(
                  Icons.access_time_rounded,
                  createdAt,
                ),
                if (isOwnDiscussion)
                  _infoChip(
                    Icons.person_rounded,
                    'Data saya',
                  ),
                if (isTeacherDiscussion)
                  _infoChip(
                    Icons.verified_user_rounded,
                    'Data guru',
                  ),
              ],
            ),

            // ====================================================
            // PETUNJUK UNTUK DISKUSI SISWA
            // ====================================================

            if (isStudentDiscussion) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 17,
                    color:
                    theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Ketuk untuk melihat dan membalas',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                      FontWeight.w500,
                      color:
                      theme.colorScheme.primary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    // ==========================================================
    // STUDENT DISCUSSION = CLICKABLE
    // ==========================================================

    if (isStudentDiscussion) {
      return InkWell(
        onTap: () {
          _openDiscussionDetail(
            discussionId,
            data,
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }

  // ============================================================
  // INFO CHIP
  // ============================================================

  Widget _infoChip(
      IconData icon,
      String text,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(
          alpha: 0.10,
        ),
        borderRadius:
        BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }
}