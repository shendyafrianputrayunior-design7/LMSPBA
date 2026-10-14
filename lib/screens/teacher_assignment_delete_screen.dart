
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeacherAssignmentDeleteScreen extends StatefulWidget {
  final String assignmentId;
  final String title;

  const TeacherAssignmentDeleteScreen({
    super.key,
    required this.assignmentId,
    required this.title,
  });

  @override
  State<TeacherAssignmentDeleteScreen> createState() =>
      _TeacherAssignmentDeleteScreenState();
}

class _TeacherAssignmentDeleteScreenState
    extends State<TeacherAssignmentDeleteScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _deleting = false;

  // ============================================================
  // DELETE ASSIGNMENT
  // ============================================================

  Future<void> _deleteAssignment() async {
    if (_deleting) return;

    setState(() {
      _deleting = true;
    });

    try {
      final assignmentRef = _firestore
          .collection('assignments')
          .doc(widget.assignmentId);

      // Pastikan assignment masih tersedia.
      final assignmentSnapshot = await assignmentRef.get();

      if (!assignmentSnapshot.exists) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment sudah tidak tersedia.'),
          ),
        );

        Navigator.pop(context, true);
        return;
      }

      // Hapus dokumen assignment dari Firestore.
      await assignmentRef.delete();

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _deleting = false;
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus assignment:\n$e'),
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
        title: const Text('Hapus Assignment'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ==================================================
              // DELETE ICON
              // ==================================================

              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  size: 44,
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // TITLE
              // ==================================================

              Text(
                'Hapus Assignment?',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // ASSIGNMENT NAME
              // ==================================================

              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 16),

              // ==================================================
              // WARNING
              // ==================================================

              Text(
                'Assignment ini akan dihapus secara permanen '
                    'dan tindakan ini tidak dapat dibatalkan.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),

              const SizedBox(height: 32),

              // ==================================================
              // DELETE BUTTON
              // ==================================================

              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  onPressed: _deleting ? null : _deleteAssignment,
                  icon: _deleting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(Icons.delete_outline),
                  label: Text(
                    _deleting
                        ? 'Menghapus...'
                        : 'Ya, Hapus Assignment',
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // ==================================================
              // CANCEL BUTTON
              // ==================================================

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _deleting
                      ? null
                      : () {
                    Navigator.pop(context, false);
                  },
                  child: const Text('Batal'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
