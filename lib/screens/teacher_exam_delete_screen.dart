import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeacherExamDeleteScreen extends StatefulWidget {
  final String examId;
  final String title;

  const TeacherExamDeleteScreen({
    super.key,
    required this.examId,
    required this.title,
  });

  @override
  State<TeacherExamDeleteScreen> createState() =>
      _TeacherExamDeleteScreenState();
}

class _TeacherExamDeleteScreenState
    extends State<TeacherExamDeleteScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool _deleting = false;

  Future<void> _deleteExam() async {
    setState(() {
      _deleting = true;
    });

    try {
      await _firestore
          .collection('exams')
          .doc(widget.examId)
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
            'Gagal menghapus ujian:\n$e',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hapus Ujian'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: theme
                      .colorScheme
                      .errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.delete_outline,
                  size: 46,
                  color: theme
                      .colorScheme
                      .onErrorContainer,
                ),
              ),

              const SizedBox(height: 24),

              Text(
                'Hapus Ujian?',
                textAlign: TextAlign.center,
                style: theme
                    .textTheme
                    .headlineSmall
                    ?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Ujian ini akan dihapus secara permanen. '
                    'Pastikan Anda benar-benar ingin menghapus '
                    'ujian tersebut.',
                textAlign: TextAlign.center,
                style:
                theme.textTheme.bodyMedium,
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor:
                    theme.colorScheme.error,
                    foregroundColor:
                    theme.colorScheme.onError,
                  ),
                  onPressed: _deleting
                      ? null
                      : _deleteExam,
                  icon: _deleting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                      : const Icon(
                    Icons.delete_outline,
                  ),
                  label: Text(
                    _deleting
                        ? 'Menghapus...'
                        : 'Ya, Hapus Ujian',
                  ),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _deleting
                      ? null
                      : () {
                    Navigator.pop(
                      context,
                      false,
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
    );
  }
}