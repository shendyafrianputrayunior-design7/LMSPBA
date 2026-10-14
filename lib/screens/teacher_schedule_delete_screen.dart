import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherScheduleDeleteScreen extends StatefulWidget {
  final String scheduleId;
  final String subject;

  const TeacherScheduleDeleteScreen({
    super.key,
    required this.scheduleId,
    required this.subject,
  });

  @override
  State<TeacherScheduleDeleteScreen> createState() =>
      _TeacherScheduleDeleteScreenState();
}

class _TeacherScheduleDeleteScreenState
    extends State<TeacherScheduleDeleteScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _deleting = false;

  Future<String?> _getTeacherId() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    // Ambil data pengguna yang sedang login.
    final userDoc =
    await _firestore.collection('users').doc(user.uid).get();

    final userData = userDoc.data();

    // Prioritaskan teacherDocId sesuai struktur pendaftaran guru.
    final teacherDocId = userData?['teacherDocId']?.toString();
    if (teacherDocId != null && teacherDocId.isNotEmpty) {
      return teacherDocId;
    }

    // Fallback untuk data lama yang menggunakan teacherId.
    final teacherId = userData?['teacherId']?.toString();
    if (teacherId != null && teacherId.isNotEmpty) {
      return teacherId;
    }

    // Fallback berdasarkan UID jika data pengguna belum menyimpan ID guru.
    final teacherQuery = await _firestore
        .collection('teachers')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (teacherQuery.docs.isNotEmpty) {
      return teacherQuery.docs.first.id;
    }

    return null;
  }

  Future<void> _deleteSchedule() async {
    if (_deleting) return;

    setState(() {
      _deleting = true;
    });

    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Silakan login terlebih dahulu.');
      }

      final teacherId = await _getTeacherId();

      if (teacherId == null) {
        throw Exception(
          'Data guru tidak ditemukan. Silakan periksa profil akun guru.',
        );
      }

      // Pastikan jadwal tersedia.
      final scheduleRef =
      _firestore.collection('schedules').doc(widget.scheduleId);

      final scheduleDoc = await scheduleRef.get();

      if (!scheduleDoc.exists) {
        throw Exception('Jadwal sudah tidak tersedia atau telah dihapus.');
      }

      final scheduleData = scheduleDoc.data();
      final scheduleTeacherId =
      scheduleData?['teacherId']?.toString();

      // Pastikan jadwal dimiliki oleh guru yang sedang login.
      if (scheduleTeacherId != teacherId) {
        throw Exception(
          'Anda tidak memiliki izin untuk menghapus jadwal ini.',
        );
      }

      await scheduleRef.delete();

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
            'Gagal menghapus jadwal: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hapus Jadwal'),
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
                        color: Colors.red.withValues(
                          alpha: 0.1,
                        ),
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
                      'Hapus Jadwal?',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      'Apakah kamu yakin ingin menghapus jadwal berikut?',
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
                        color: Colors.grey.withValues(
                          alpha: 0.08,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        widget.subject,
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
                        onPressed: _deleting ? null : _deleteSchedule,
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
                              : 'Ya, Hapus Jadwal',
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