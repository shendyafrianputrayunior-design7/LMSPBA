import 'package:cloud_firestore/cloud_firestore.dart';
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

  bool _deleting = false;

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteAnnouncement() async {
    if (_deleting) return;

    setState(() {
      _deleting = true;
    });

    try {
      await _firestore
          .collection('announcements')
          .doc(widget.announcementId)
          .delete();

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _deleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus pengumuman: $e',
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
                      color: theme
                          .colorScheme
                          .errorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 42,
                      color:
                      theme.colorScheme.error,
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
                      color: theme
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // ANNOUNCEMENT TITLE
                  // ==================================================

                  Container(
                    width: double.infinity,
                    padding:
                    const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme
                          .colorScheme
                          .surfaceContainerHighest,
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons
                              .campaign_outlined,
                          color: theme
                              .colorScheme
                              .primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            widget.title,
                            style:
                            const TextStyle(
                              fontSize: 16,
                              fontWeight:
                              FontWeight.w600,
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
                    padding:
                    const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme
                          .colorScheme
                          .errorContainer
                          .withValues(alpha: 0.6),
                      borderRadius:
                      BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: theme
                              .colorScheme
                              .error,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pengumuman yang sudah '
                                'dihapus tidak dapat '
                                'dikembalikan.',
                            style: TextStyle(
                              color: theme
                                  .colorScheme
                                  .onErrorContainer,
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
                      onPressed: _deleting
                          ? null
                          : _deleteAnnouncement,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                        theme.colorScheme.error,
                        foregroundColor:
                        theme.colorScheme.onError,
                      ),
                      icon: _deleting
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
                        Icons.delete_outline,
                      ),
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
                        Navigator.pop(
                          context,
                        );
                      },
                      child: const Text(
                        'Batal',
                      ),
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