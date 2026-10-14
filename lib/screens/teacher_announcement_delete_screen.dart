
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherAnnouncementDeleteScreen extends StatefulWidget {
  final String announcementId;
  final String title;

  const TeacherAnnouncementDeleteScreen({
    super.key,
    required this.announcementId,
    required this.title,
  });

  @override
  State<TeacherAnnouncementDeleteScreen> createState() =>
      _TeacherAnnouncementDeleteScreenState();
}

class _TeacherAnnouncementDeleteScreenState
    extends State<TeacherAnnouncementDeleteScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _deleting = false;

  // ============================================================
  // RESOLVE TEACHER ID
  // ============================================================

  Future<String?> _resolveTeacherId(User user) async {
    final userSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final userData = userSnapshot.data();

    // 1. Prioritaskan teacherDocId.
    final teacherDocId = userData?['teacherDocId']?.toString();

    if (teacherDocId != null && teacherDocId.isNotEmpty) {
      final teacherDoc = await _firestore
          .collection('teachers')
          .doc(teacherDocId)
          .get();

      if (teacherDoc.exists) {
        return teacherDoc.id;
      }
    }

    // 2. Fallback ke teacherId.
    final teacherId = userData?['teacherId']?.toString();

    if (teacherId != null && teacherId.isNotEmpty) {
      final teacherDoc = await _firestore
          .collection('teachers')
          .doc(teacherId)
          .get();

      if (teacherDoc.exists) {
        return teacherDoc.id;
      }
    }

    // 3. Cari guru berdasarkan UID.
    final uidQuery = await _firestore
        .collection('teachers')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (uidQuery.docs.isNotEmpty) {
      return uidQuery.docs.first.id;
    }

    // 4. Fallback berdasarkan email.
    final email = user.email;

    if (email != null && email.isNotEmpty) {
      final emailQuery = await _firestore
          .collection('teachers')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (emailQuery.docs.isNotEmpty) {
        return emailQuery.docs.first.id;
      }
    }

    return null;
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteAnnouncement() async {
    if (_deleting) return;

    final user = _auth.currentUser;

    if (user == null) {
      _showMessage('Silakan login terlebih dahulu.');
      return;
    }

    setState(() {
      _deleting = true;
    });

    try {
      final announcementRef = _firestore
          .collection('announcements')
          .doc(widget.announcementId);

      // Ambil data pengumuman sebelum menghapus.
      final announcementSnapshot =
      await announcementRef.get();

      if (!announcementSnapshot.exists) {
        throw Exception('Pengumuman tidak ditemukan.');
      }

      final announcementData =
      announcementSnapshot.data()!;

      // Cari identitas guru yang sedang login.
      final teacherId = await _resolveTeacherId(user);

      if (teacherId == null) {
        throw Exception(
          'Data guru tidak ditemukan. Periksa profil guru di Firestore.',
        );
      }

      final announcementTeacherId =
      announcementData['teacherId']?.toString();

      final announcementTeacherUid =
      announcementData['teacherUid']?.toString();

      // Mendukung data lama yang teacherId-nya berisi UID.
      final isOwner =
          announcementTeacherId == teacherId ||
              announcementTeacherId == user.uid ||
              announcementTeacherUid == user.uid;

      if (!isOwner) {
        throw Exception(
          'Anda tidak memiliki izin menghapus pengumuman ini.',
        );
      }

      await announcementRef.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Pengumuman berhasil dihapus.',
            ),
          ),
        );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _deleting = false;
      });

      _showMessage(
        'Gagal menghapus pengumuman: $e',
      );
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
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
          'Hapus Pengumuman',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ==================================================
                  // ICON
                  // ==================================================

                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 42,
                      color: theme.colorScheme.error,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // TITLE
                  // ==================================================

                  const Text(
                    'Hapus Pengumuman?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Apakah kamu yakin ingin menghapus '
                        'pengumuman berikut?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // ANNOUNCEMENT TITLE
                  // ==================================================

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme
                          .colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.campaign_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // WARNING
                  // ==================================================

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pengumuman yang sudah dihapus '
                                'tidak dapat dikembalikan.',
                            style: TextStyle(
                              color:
                              theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ==================================================
                  // DELETE BUTTON
                  // ==================================================

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed:
                      _deleting ? null : _deleteAnnouncement,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.error,
                        foregroundColor: theme.colorScheme.onError,
                      ),
                      icon: _deleting
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.delete_outline),
                      label: Text(
                        _deleting
                            ? 'Menghapus...'
                            : 'Ya, Hapus Pengumuman',
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ==================================================
                  // CANCEL
                  // ==================================================

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _deleting
                          ? null
                          : () {
                        Navigator.pop(context);
                      },
                      child: const Text('Batal'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
