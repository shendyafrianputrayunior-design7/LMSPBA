
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
  String? _teacherError;

  late Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _discussionsFuture;

  @override
  void initState() {
    super.initState();
    _discussionsFuture = Future.value([]);
    _initialize();
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> _initialize() async {
    await _loadTeacherData();

    if (!mounted) return;

    setState(() {
      _discussionsFuture = _getDiscussions();
      _loading = false;
    });
  }

  // ============================================================
  // GET TEACHER DOCUMENT ID
  //
  // 1. users/{uid}.teacherId
  // 2. Fallback: teachers.email
  //
  // Teacher ID menggunakan ID dokumen pada koleksi teachers,
  // misalnya teacher_001, teacher_002, dan seterusnya.
  // ============================================================

  Future<String?> _getTeacherDocumentId() async {
    final user = _auth.currentUser;

    if (user == null) return null;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final savedTeacherId =
      userDoc.data()?['teacherId']?.toString().trim();

      debugPrint(
        'users/${user.uid}.teacherId = $savedTeacherId',
      );

      if (savedTeacherId != null && savedTeacherId.isNotEmpty) {
        final teacherDoc = await _firestore
            .collection('teachers')
            .doc(savedTeacherId)
            .get();

        if (teacherDoc.exists) {
          return savedTeacherId;
        }
      }
    } catch (e) {
      debugPrint('Gagal membaca teacherId dari users: $e');
    }

    try {
      final email = user.email?.trim();

      if (email != null && email.isNotEmpty) {
        final result = await _firestore
            .collection('teachers')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (result.docs.isNotEmpty) {
          return result.docs.first.id;
        }
      }
    } catch (e) {
      debugPrint('Gagal mencari guru berdasarkan email: $e');
    }

    return null;
  }

  // ============================================================
  // LOAD TEACHER DATA
  // ============================================================

  Future<void> _loadTeacherData() async {
    final user = _auth.currentUser;

    if (user == null) {
      _authUid = null;
      _teacherDocumentId = null;
      _teacherError = 'User belum login.';
      return;
    }

    _authUid = user.uid;
    _teacherError = null;

    debugPrint('==========================================');
    debugPrint('TEACHER DISCUSSIONS');
    debugPrint('AUTH UID: ${user.uid}');
    debugPrint('EMAIL: ${user.email}');

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      _teacherName = (
          userData['name'] ??
              userData['username'] ??
              userData['displayName'] ??
              user.displayName ??
              'Guru'
      ).toString().trim();

      if (_teacherName.isEmpty) {
        _teacherName = 'Guru';
      }

      _teacherDocumentId = await _getTeacherDocumentId();

      debugPrint('TEACHER ID: $_teacherDocumentId');
      debugPrint('TEACHER NAME: $_teacherName');

      if (_teacherDocumentId == null) {
        _teacherError =
        'ID guru tidak ditemukan. Periksa users.teacherId '
            'atau email pada koleksi teachers.';
      }
    } catch (e) {
      _teacherError = 'Gagal memuat data guru: $e';
      debugPrint(_teacherError);
    }

    debugPrint('==========================================');
  }

  // ============================================================
  // GET TEACHER CLASS IDS
  //
  // Mengambil classId dari courses milik guru.
  // UID tetap digunakan untuk mendukung data lama.
  // ============================================================

  Future<Set<String>> _getTeacherClassIds() async {
    final Set<String> classIds = {};

    final teacherId = _teacherDocumentId;
    final authUid = _authUid;

    Future<void> loadCoursesByTeacherId(String id) async {
      try {
        final snapshot = await _firestore
            .collection('courses')
            .where('teacherId', isEqualTo: id)
            .get();

        debugPrint(
          'Courses teacherId=$id: ${snapshot.docs.length}',
        );

        for (final doc in snapshot.docs) {
          final data = doc.data();

          final classId = data['classId']?.toString().trim();

          if (classId != null && classId.isNotEmpty) {
            classIds.add(classId);
          }
        }
      } catch (e) {
        debugPrint('Gagal mengambil courses untuk $id: $e');
      }
    }

    if (teacherId != null && teacherId.isNotEmpty) {
      await loadCoursesByTeacherId(teacherId);
    }

    if (authUid != null &&
        authUid.isNotEmpty &&
        authUid != teacherId) {
      await loadCoursesByTeacherId(authUid);
    }

    debugPrint('TOTAL KELAS GURU: ${classIds.length}');
    debugPrint('CLASS IDS: $classIds');

    return classIds;
  }

  // ============================================================
  // GET DISCUSSIONS
  //
  // Menggabungkan:
  // 1. Diskusi dengan teacherId milik guru.
  // 2. Diskusi dengan userId berupa UID guru.
  // 3. Diskusi siswa dari kelas yang diajar guru.
  // ============================================================

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _getDiscussions() async {
    final user = _auth.currentUser;

    if (user == null) return [];

    final Map<
        String,
        QueryDocumentSnapshot<Map<String, dynamic>>> discussions = {};

    Future<void> addQueryResults(
        Query<Map<String, dynamic>> query,
        String description,
        ) async {
      try {
        final snapshot = await query.get();

        debugPrint('$description: ${snapshot.docs.length} dokumen');

        for (final doc in snapshot.docs) {
          discussions[doc.id] = doc;
        }
      } catch (e) {
        debugPrint('Gagal menjalankan $description: $e');
      }
    }

    // ------------------------------------------------------------
    // 1. Diskusi milik guru berdasarkan teacherId
    // ------------------------------------------------------------

    final teacherId = _teacherDocumentId;

    if (teacherId != null && teacherId.isNotEmpty) {
      await addQueryResults(
        _firestore
            .collection('discussions')
            .where('teacherId', isEqualTo: teacherId),
        'Diskusi berdasarkan teacherId',
      );
    }

    // ------------------------------------------------------------
    // 2. Diskusi guru lama berdasarkan userId
    // ------------------------------------------------------------

    await addQueryResults(
      _firestore
          .collection('discussions')
          .where('userId', isEqualTo: user.uid),
      'Diskusi berdasarkan userId',
    );

    // ------------------------------------------------------------
    // 3. Diskusi siswa berdasarkan classId kelas guru
    // ------------------------------------------------------------

    final classIds = (await _getTeacherClassIds()).toList();

    // Batas whereIn Firestore saat ini maksimal 30 nilai.
    const batchSize = 30;

    for (int start = 0; start < classIds.length; start += batchSize) {
      final end = (start + batchSize < classIds.length)
          ? start + batchSize
          : classIds.length;

      final batch = classIds.sublist(start, end);

      await addQueryResults(
        _firestore
            .collection('discussions')
            .where('classId', whereIn: batch),
        'Diskusi berdasarkan classId $batch',
      );
    }

    // ------------------------------------------------------------
    // SORT BERDASARKAN CREATED AT TERBARU
    // ------------------------------------------------------------

    final result = discussions.values.toList();

    result.sort((a, b) {
      final aCreated = a.data()['createdAt'];
      final bCreated = b.data()['createdAt'];

      if (aCreated is Timestamp && bCreated is Timestamp) {
        return bCreated.compareTo(aCreated);
      }

      if (aCreated is Timestamp) return -1;
      if (bCreated is Timestamp) return 1;

      return 0;
    });

    debugPrint('TOTAL DISKUSI: ${result.length}');

    for (final doc in result) {
      final data = doc.data();

      debugPrint(
        'ID=${doc.id}, '
            'userId=${data['userId']}, '
            'teacherId=${data['teacherId']}, '
            'classId=${data['classId']}, '
            'title=${data['title']}',
      );
    }

    return result;
  }

  // ============================================================
  // REFRESH DATA
  // ============================================================

  Future<void> _refresh() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    await _loadTeacherData();

    if (!mounted) return;

    setState(() {
      _discussionsFuture = _getDiscussions();
      _loading = false;
    });

    await _discussionsFuture;
  }

  // ============================================================
  // OPEN DISCUSSION DETAIL
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

    if (!mounted) return;

    setState(() {
      _discussionsFuture = _getDiscussions();
    });
  }

  // ============================================================
  // OPEN FORM
  // ============================================================

  Future<void> _openDiscussionForm({
    String? discussionId,
    Map<String, dynamic>? discussionData,
  }) async {
    if (_teacherDocumentId == null) {
      _showMessage(
        _teacherError ??
            'ID guru belum ditemukan. Tidak dapat membuka form.',
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherDiscussionFormScreen(
          discussionId: discussionId,
          discussionData: discussionData,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      setState(() {
        _discussionsFuture = _getDiscussions();
      });

      _showMessage(
        discussionId == null
            ? 'Diskusi berhasil ditambahkan.'
            : 'Diskusi berhasil diperbarui.',
      );
    }
  }

  // ============================================================
  // DELETE DISCUSSION
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

    if (!mounted) return;

    if (result == true) {
      setState(() {
        _discussionsFuture = _getDiscussions();
      });

      _showMessage('Diskusi berhasil dihapus.');
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message)),
      );
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

    if (date == null) return '-';

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
        appBar: AppBar(title: const Text('Diskusi')),
        body: const Center(child: Text('User belum login.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diskusi'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : () => _openDiscussionForm(),
        icon: const Icon(Icons.add_comment_rounded),
        label: const Text('Tambah Diskusi'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _teacherDocumentId == null
          ? _buildTeacherErrorState()
          : FutureBuilder<
          List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
        future: _discussionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _buildErrorState(
              snapshot.error.toString(),
            );
          }

          final docs = snapshot.data ?? [];

          if (docs.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                100,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
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
  // TEACHER ERROR STATE
  // ============================================================

  Widget _buildTeacherErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 64,
              color: Colors.orange.shade700,
            ),
            const SizedBox(height: 16),
            const Text(
              'Data guru tidak ditemukan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _teacherError ??
                  'Pastikan akun terhubung ke dokumen guru.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // GENERAL ERROR STATE
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
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _discussionsFuture = _getDiscussions();
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba Lagi'),
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
              'Belum ada diskusi pada kelas yang diajar '
                  'oleh $_teacherName.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.10),
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
              onPressed: () => _openDiscussionForm(),
              icon: const Icon(Icons.add_comment_rounded),
              label: const Text('Buat Diskusi'),
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

    final displayTitle =
    title == null || title.isEmpty ? 'Tanpa Judul' : title;

    final displayContent = content == null || content.isEmpty
        ? 'Tidak ada isi diskusi.'
        : content;

    final displaySubject =
    subject == null || subject.isEmpty ? '-' : subject;

    final displayClass =
    className != null && className.isNotEmpty
        ? className
        : classId != null && classId.isNotEmpty
        ? classId
        : '-';

    final displayUsername =
    username != null && username.isNotEmpty
        ? username
        : 'Pengguna';

    final createdAt = _formatDate(data['createdAt']);

    // Diskusi guru dikenali dari teacherId atau UID pembuat.
    final isOwnDiscussion =
        userId != null &&
            userId.isNotEmpty &&
            userId == _authUid;

    final isTeacherDiscussion =
        (teacherId != null &&
            teacherId.isNotEmpty &&
            teacherId == _teacherDocumentId) ||
            isOwnDiscussion;

    final isStudentDiscussion = !isTeacherDiscussion;
    final theme = Theme.of(context);

    final card = Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(
                      alpha: 0.12,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isStudentDiscussion
                        ? Icons.person_rounded
                        : Icons.forum_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        displayUsername,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        displaySubject,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Kelas: $displayClass',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),

                // MENU HANYA UNTUK DISKUSI GURU SENDIRI
                if (isOwnDiscussion ||
                    (teacherId != null &&
                        teacherId.isNotEmpty &&
                        teacherId == _teacherDocumentId))
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _openDiscussionForm(
                          discussionId: discussionId,
                          discussionData: data,
                        );
                      } else if (value == 'delete') {
                        _openDeleteDiscussion(
                          discussionId,
                          displayTitle,
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded),
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

            // LABEL
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: isStudentDiscussion
                    ? Colors.orange.withValues(alpha: 0.12)
                    : theme.colorScheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isStudentDiscussion
                        ? Icons.school_rounded
                        : Icons.verified_user_rounded,
                    size: 16,
                    color: isStudentDiscussion
                        ? Colors.orange.shade700
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isStudentDiscussion
                        ? 'Diskusi Siswa'
                        : 'Diskusi Guru',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isStudentDiscussion
                          ? Colors.orange.shade700
                          : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // CONTENT
            Text(
              displayContent,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 14),

            // INFORMATION CHIPS
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(Icons.class_rounded, displayClass),
                _infoChip(Icons.menu_book_rounded, displaySubject),
                _infoChip(Icons.access_time_rounded, createdAt),
                if (isOwnDiscussion)
                  _infoChip(Icons.person_rounded, 'Data saya'),
                if (isTeacherDiscussion)
                  _infoChip(Icons.verified_user_rounded, 'Data guru'),
              ],
            ),

            if (isStudentDiscussion) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 17,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Ketuk untuk melihat dan membalas',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
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

    // DISKUSI SISWA DAPAT DIBUKA UNTUK MEMBACA/MEMBALAS.
    if (isStudentDiscussion) {
      return InkWell(
        onTap: () => _openDiscussionDetail(discussionId, data),
        borderRadius: BorderRadius.circular(12),
        child: card,
      );
    }

    return card;
  }

  // ============================================================
  // INFO CHIP
  // ============================================================

  Widget _infoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
    );
  }
}
