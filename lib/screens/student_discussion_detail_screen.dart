import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StudentDiscussionDetailScreen extends StatefulWidget {
  final String discussionId;
  final Map<String, dynamic> discussionData;

  const StudentDiscussionDetailScreen({
    super.key,
    required this.discussionId,
    required this.discussionData,
  });

  @override
  State<StudentDiscussionDetailScreen> createState() =>
      _StudentDiscussionDetailScreenState();
}

class _StudentDiscussionDetailScreenState
    extends State<StudentDiscussionDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _commentController = TextEditingController();

  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ============================================================
  // HELPER
  // ============================================================

  String _getString(
      String key, [
        String fallback = '-',
      ]) {
    final value = widget.discussionData[key];

    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }

    return value.toString();
  }

  DateTime _getDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime(2000);
    }

    return DateTime(2000);
  }

  String _formatDate(DateTime date) {
    if (date.year <= 2000) {
      return '-';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year • $hour:$minute';
  }

  // ============================================================
  // AMBIL DATA USER
  // ============================================================

  Future<Map<String, dynamic>> _getCurrentUserData() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Pengguna belum login.');
    }

    final userDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    return userDoc.data() ?? {};
  }

  String _getUserName(
      Map<String, dynamic> userData,
      User user,
      ) {
    final name =
        userData['username'] ??
            userData['name'] ??
            userData['displayName'] ??
            user.displayName;

    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString().trim();
    }

    return 'Pengguna';
  }

  String _getUserRole(Map<String, dynamic> userData) {
    final role = userData['role']?.toString().trim().toLowerCase();

    if (role == 'teacher' ||
        role == 'guru') {
      return 'teacher';
    }

    if (role == 'admin') {
      return 'admin';
    }

    return 'student';
  }

  // ============================================================
  // KIRIM KOMENTAR
  // ============================================================

  Future<void> _sendComment() async {
    final content = _commentController.text.trim();

    if (content.isEmpty) {
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kamu belum login.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final userData = await _getCurrentUserData();

      final username = _getUserName(
        userData,
        user,
      );

      final role = _getUserRole(userData);

      await _firestore
          .collection('discussions')
          .doc(widget.discussionId)
          .collection('comments')
          .add({
        'discussionId': widget.discussionId,
        'userId': user.uid,
        'username': username,
        'role': role,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();

      if (!mounted) return;

      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Komentar berhasil dikirim.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengirim komentar: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  // ============================================================
  // EDIT KOMENTAR
  // ============================================================

  Future<void> _editComment(
      String commentId,
      Map<String, dynamic> data,
      ) async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    final ownerId = (
        data['userId'] ??
            data['authorId'] ??
            data['uid'] ??
            ''
    ).toString();

    if (ownerId != user.uid) {
      return;
    }

    final controller = TextEditingController(
      text: (data['content'] ?? '').toString(),
    );

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Komentar'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Tulis komentar...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                final value = controller.text.trim();

                if (value.isEmpty) {
                  return;
                }

                Navigator.pop(
                  dialogContext,
                  value,
                );
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null || result.trim().isEmpty) {
      return;
    }

    try {
      await _firestore
          .collection('discussions')
          .doc(widget.discussionId)
          .collection('comments')
          .doc(commentId)
          .update({
        'content': result.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Komentar berhasil diperbarui.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memperbarui komentar: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // HAPUS KOMENTAR
  // ============================================================

  Future<void> _deleteComment(
      String commentId,
      Map<String, dynamic> data,
      ) async {
    final user = _auth.currentUser;

    if (user == null) {
      return;
    }

    final ownerId = (
        data['userId'] ??
            data['authorId'] ??
            data['uid'] ??
            ''
    ).toString();

    if (ownerId != user.uid) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Komentar?'),
          content: const Text(
            'Komentar ini akan dihapus secara permanen.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text('Hapus'),
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
          .collection('discussions')
          .doc(widget.discussionId)
          .collection('comments')
          .doc(commentId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Komentar berhasil dihapus.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus komentar: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final title = _getString(
      'title',
      'Diskusi',
    );

    final content = _getString(
      'content',
      'Tidak ada isi diskusi.',
    );

    final subject = _getString(
      'subject',
      '',
    );

    final username = _getString(
      'username',
      'Pengguna',
    );

    final createdAt = _getDate(
      widget.discussionData['createdAt'],
    );

    final ownerId = (
        widget.discussionData['userId'] ??
            widget.discussionData['authorId'] ??
            ''
    ).toString();

    final teacherId = (
        widget.discussionData['teacherId'] ??
            ''
    ).toString();

    final isTeacherDiscussion =
        teacherId.isNotEmpty;

    final isDiscussionOwner =
        _auth.currentUser?.uid == ownerId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Diskusi'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('discussions')
                  .doc(widget.discussionId)
                  .collection('comments')
                  .orderBy(
                'createdAt',
                descending: false,
              )
                  .snapshots(),
              builder: (context, snapshot) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    24,
                  ),
                  children: [
                    _buildDiscussionCard(
                      context,
                      title: title,
                      content: content,
                      subject: subject,
                      username: username,
                      createdAt: createdAt,
                      isTeacherDiscussion:
                      isTeacherDiscussion,
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        const Icon(
                          Icons.forum_outlined,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Komentar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),

                        if (snapshot.hasData)
                          Container(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1),
                              borderRadius:
                              BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${snapshot.data!.docs.length}',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (snapshot.connectionState ==
                        ConnectionState.waiting)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (snapshot.hasError)
                      _buildCommentError(
                        snapshot.error.toString(),
                      )
                    else if (!snapshot.hasData ||
                          snapshot.data!.docs.isEmpty)
                        _buildEmptyComments()
                      else
                        ...snapshot.data!.docs.map(
                              (doc) {
                            final data =
                            doc.data()
                            as Map<String, dynamic>;

                            return _CommentCard(
                              commentId: doc.id,
                              data: data,
                              onEdit: () {
                                _editComment(
                                  doc.id,
                                  data,
                                );
                              },
                              onDelete: () {
                                _deleteComment(
                                  doc.id,
                                  data,
                                );
                              },
                            );
                          },
                        ),

                    const SizedBox(height: 20),

                    // Informasi kecil di bagian bawah.
                    if (isDiscussionOwner)
                      _buildOwnerInfo(
                        context,
                        'Ini adalah diskusi yang kamu buat.',
                      ),
                  ],
                );
              },
            ),
          ),

          _buildCommentInput(),
        ],
      ),
    );
  }

  // ============================================================
  // KARTU DISKUSI
  // ============================================================

  Widget _buildDiscussionCard(
      BuildContext context, {
        required String title,
        required String content,
        required String subject,
        required String username,
        required DateTime createdAt,
        required bool isTeacherDiscussion,
      }) {
    final primaryColor =
        Theme.of(context).colorScheme.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.35),
        border: Border.all(
          color: primaryColor.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              Container(
                padding:
                const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(20),
                  color: isTeacherDiscussion
                      ? primaryColor.withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                ),
                child: Text(
                  isTeacherDiscussion
                      ? 'Guru'
                      : 'Siswa',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isTeacherDiscussion
                        ? primaryColor
                        : Colors.orange.shade800,
                  ),
                ),
              ),
            ],
          ),

          if (subject.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                borderRadius:
                BorderRadius.circular(20),
                color: primaryColor.withOpacity(0.1),
              ),
              child: Text(
                subject,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],

          const SizedBox(height: 18),

          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 18),

          const Divider(),

          const SizedBox(height: 8),

          Row(
            children: [
              CircleAvatar(
                radius: 17,
                child: Text(
                  username.isNotEmpty
                      ? username[0].toUpperCase()
                      : 'P',
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            username,
                            overflow:
                            TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isTeacherDiscussion
                              ? '• Guru'
                              : '• Siswa',
                          style: TextStyle(
                            fontSize: 11,
                            color: isTeacherDiscussion
                                ? primaryColor
                                : Colors.orange.shade800,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                        Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY COMMENT
  // ============================================================

  Widget _buildEmptyComments() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 42,
            color: Colors.grey.shade400,
          ),

          const SizedBox(height: 10),

          const Text(
            'Belum ada komentar',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Jadilah yang pertama memberikan komentar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR COMMENT
  // ============================================================

  Widget _buildCommentError(String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.red.withOpacity(0.08),
      ),
      child: Text(
        'Gagal memuat komentar.\n\n$error',
        style: const TextStyle(
          color: Colors.red,
        ),
      ),
    );
  }

  // ============================================================
  // INFO PEMILIK
  // ============================================================

  Widget _buildOwnerInfo(
      BuildContext context,
      String text,
      ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context)
            .colorScheme
            .primary
            .withOpacity(0.06),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: Theme.of(context)
                .colorScheme
                .primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INPUT KOMENTAR
  // ============================================================

  Widget _buildCommentInput() {
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
          color: Theme.of(context)
              .colorScheme
              .surface,
          boxShadow: [
            BoxShadow(
              color:
              Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                minLines: 1,
                maxLines: 4,
                textInputAction:
                TextInputAction.newline,
                textCapitalization:
                TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'Tulis komentar...',
                  border: OutlineInputBorder(
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            SizedBox(
              width: 48,
              height: 48,
              child: IconButton.filled(
                onPressed:
                _sending ? null : _sendComment,
                icon: _sending
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons.send_rounded,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// COMMENT CARD
// ================================================================

class _CommentCard extends StatelessWidget {
  final String commentId;
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CommentCard({
    required this.commentId,
    required this.data,
    required this.onEdit,
    required this.onDelete,
  });

  DateTime _getDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value) ??
          DateTime(2000);
    }

    return DateTime(2000);
  }

  String _formatDate(DateTime date) {
    if (date.year <= 2000) {
      return '-';
    }

    final day =
    date.day.toString().padLeft(2, '0');

    final month =
    date.month.toString().padLeft(2, '0');

    final year = date.year.toString();

    final hour =
    date.hour.toString().padLeft(2, '0');

    final minute =
    date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year • $hour:$minute';
  }

  bool _isOwner() {
    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      return false;
    }

    final ownerId = (
        data['userId'] ??
            data['authorId'] ??
            data['uid'] ??
            ''
    ).toString();

    return ownerId.isNotEmpty &&
        ownerId == user.uid;
  }

  String _getRole() {
    final role =
    (data['role'] ?? '').toString().toLowerCase();

    if (role == 'teacher' ||
        role == 'guru') {
      return 'Guru';
    }

    if (role == 'admin') {
      return 'Admin';
    }

    return 'Siswa';
  }

  Color _getRoleColor(
      BuildContext context,
      String role,
      ) {
    if (role == 'Guru') {
      return Theme.of(context)
          .colorScheme
          .primary;
    }

    if (role == 'Admin') {
      return Colors.deepPurple;
    }

    return Colors.orange.shade800;
  }

  @override
  Widget build(BuildContext context) {
    final username =
    (data['username'] ?? 'Pengguna').toString();

    final content =
    (data['content'] ?? '').toString();

    final createdAt =
    _getDate(data['createdAt']);

    final isEdited =
        data['updatedAt'] != null;

    final isOwner = _isOwner();

    final role = _getRole();

    final roleColor =
    _getRoleColor(context, role);

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: role == 'Guru'
              ? roleColor.withOpacity(0.25)
              : Colors.grey.shade300,
        ),
        color: role == 'Guru'
            ? roleColor.withOpacity(0.035)
            : null,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            child: Text(
              username.isNotEmpty
                  ? username[0].toUpperCase()
                  : 'P',
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              username,
                              overflow:
                              TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                          ),

                          const SizedBox(width: 6),

                          Container(
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: roleColor
                                  .withOpacity(0.1),
                              borderRadius:
                              BorderRadius.circular(10),
                            ),
                            child: Text(
                              role,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                FontWeight.w700,
                                color: roleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (isOwner)
                      PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        constraints:
                        const BoxConstraints(),
                        icon: const Icon(
                          Icons.more_vert,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit();
                          }

                          if (value == 'delete') {
                            onDelete();
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
                                    size: 19,
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
                                    size: 19,
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
                      )
                    else
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color:
                          Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 4),

                if (isOwner)
                  Text(
                    '${_formatDate(createdAt)}'
                        '${isEdited ? ' • diedit' : ''}',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                      Colors.grey.shade600,
                    ),
                  ),

                const SizedBox(height: 7),

                Text(
                  content,
                  style: const TextStyle(
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}