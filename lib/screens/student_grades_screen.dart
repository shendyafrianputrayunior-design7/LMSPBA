import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StudentGradesScreen extends StatefulWidget {
  const StudentGradesScreen({super.key});

  @override
  State<StudentGradesScreen> createState() =>
      _StudentGradesScreenState();
}

class _StudentGradesScreenState extends State<StudentGradesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _grades = [];

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final user = _auth.currentUser;

      if (user == null) {
        throw Exception('Silakan login terlebih dahulu.');
      }

      // Ambil nilai berdasarkan UID akun siswa.
      final snapshot = await _firestore
          .collection('student_grades')
          .where('studentId', isEqualTo: user.uid)
          .get();

      final grades = snapshot.docs
          .map((doc) {
        final data = doc.data();
        final score = data['finalScore'];

        if (score is! num) {
          return null;
        }

        return <String, dynamic>{
          'id': doc.id,
          'courseId': data['courseId'] ?? '',
          'courseName': data['courseName'] ??
              data['courseTitle'] ??
              'Mata Pelajaran',
          'finalScore': score,
          'updatedAt': data['updatedAt'],
        };
      })
          .whereType<Map<String, dynamic>>()
          .toList();

      grades.sort((a, b) {
        final nameA = (a['courseName'] ?? '')
            .toString()
            .toLowerCase();
        final nameB = (b['courseName'] ?? '')
            .toString()
            .toLowerCase();

        return nameA.compareTo(nameB);
      });

      if (!mounted) return;

      setState(() {
        _grades = grades;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  double get _average {
    if (_grades.isEmpty) return 0;

    final total = _grades.fold<double>(
      0,
          (sum, grade) =>
      sum + (grade['finalScore'] as num).toDouble(),
    );

    return total / _grades.length;
  }

  Color _scoreColor(double score) {
    if (score >= 85) return Colors.green;
    if (score >= 75) return Colors.blue;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  String _scoreDescription(double score) {
    if (score >= 85) return 'Sangat Baik';
    if (score >= 75) return 'Baik';
    if (score >= 60) return 'Cukup';
    return 'Perlu ditingkatkan';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nilai Akhir'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loading ? null : _loadGrades,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _error != null
          ? _buildError()
          : RefreshIndicator(
        onRefresh: _loadGrades,
        child: _buildContent(theme),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red,
            ),
            const SizedBox(height: 12),
            Text(
              'Gagal memuat nilai',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGrades,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildAverageCard(),
        const SizedBox(height: 24),
        Text(
          'Nilai per Mata Pelajaran',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_grades.isEmpty)
          _buildEmptyState()
        else
          ..._grades.map(_buildGradeCard),
        const SizedBox(height: 16),
        if (_grades.isNotEmpty)
          Text(
            'Rata-rata dihitung dari ${_grades.length} '
                'mata pelajaran yang sudah memiliki nilai.',
            style: theme.textTheme.bodySmall,
          ),
      ],
    );
  }

  Widget _buildAverageCard() {
    final color = _scoreColor(_average);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined),
              SizedBox(width: 8),
              Text('Rata-rata Nilai'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _grades.isEmpty ? '--' : _average.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            _grades.isEmpty
                ? 'Belum ada nilai yang tersedia'
                : _scoreDescription(_average),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _grades.isEmpty
                ? 0
                : (_average / 100).clamp(0.0, 1.0),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 8),
          Text(
            '${_grades.length} mata pelajaran sudah dinilai',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildGradeCard(Map<String, dynamic> grade) {
    final score = (grade['finalScore'] as num).toDouble();
    final courseName = (grade['courseName'] ?? 'Mata Pelajaran')
        .toString();
    final color = _scoreColor(score);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.menu_book_outlined,
                color: color,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    courseName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _scoreDescription(score),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              score.toStringAsFixed(
                score == score.roundToDouble() ? 0 : 2,
              ),
              style: TextStyle(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.grading_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum Ada Nilai',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nilai akan muncul setelah guru '
                'memasukkan nilai akhir.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}