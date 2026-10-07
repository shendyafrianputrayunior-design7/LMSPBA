import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StudentDiscussionFormScreen extends StatefulWidget {
  final String classId;

  // ID diskusi untuk mode edit.
  // null = membuat diskusi baru.
  final String? discussionId;

  // Data diskusi lama untuk mode edit.
  final Map<String, dynamic>? initialData;

  const StudentDiscussionFormScreen({
    super.key,
    required this.classId,
    this.discussionId,
    this.initialData,
  });

  bool get isEditMode => discussionId != null;

  @override
  State<StudentDiscussionFormScreen> createState() =>
      _StudentDiscussionFormScreenState();
}

class _StudentDiscussionFormScreenState
    extends State<StudentDiscussionFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController =
  TextEditingController();

  final TextEditingController _subjectController =
  TextEditingController();

  final TextEditingController _contentController =
  TextEditingController();

  bool _saving = false;

  bool get _isEditMode => widget.discussionId != null;

  @override
  void initState() {
    super.initState();

    if (_isEditMode && widget.initialData != null) {
      final data = widget.initialData!;

      _titleController.text =
          (data['title'] ?? '').toString();

      _subjectController.text =
          (data['subject'] ?? '').toString();

      _contentController.text =
          (data['content'] ?? '').toString();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _saveDiscussion() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

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
      _saving = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      if (_isEditMode) {
        await _updateDiscussion(firestore, user);
      } else {
        await _createDiscussion(firestore, user);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Diskusi berhasil diperbarui.'
                : 'Diskusi berhasil dibuat.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Gagal memperbarui diskusi: $e'
                : 'Gagal membuat diskusi: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _createDiscussion(
      FirebaseFirestore firestore,
      User user,
      ) async {
    final userSnapshot = await firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userSnapshot.data() ?? {};

    final username =
    (userData['username'] ??
        userData['name'] ??
        userData['displayName'] ??
        user.displayName ??
        'Siswa')
        .toString();

    await firestore.collection('discussions').add({
      'classId': widget.classId,
      'content': _contentController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'subject': _subjectController.text.trim(),
      'title': _titleController.text.trim(),

      // UID pemilik diskusi.
      'userId': user.uid,

      'username': username,
    });
  }

  Future<void> _updateDiscussion(
      FirebaseFirestore firestore,
      User user,
      ) async {
    final discussionId = widget.discussionId;

    if (discussionId == null) {
      throw Exception('ID diskusi tidak ditemukan.');
    }

    final discussionRef =
    firestore.collection('discussions').doc(discussionId);

    final discussionSnapshot = await discussionRef.get();

    if (!discussionSnapshot.exists) {
      throw Exception('Diskusi tidak ditemukan.');
    }

    final existingData =
    discussionSnapshot.data() as Map<String, dynamic>;

    final ownerId =
    (existingData['userId'] ??
        existingData['authorId'] ??
        existingData['uid'] ??
        '')
        .toString();

    // Keamanan tambahan:
    // hanya pemilik diskusi yang boleh mengedit.
    if (ownerId.isEmpty || ownerId != user.uid) {
      throw Exception(
        'Kamu tidak memiliki izin untuk mengedit diskusi ini.',
      );
    }

    await discussionRef.update({
      'title': _titleController.text.trim(),
      'subject': _subjectController.text.trim(),
      'content': _contentController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor =
        Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditMode
              ? 'Edit Diskusi'
              : 'Diskusi Baru',
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // =========================================================
            // INFO
            // =========================================================
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: primaryColor.withOpacity(0.08),
              ),
              child: Row(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Icon(
                    _isEditMode
                        ? Icons.edit_outlined
                        : Icons.forum_outlined,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _isEditMode
                          ? 'Perbarui judul, mata pelajaran, atau isi diskusi kamu.'
                          : 'Buat diskusi untuk bertanya, berbagi pendapat, atau membahas materi bersama teman sekelas.',
                      style: TextStyle(
                        height: 1.4,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // =========================================================
            // JUDUL
            // =========================================================
            const Text(
              'Judul Diskusi',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            TextFormField(
              controller: _titleController,
              textCapitalization:
              TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText:
                'Contoh: Cara menghitung luas lingkaran',
                prefixIcon: const Icon(
                  Icons.title_outlined,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(14),
                ),
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Judul diskusi wajib diisi.';
                }

                if (value.trim().length < 5) {
                  return 'Judul minimal 5 karakter.';
                }

                return null;
              },
            ),

            const SizedBox(height: 20),

            // =========================================================
            // MATA PELAJARAN
            // =========================================================
            const Text(
              'Mata Pelajaran',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            TextFormField(
              controller: _subjectController,
              textCapitalization:
              TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Contoh: Matematika',
                prefixIcon: const Icon(
                  Icons.menu_book_outlined,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(14),
                ),
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Mata pelajaran wajib diisi.';
                }

                return null;
              },
            ),

            const SizedBox(height: 20),

            // =========================================================
            // ISI DISKUSI
            // =========================================================
            const Text(
              'Isi Diskusi',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 8),

            TextFormField(
              controller: _contentController,
              textCapitalization:
              TextCapitalization.sentences,
              minLines: 6,
              maxLines: 10,
              decoration: InputDecoration(
                hintText:
                'Tuliskan pertanyaan atau topik yang ingin dibahas...',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(
                    bottom: 90,
                  ),
                  child: Icon(
                    Icons.chat_outlined,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius:
                  BorderRadius.circular(14),
                ),
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'Isi diskusi wajib diisi.';
                }

                if (value.trim().length < 10) {
                  return 'Isi diskusi minimal 10 karakter.';
                }

                return null;
              },
            ),

            const SizedBox(height: 28),

            // =========================================================
            // BUTTON
            // =========================================================
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed:
                _saving ? null : _saveDiscussion,
                icon: _saving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Icon(
                  _isEditMode
                      ? Icons.save_outlined
                      : Icons.send_rounded,
                ),
                label: Text(
                  _saving
                      ? 'Menyimpan...'
                      : _isEditMode
                      ? 'Simpan Perubahan'
                      : 'Buat Diskusi',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              _isEditMode
                  ? 'Perubahan hanya dapat dilakukan oleh pemilik diskusi.'
                  : 'Diskusi akan terlihat oleh siswa lain yang berada di kelas yang sama.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}