import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class DiscussionScreen extends StatefulWidget {
  const DiscussionScreen({super.key});

  @override
  State<DiscussionScreen> createState() => _DiscussionScreenState();
}

class _DiscussionScreenState extends State<DiscussionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _classId = '';
  String _className = '';
  String _userId = '';

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  // ============================================================
  // LOAD STUDENT DATA
  // ============================================================

  Future<void> _loadStudentData() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Pengguna belum login.');
      }

      _userId = user.uid;

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('Data pengguna tidak ditemukan.');
      }

      final userData = userDoc.data() ?? {};

      final classId = (userData['classId'] ?? '').toString();

      if (classId.isEmpty) {
        throw Exception(
          'Data kelas belum tersedia. Silakan lengkapi classId pada profil siswa.',
        );
      }

      String className = classId;

      final classDoc = await _firestore
          .collection('classes')
          .doc(classId)
          .get();

      if (classDoc.exists) {
        final classData = classDoc.data() ?? {};

        className = (classData['name'] ?? classId).toString();
      }

      if (!mounted) return;

      setState(() {
        _classId = classId;
        _className = className;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    await _loadStudentData();
  }

  // ============================================================
  // CREATE DISCUSSION
  // ============================================================

  Future<void> _createDiscussion() async {
    if (_classId.isEmpty || _userId.isEmpty) {
      return;
    }

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (_) => const _CreateDiscussionDialog(),
    );

    if (result == null) return;

    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Pengguna belum login.');
      }

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      final username = (userData['username'] ??
          userData['name'] ??
          user.displayName ??
          'Siswa')
          .toString();

      await _firestore.collection('discussions').add({
        'classId': _classId,
        'userId': user.uid,
        'username': username,
        'title': result['title'] ?? '',
        'content': result['content'] ?? '',
        'subject': result['subject'] ?? '',
        'type': 'student',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diskusi berhasil dibuat.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal membuat diskusi: '
                '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  // ============================================================
  // EDIT DISCUSSION
  // ============================================================

  Future<void> _editDiscussion(
      String discussionId,
      Map<String, dynamic> data,
      ) async {
    final discussionUserId = (data['userId'] ?? '').toString();

    final teacherId = (data['teacherId'] ?? '').toString();

    // ----------------------------------------------------------
    // SECURITY CHECK
    // ----------------------------------------------------------
    // Diskusi guru tidak boleh diedit siswa.
    if (teacherId.isNotEmpty) {
      return;
    }

    // Siswa hanya boleh mengedit diskusi miliknya.
    if (_userId.isEmpty || discussionUserId != _userId) {
      return;
    }

    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (_) => _EditDiscussionDialog(
        initialTitle: (data['title'] ?? '').toString(),
        initialSubject: (data['subject'] ?? '').toString(),
        initialContent: (data['content'] ?? '').toString(),
      ),
    );

    if (result == null) return;

    try {
      await _firestore
          .collection('discussions')
          .doc(discussionId)
          .update({
        'title': result['title'] ?? '',
        'subject': result['subject'] ?? '',
        'content': result['content'] ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diskusi berhasil diperbarui.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memperbarui diskusi: '
                '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  // ============================================================
  // DELETE DISCUSSION
  // ============================================================

  Future<void> _deleteDiscussion(
      String discussionId,
      Map<String, dynamic> data,
      ) async {
    final discussionUserId = (data['userId'] ?? '').toString();

    final teacherId = (data['teacherId'] ?? '').toString();

    // ----------------------------------------------------------
    // SECURITY CHECK
    // ----------------------------------------------------------

    // Diskusi guru tidak boleh dihapus siswa.
    if (teacherId.isNotEmpty) {
      return;
    }

    // Siswa hanya boleh menghapus diskusi miliknya.
    if (_userId.isEmpty || discussionUserId != _userId) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          title: const Text(
            'Hapus Diskusi?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Diskusi dan seluruh komentar di dalamnya '
                'akan dihapus. Tindakan ini tidak dapat '
                'dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
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

    try {
      // --------------------------------------------------------
      // DELETE ALL COMMENTS
      // --------------------------------------------------------

      final commentsSnapshot = await _firestore
          .collection('discussion_comments')
          .where(
        'discussionId',
        isEqualTo: discussionId,
      )
          .get();

      final batch = _firestore.batch();

      for (final comment in commentsSnapshot.docs) {
        batch.delete(comment.reference);
      }

      // --------------------------------------------------------
      // DELETE DISCUSSION
      // --------------------------------------------------------

      batch.delete(
        _firestore
            .collection('discussions')
            .doc(discussionId),
      );

      await batch.commit();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Diskusi berhasil dihapus.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus diskusi: '
                '${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  // ============================================================
  // OPEN DISCUSSION
  // ============================================================

  void _openDiscussion(
      String discussionId,
      Map<String, dynamic> data,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiscussionDetailScreen(
          discussionId: discussionId,
          discussionData: data,
          currentUserId: _userId,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Discussions',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      floatingActionButton: !_loading && _error == null
          ? FloatingActionButton.extended(
        onPressed: _createDiscussion,
        icon: const Icon(
          Icons.add_comment_outlined,
        ),
        label: const Text('Diskusi'),
      )
          : null,
      body: _buildBody(
        theme,
        colorScheme,
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody(
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _buildErrorState(
        theme,
        colorScheme,
      );
    }

    if (_classId.isEmpty) {
      return _buildEmptyClassState(theme);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('discussions')
          .where(
        'classId',
        isEqualTo: _classId,
      )
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(
            theme,
            colorScheme,
            message: snapshot.error.toString(),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final docs = [
          ...(snapshot.data?.docs ?? []),
        ];

        // --------------------------------------------------------
        // SORT NEWEST FIRST
        // --------------------------------------------------------

        docs.sort((a, b) {
          final aTime = a.data()['createdAt'];
          final bTime = b.data()['createdAt'];

          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime);
          }

          if (aTime is Timestamp) return -1;
          if (bTime is Timestamp) return 1;

          return 0;
        });

        if (docs.isEmpty) {
          return _buildEmptyState(
            theme,
            colorScheme,
          );
        }

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              100,
            ),
            children: [
              _buildHeader(
                theme,
                colorScheme,
              ),
              const SizedBox(height: 16),
              ...docs.map((doc) {
                final data = doc.data();

                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 12,
                  ),
                  child: _buildDiscussionCard(
                    theme,
                    colorScheme,
                    doc.id,
                    data,
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withValues(
            alpha: 0.12,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.forum_rounded,
              color: colorScheme.primary,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Forum Diskusi',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _className.isEmpty
                      ? 'Diskusi kelas'
                      : 'Kelas $_className',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISCUSSION CARD
  // ============================================================

  Widget _buildDiscussionCard(
      ThemeData theme,
      ColorScheme colorScheme,
      String discussionId,
      Map<String, dynamic> data,
      ) {
    final userId = (data['userId'] ?? '').toString();

    final teacherId = (data['teacherId'] ?? '').toString();

    final username = (data['username'] ?? '').toString();

    final teacherName = (data['teacherName'] ?? '').toString();

    final title = (data['title'] ?? 'Tanpa judul').toString();

    final content = (data['content'] ?? '').toString();

    final subject = (data['subject'] ?? '').toString();

    final courseName = (data['courseName'] ?? '').toString();

    final isTeacher = teacherId.isNotEmpty;

    // ----------------------------------------------------------
    // OWNER CHECK
    // ----------------------------------------------------------

    final isOwner = !isTeacher && userId == _userId;

    String authorName;

    if (isTeacher) {
      authorName = teacherName.isNotEmpty ? teacherName : 'Guru';
    } else {
      authorName = username.isNotEmpty ? username : 'Siswa';
    }

    String category;

    if (isTeacher) {
      category = courseName.isNotEmpty
          ? courseName
          : 'Pengumuman Guru';
    } else {
      category = subject.isNotEmpty
          ? subject
          : 'Diskusi Siswa';
    }

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _openDiscussion(
            discussionId,
            data,
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            8,
            16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------------------------------------------------
              // TITLE + OWNER MENU
              // ------------------------------------------------

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: isTeacher
                                ? Colors.orange.withValues(
                              alpha: 0.12,
                            )
                                : colorScheme.primary.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isTeacher
                                ? Icons.school_rounded
                                : Icons.person_outline_rounded,
                            size: 21,
                            color: isTeacher
                                ? Colors.orange
                                : colorScheme.primary,
                          ),
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ------------------------------------------------
                  // EDIT + DELETE MENU
                  // ------------------------------------------------

                  if (isOwner)
                    PopupMenuButton<String>(
                      tooltip: 'Menu',
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editDiscussion(
                            discussionId,
                            data,
                          );
                        }

                        if (value == 'delete') {
                          _deleteDiscussion(
                            discussionId,
                            data,
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
                                Text(
                                  'Edit Diskusi',
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem<String>(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.red,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Hapus Diskusi',
                                ),
                              ],
                            ),
                          ),
                        ];
                      },
                    ),
                ],
              ),

              const SizedBox(height: 12),

              // ------------------------------------------------
              // AUTHOR
              // ------------------------------------------------

              Row(
                children: [
                  Icon(
                    isTeacher
                        ? Icons.school_outlined
                        : Icons.person_outline_rounded,
                    size: 16,
                    color: isTeacher
                        ? Colors.orange
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Text(
                    isTeacher
                        ? 'Guru: $authorName'
                        : authorName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isTeacher
                          ? Colors.orange
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ------------------------------------------------
              // CONTENT
              // ------------------------------------------------

              Text(
                content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.45,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 14),

              // ------------------------------------------------
              // TAG
              // ------------------------------------------------

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTag(
                    colorScheme,
                    isTeacher
                        ? Icons.school_outlined
                        : Icons.book_outlined,
                    category,
                    isTeacher: isTeacher,
                  ),
                  _buildTag(
                    colorScheme,
                    Icons.class_outlined,
                    _className.isEmpty
                        ? _classId
                        : _className,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ------------------------------------------------
              // OPEN DISCUSSION
              // ------------------------------------------------

              Row(
                children: [
                  Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 17,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Text(
                    'Buka diskusi',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TAG
  // ============================================================

  Widget _buildTag(
      ColorScheme colorScheme,
      IconData icon,
      String text, {
        bool isTeacher = false,
      }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: isTeacher
            ? Colors.orange.withValues(
          alpha: 0.10,
        )
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isTeacher
                ? Colors.orange
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isTeacher
                  ? Colors.orange
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
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
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.forum_outlined,
            size: 72,
            color: colorScheme.onSurfaceVariant.withValues(
              alpha: 0.5,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Belum Ada Diskusi',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Belum ada topik diskusi untuk '
                'kelas $_className. '
                'Buat diskusi pertama untuk memulai.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY CLASS
  // ============================================================

  Widget _buildEmptyClassState(
      ThemeData theme,
      ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Data kelas belum tersedia.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState(
      ThemeData theme,
      ColorScheme colorScheme, {
        String? message,
      }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Terjadi Kesalahan',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message ??
                  _error ??
                  'Tidak dapat memuat data.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(
                Icons.refresh_rounded,
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

// ============================================================
// CREATE DISCUSSION DIALOG
// ============================================================

class _CreateDiscussionDialog extends StatefulWidget {
  const _CreateDiscussionDialog();

  @override
  State<_CreateDiscussionDialog> createState() =>
      _CreateDiscussionDialogState();
}

class _CreateDiscussionDialogState
    extends State<_CreateDiscussionDialog> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _subjectController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop({
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'subject': _subjectController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Buat Diskusi',
        style: TextStyle(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Judul Diskusi',
                  hintText: 'Contoh: Tanya tentang Flutter',
                  prefixIcon: Icon(
                    Icons.title_rounded,
                  ),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Judul wajib diisi';
                  }

                  if (value.trim().length < 3) {
                    return 'Judul terlalu pendek';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              TextFormField(
                controller: _subjectController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Mata Pelajaran',
                  hintText: 'Contoh: Pemrograman Mobile',
                  prefixIcon: Icon(
                    Icons.book_outlined,
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

              TextFormField(
                controller: _contentController,
                minLines: 4,
                maxLines: 7,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Isi Diskusi',
                  hintText:
                  'Tulis pertanyaan atau topik diskusi...',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(
                      bottom: 70,
                    ),
                    child: Icon(
                      Icons.chat_outlined,
                    ),
                  ),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Isi diskusi wajib diisi';
                  }

                  if (value.trim().length < 5) {
                    return 'Isi diskusi terlalu pendek';
                  }

                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(
            Icons.send_rounded,
          ),
          label: const Text('Buat'),
        ),
      ],
    );
  }
}

// ============================================================
// EDIT DISCUSSION DIALOG
// ============================================================

class _EditDiscussionDialog extends StatefulWidget {
  final String initialTitle;
  final String initialSubject;
  final String initialContent;

  const _EditDiscussionDialog({
    required this.initialTitle,
    required this.initialSubject,
    required this.initialContent,
  });

  @override
  State<_EditDiscussionDialog> createState() =>
      _EditDiscussionDialogState();
}

class _EditDiscussionDialogState
    extends State<_EditDiscussionDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _subjectController;
  late final TextEditingController _contentController;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.initialTitle,
    );

    _subjectController = TextEditingController(
      text: widget.initialSubject,
    );

    _contentController = TextEditingController(
      text: widget.initialContent,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // ============================================================
  // SUBMIT EDIT
  // ============================================================

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    Navigator.of(context).pop({
      'title': _titleController.text.trim(),
      'subject': _subjectController.text.trim(),
      'content': _contentController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Edit Diskusi',
        style: TextStyle(
          fontWeight: FontWeight.w800,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ------------------------------------------------
              // TITLE
              // ------------------------------------------------

              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Judul Diskusi',
                  prefixIcon: Icon(
                    Icons.title_rounded,
                  ),
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Judul wajib diisi';
                  }

                  if (value.trim().length < 3) {
                    return 'Judul terlalu pendek';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 14),

              // ------------------------------------------------
              // SUBJECT
              // ------------------------------------------------

              TextFormField(
                controller: _subjectController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Mata Pelajaran',
                  prefixIcon: Icon(
                    Icons.book_outlined,
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

              // ------------------------------------------------
              // CONTENT
              // ------------------------------------------------

              TextFormField(
                controller: _contentController,
                minLines: 4,
                maxLines: 8,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Isi Diskusi',
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(
                      bottom: 70,
                    ),
                    child: Icon(
                      Icons.chat_outlined,
                    ),
                  ),
                  alignLabelWithHint: true,
                ),
                validator: (value) {
                  if (value == null ||
                      value.trim().isEmpty) {
                    return 'Isi diskusi wajib diisi';
                  }

                  if (value.trim().length < 5) {
                    return 'Isi diskusi terlalu pendek';
                  }

                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(
            Icons.save_outlined,
          ),
          label: const Text(
            'Simpan Perubahan',
          ),
        ),
      ],
    );
  }
}

// ============================================================
// DISCUSSION DETAIL
// ============================================================

class DiscussionDetailScreen extends StatefulWidget {
  final String discussionId;
  final Map<String, dynamic> discussionData;
  final String currentUserId;

  const DiscussionDetailScreen({
    super.key,
    required this.discussionId,
    required this.discussionData,
    required this.currentUserId,
  });

  @override
  State<DiscussionDetailScreen> createState() =>
      _DiscussionDetailScreenState();
}

class _DiscussionDetailScreenState
    extends State<DiscussionDetailScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final _commentController =
  TextEditingController();

  bool _sendingComment = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ============================================================
  // SEND COMMENT
  // ============================================================

  Future<void> _sendComment() async {
    final comment = _commentController.text.trim();

    if (comment.isEmpty || _sendingComment) {
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    setState(() {
      _sendingComment = true;
    });

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data() ?? {};

      final username = (userData['username'] ??
          userData['name'] ??
          user.displayName ??
          'Siswa')
          .toString();

      await _firestore
          .collection('discussion_comments')
          .add({
        'discussionId': widget.discussionId,
        'userId': user.uid,
        'username': username,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengirim komentar: '
                '${e.toString().replaceFirst(
              'Exception: ',
              '',
            )}',
          ),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _sendingComment = false;
      });
    }
  }

  // ============================================================
  // DELETE COMMENT
  // ============================================================

  Future<void> _deleteComment(
      String commentId,
      String commentUserId,
      ) async {
    if (commentUserId != widget.currentUserId) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (
          dialogContext,
          ) {
        final theme = Theme.of(dialogContext);

        final colorScheme = theme.colorScheme;

        return AlertDialog(
          title: const Text(
            'Hapus Komentar?',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Komentar ini akan dihapus '
                'dan tidak dapat dikembalikan.',
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
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
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

    if (confirmed != true) {
      return;
    }

    try {
      await _firestore
          .collection('discussion_comments')
          .doc(commentId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Komentar berhasil dihapus.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus komentar: '
                '${e.toString().replaceFirst(
              'Exception: ',
              '',
            )}',
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUILD DETAIL
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final title = (widget.discussionData['title'] ??
        'Diskusi')
        .toString();

    final content = (widget.discussionData['content'] ?? '')
        .toString();

    final subject = (widget.discussionData['subject'] ?? '')
        .toString();

    final courseName =
    (widget.discussionData['courseName'] ?? '')
        .toString();

    final username =
    (widget.discussionData['username'] ?? '')
        .toString();

    final teacherName =
    (widget.discussionData['teacherName'] ?? '')
        .toString();

    final teacherId =
    (widget.discussionData['teacherId'] ?? '')
        .toString();

    final isTeacher = teacherId.isNotEmpty;

    final authorName = isTeacher
        ? (teacherName.isNotEmpty
        ? teacherName
        : 'Guru')
        : (username.isNotEmpty
        ? username
        : 'Siswa');

    final category = isTeacher
        ? (courseName.isNotEmpty
        ? courseName
        : 'Diskusi Guru')
        : (subject.isNotEmpty
        ? subject
        : 'Diskusi Siswa');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<
                QuerySnapshot<
                    Map<String, dynamic>>>(
              stream: _firestore
                  .collection(
                'discussion_comments',
              )
                  .where(
                'discussionId',
                isEqualTo: widget.discussionId,
              )
                  .snapshots(),
              builder: (
                  context,
                  snapshot,
                  ) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Gagal memuat komentar:\n'
                            '${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final comments = [
                  ...(snapshot.data?.docs ?? []),
                ];

                comments.sort(
                      (a, b) {
                    final aTime =
                    a.data()['createdAt'];

                    final bTime =
                    b.data()['createdAt'];

                    if (aTime is Timestamp &&
                        bTime is Timestamp) {
                      return aTime.compareTo(bTime);
                    }

                    if (aTime is Timestamp) {
                      return -1;
                    }

                    if (bTime is Timestamp) {
                      return 1;
                    }

                    return 0;
                  },
                );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    24,
                  ),
                  children: [
                    _buildMainDiscussion(
                      theme,
                      colorScheme,
                      title,
                      content,
                      category,
                      authorName,
                      isTeacher,
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    Row(
                      children: [
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 21,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Komentar (${comments.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    if (comments.isEmpty)
                      _buildNoComments(
                        theme,
                        colorScheme,
                      )
                    else
                      ...comments.map(
                            (doc) {
                          final data = doc.data();

                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: 10,
                            ),
                            child: _buildCommentCard(
                              theme,
                              colorScheme,
                              doc.id,
                              data,
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),

          _buildCommentInput(
            theme,
            colorScheme,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MAIN DISCUSSION
  // ============================================================

  Widget _buildMainDiscussion(
      ThemeData theme,
      ColorScheme colorScheme,
      String title,
      String content,
      String category,
      String authorName,
      bool isTeacher,
      ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(
            alpha: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: isTeacher
                  ? Colors.orange.withValues(
                alpha: 0.10,
              )
                  : colorScheme.primary.withValues(
                alpha: 0.10,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isTeacher
                      ? Icons.school_outlined
                      : Icons.book_outlined,
                  size: 14,
                  color: isTeacher
                      ? Colors.orange
                      : colorScheme.primary,
                ),
                const SizedBox(
                  width: 5,
                ),
                Text(
                  category,
                  style: TextStyle(
                    color: isTeacher
                        ? Colors.orange
                        : colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            content,
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: isTeacher
                    ? Colors.orange.withValues(
                  alpha: 0.12,
                )
                    : colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
                child: Icon(
                  isTeacher
                      ? Icons.school_outlined
                      : Icons.person_outline_rounded,
                  size: 19,
                  color: isTeacher
                      ? Colors.orange
                      : colorScheme.primary,
                ),
              ),
              const SizedBox(
                width: 9,
              ),
              Text(
                isTeacher
                    ? 'Guru: $authorName'
                    : authorName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMMENT CARD
  // ============================================================

  Widget _buildCommentCard(
      ThemeData theme,
      ColorScheme colorScheme,
      String commentId,
      Map<String, dynamic> data,
      ) {
    final username =
    (data['username'] ?? 'Siswa').toString();

    final comment =
    (data['comment'] ?? '').toString();

    final userId =
    (data['userId'] ?? '').toString();

    final isOwner =
        userId == widget.currentUserId;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        14,
        14,
        8,
        14,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: colorScheme.primary.withValues(
              alpha: 0.10,
            ),
            child: Icon(
              Icons.person_outline_rounded,
              size: 20,
              color: colorScheme.primary,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  username,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                Text(
                  comment,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          if (isOwner)
            PopupMenuButton<String>(
              tooltip: 'Menu',
              onSelected: (value) {
                if (value == 'delete') {
                  _deleteComment(
                    commentId,
                    userId,
                  );
                }
              },
              itemBuilder: (context) {
                return const [
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red,
                        ),
                        SizedBox(
                          width: 10,
                        ),
                        Text(
                          'Hapus Komentar',
                        ),
                      ],
                    ),
                  ),
                ];
              },
            ),
        ],
      ),
    );
  }

  // ============================================================
  // NO COMMENTS
  // ============================================================

  Widget _buildNoComments(
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 42,
            color: colorScheme.onSurfaceVariant.withValues(
              alpha: 0.5,
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          Text(
            'Belum ada komentar',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            'Jadilah yang pertama '
                'memberikan komentar.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMMENT INPUT
  // ============================================================

  Widget _buildCommentInput(
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          12,
          10,
          12,
          10,
        ),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(
                alpha: 0.5,
              ),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Tulis komentar...',
                  filled: true,
                  fillColor:
                  colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            const SizedBox(
              width: 8,
            ),

            SizedBox(
              width: 48,
              height: 48,
              child: FilledButton(
                onPressed:
                _sendingComment
                    ? null
                    : _sendComment,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _sendingComment
                    ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(
                  Icons.send_rounded,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}