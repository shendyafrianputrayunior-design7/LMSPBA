import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeacherDiscussionDeleteScreen extends StatefulWidget {
  final String discussionId;
  final String title;

  const TeacherDiscussionDeleteScreen({
    super.key,
    required this.discussionId,
    required this.title,
  });

  @override
  State<TeacherDiscussionDeleteScreen> createState() =>
      _TeacherDiscussionDeleteScreenState();
}

class _TeacherDiscussionDeleteScreenState
    extends State<TeacherDiscussionDeleteScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _deleting = false;

  Future<void> _deleteDiscussion() async {
    setState(() {
      _deleting = true;
    });

    try {
      final discussionRef = _firestore
          .collection('discussions')
          .doc(widget.discussionId);

      // Pastikan dokumen diskusi masih tersedia.
      final discussionSnapshot = await discussionRef.get();

      if (!discussionSnapshot.exists) {
        if (!mounted) return;

        setState(() {
          _deleting = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Diskusi sudah tidak tersedia.'),
          ),
        );
        return;
      }

      // Hapus dokumen diskusi.
      await discussionRef.delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diskusi berhasil dihapus.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _deleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menghapus diskusi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Konfirmasi Penghapusan'),
          content: Text(
            'Apakah kamu yakin ingin menghapus diskusi '
                '"${widget.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ya, Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _deleteDiscussion();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hapus Diskusi'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 500,
            ),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_outline,
                        size: 40,
                        color: Colors.red,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'Hapus Diskusi?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Apakah kamu yakin ingin menghapus diskusi berikut?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _deleting ? null : _confirmDelete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        icon: _deleting
                            ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Icon(Icons.delete),
                        label: Text(
                          _deleting
                              ? 'Menghapus...'
                              : 'Ya, Hapus Diskusi',
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: _deleting
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}