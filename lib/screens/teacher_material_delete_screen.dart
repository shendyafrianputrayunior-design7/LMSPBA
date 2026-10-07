import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeacherMaterialDeleteScreen extends StatefulWidget {
  final String materialId;
  final String title;

  const TeacherMaterialDeleteScreen({
    super.key,
    required this.materialId,
    required this.title,
  });

  @override
  State<TeacherMaterialDeleteScreen> createState() =>
      _TeacherMaterialDeleteScreenState();
}

class _TeacherMaterialDeleteScreenState
    extends State<TeacherMaterialDeleteScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _deleting = false;

  Future<void> _deleteMaterial() async {
    setState(() {
      _deleting = true;
    });

    try {
      await _firestore
          .collection('materials')
          .doc(widget.materialId)
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
            'Gagal menghapus materi: $e',
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
        title: const Text(
          'Hapus Materi',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor:
                    theme.colorScheme.errorContainer,
                    child: Icon(
                      Icons.delete_outline,
                      size: 40,
                      color: theme.colorScheme.error,
                    ),
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Hapus Materi?',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Apakah Anda yakin ingin menghapus materi:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Materi yang sudah dihapus tidak dapat dikembalikan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.error,
                    ),
                  ),

                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed:
                      _deleting ? null : _deleteMaterial,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                        theme.colorScheme.error,
                        foregroundColor:
                        theme.colorScheme.onError,
                      ),
                      icon: _deleting
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                          : const Icon(Icons.delete),
                      label: Text(
                        _deleting
                            ? 'Menghapus...'
                            : 'Ya, Hapus Materi',
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                      onPressed:
                      _deleting ? null : () => Navigator.pop(context),
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