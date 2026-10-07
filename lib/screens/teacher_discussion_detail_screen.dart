import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherDiscussionDetailScreen extends StatefulWidget {
  final String discussionId;
  final Map<String, dynamic> discussionData;

  const TeacherDiscussionDetailScreen({
    super.key,
    required this.discussionId,
    required this.discussionData,
  });

  @override
  State<TeacherDiscussionDetailScreen> createState() =>
      _TeacherDiscussionDetailScreenState();
}

class _TeacherDiscussionDetailScreenState
    extends State<TeacherDiscussionDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _commentController =
  TextEditingController();

  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ============================================================
  // GET STRING
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

  // ============================================================
  // GET DATE
  // ============================================================

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

  // ============================================================
  // FORMAT DATE
  // ============================================================

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
  // GET TEACHER NAME
  // ============================================================

  Future<String> _getTeacherName() async {
    final user = _auth.currentUser;

    if (user == null) {
      return 'Guru';
    }

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = userDoc.data() ?? {};

      final name = (
          data['name'] ??
              data['username'] ??
              data['displayName'] ??
              user.displayName ??
              'Guru'
      ).toString().trim();

      if (name.isNotEmpty) {
        return name;
      }
    } catch (e) {
      debugPrint(
        'ERROR GET TEACHER NAME: $e',
      );
    }

    return 'Guru';
  }

  // ============================================================
  // SEND COMMENT
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
          content: Text(
            'Guru belum login.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      final teacherName = await _getTeacherName();

      await _firestore
          .collection('discussions')
          .doc(widget.discussionId)
          .collection('comments')
          .add({
        'discussionId': widget.discussionId,
        'userId': user.uid,
        'username': teacherName,
        'role': 'teacher',
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
      });

      _commentController.clear();

      if (!mounted) return;

      FocusScope.of(context).unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Balasan berhasil dikirim.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal mengirim balasan: $e',
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
  // EDIT COMMENT
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
          title: const Text(
            'Edit Balasan',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            textCapitalization:
            TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Tulis balasan...',
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
              child: const Text(
                'Batal',
              ),
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
              child: const Text(
                'Simpan',
              ),
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
          content: Text(
            'Balasan berhasil diperbarui.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memperbarui balasan: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // DELETE COMMENT
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
          title: const Text(
            'Hapus Balasan?',
          ),
          content: const Text(
            'Balasan ini akan dihapus secara permanen.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Batal',
              ),
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
          .collection('discussions')
          .doc(widget.discussionId)
          .collection('comments')
          .doc(commentId)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Balasan berhasil dihapus.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus balasan: $e',
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

    final className = _getString(
      'className',
      _getString('classId', '-'),
    );

    final username = _getString(
      'username',
      'Siswa',
    );

    final createdAt = _getDate(
      widget.discussionData['createdAt'],
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detail Diskusi',
        ),
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
              builder: (
                  context,
                  snapshot,
                  ) {
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildDiscussionCard(
                      context,
                      title: title,
                      content: content,
                      subject: subject,
                      className: className,
                      username: username,
                      createdAt: createdAt,
                    ),

                    const SizedBox(height: 24),

                    Row(
                      children: [
                        const Icon(
                          Icons.forum_rounded,
                          size: 21,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Komentar',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (snapshot.hasData)
                          Text(
                            '${snapshot.data!.docs.length}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
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
  // DISCUSSION CARD
  // ============================================================

  Widget _buildDiscussionCard(
      BuildContext context, {
        required String title,
        required String content,
        required String subject,
        required String className,
        required String username,
        required DateTime createdAt,
      }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme
            .colorScheme
            .surfaceContainerHighest
            .withOpacity(0.35),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme
                    .colorScheme
                    .primary
                    .withOpacity(0.12),
                child: Icon(
                  Icons.person_rounded,
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
                      username,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDate(createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Siswa',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            title,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),

          if (subject.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: theme
                    .colorScheme
                    .primary
                    .withOpacity(0.1),
              ),
              child: Text(
                subject,
                style: TextStyle(
                  color: theme.colorScheme.primary,
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
              Icon(
                Icons.class_rounded,
                size: 17,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  className,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY COMMENTS
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
            'Berikan jawaban untuk pertanyaan siswa.',
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
  // COMMENT ERROR
  // ============================================================

  Widget _buildCommentError(
      String error,
      ) {
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
  // COMMENT INPUT
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
              color: Colors.black.withOpacity(0.08),
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
                decoration: InputDecoration(
                  hintText: 'Tulis balasan untuk siswa...',
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
  final Map<String, dynamic> data;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CommentCard({
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

    final year =
    date.year.toString();

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

  @override
  Widget build(BuildContext context) {
    final username =
    (data['username'] ?? 'Pengguna').toString();

    final content =
    (data['content'] ?? '').toString();

    final createdAt =
    _getDate(data['createdAt']);

    final updatedAt =
    data['updatedAt'];

    final isEdited =
        updatedAt != null;

    final isOwner =
    _isOwner();

    final role =
    (data['role'] ?? '').toString();

    final isTeacher =
        role == 'teacher';

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isTeacher
            ? Theme.of(context)
            .colorScheme
            .primary
            .withOpacity(0.06)
            : null,
        border: Border.all(
          color: isTeacher
              ? Theme.of(context)
              .colorScheme
              .primary
              .withOpacity(0.2)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: isTeacher
                ? Theme.of(context)
                .colorScheme
                .primary
                : Colors.orange.shade100,
            child: Icon(
              isTeacher
                  ? Icons.school_rounded
                  : Icons.person_rounded,
              size: 20,
              color: isTeacher
                  ? Colors.white
                  : Colors.orange.shade700,
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
                              style: const TextStyle(
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                          ),

                          if (isTeacher) ...[
                            const SizedBox(width: 7),
                            Container(
                              padding:
                              const EdgeInsets
                                  .symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration:
                              BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.1),
                                borderRadius:
                                BorderRadius
                                    .circular(6),
                              ),
                              child: Text(
                                'Guru',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight:
                                  FontWeight.w700,
                                  color:
                                  Theme.of(context)
                                      .colorScheme
                                      .primary,
                                ),
                              ),
                            ),
                          ],
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
                        itemBuilder:
                            (context) => const [
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
                        ],
                      )
                    else
                      Text(
                        _formatDate(createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),

                if (isOwner)
                  Padding(
                    padding:
                    const EdgeInsets.only(
                      top: 2,
                    ),
                    child: Text(
                      '${_formatDate(createdAt)}'
                          '${isEdited ? ' • diedit' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
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