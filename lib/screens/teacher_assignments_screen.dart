import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'teacher_assignment_form_screen.dart';
import 'teacher_assignment_delete_screen.dart';
import 'teacher_assignment_submissions_screen.dart';

class TeacherAssignmentsScreen extends StatefulWidget {
  const TeacherAssignmentsScreen({super.key});

  @override
  State<TeacherAssignmentsScreen> createState() =>
      _TeacherAssignmentsScreenState();
}

class _TeacherAssignmentsScreenState
    extends State<TeacherAssignmentsScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _teacherId;
  bool _loadingTeacher = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherId();
  }

  // ============================================================
  // GET TEACHER DOCUMENT ID
  // ============================================================

  Future<String?> _getTeacherDocumentId() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    try {
      // --------------------------------------------------------
      // 1. users/{uid}.teacherId
      // --------------------------------------------------------

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();

      final teacherIdFromUser =
      userData?['teacherId']?.toString().trim();

      if (teacherIdFromUser != null &&
          teacherIdFromUser.isNotEmpty) {
        final teacherDoc = await _firestore
            .collection('teachers')
            .doc(teacherIdFromUser)
            .get();

        if (teacherDoc.exists) {
          return teacherIdFromUser;
        }
      }

      // --------------------------------------------------------
      // 2. FALLBACK EMAIL
      // --------------------------------------------------------

      final email = user.email?.trim();

      if (email != null && email.isNotEmpty) {
        final teacherQuery = await _firestore
            .collection('teachers')
            .where(
          'email',
          isEqualTo: email,
        )
            .limit(1)
            .get();

        if (teacherQuery.docs.isNotEmpty) {
          return teacherQuery.docs.first.id;
        }
      }
    } catch (e) {
      debugPrint(
        'Error get teacher document ID: $e',
      );
    }

    return null;
  }

  // ============================================================
  // LOAD TEACHER
  // ============================================================

  Future<void> _loadTeacherId() async {
    if (mounted) {
      setState(() {
        _loadingTeacher = true;
      });
    }

    final teacherId = await _getTeacherDocumentId();

    if (!mounted) return;

    setState(() {
      _teacherId = teacherId;
      _loadingTeacher = false;
    });
  }

  // ============================================================
  // ASSIGNMENT STREAM
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>>
  _assignmentStream() {
    final user = _auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    final uid = user.uid;
    final teacherId = _teacherId;

    // Kalau teacherId canonical tersedia,
    // ambil data dengan teacherId canonical dan UID lama.
    if (teacherId != null &&
        teacherId.isNotEmpty &&
        teacherId != uid) {
      return _firestore
          .collection('assignments')
          .where(
        'teacherId',
        whereIn: [
          teacherId,
          uid,
        ],
      )
          .snapshots();
    }

    return _firestore
        .collection('assignments')
        .where(
      'teacherId',
      isEqualTo: teacherId ?? uid,
    )
        .snapshots();
  }

  // ============================================================
  // TAMBAH / EDIT ASSIGNMENT
  // ============================================================

  Future<void> _openAssignmentForm({
    String? assignmentId,
    Map<String, dynamic>? assignmentData,
  }) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherAssignmentFormScreen(
          assignmentId: assignmentId,
          assignmentData: assignmentData,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            assignmentId == null
                ? 'Assignment berhasil ditambahkan.'
                : 'Assignment berhasil diperbarui.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // HAPUS ASSIGNMENT
  // ============================================================

  Future<void> _openDeleteAssignment(
      String assignmentId,
      String title,
      ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherAssignmentDeleteScreen(
          assignmentId: assignmentId,
          title: title,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Assignment berhasil dihapus.',
          ),
        ),
      );
    }
  }

  // ============================================================
  // LIHAT PENGUMPULAN
  // ============================================================

  Future<void> _openAssignmentSubmissions(
      String assignmentId,
      Map<String, dynamic> assignmentData,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherAssignmentSubmissionsScreen(
          assignmentId: assignmentId,
          assignmentData: assignmentData,
        ),
      ),
    );
  }

  // ============================================================
  // FORMAT TANGGAL
  // ============================================================

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatDueDate(dynamic value) {
    if (value is Timestamp) {
      return _formatDate(value.toDate());
    }

    if (value is DateTime) {
      return _formatDate(value);
    }

    if (value == null) {
      return 'Belum ditentukan';
    }

    return value.toString();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_auth.currentUser == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'Akun guru tidak ditemukan.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assignments'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadTeacherId,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Tambah Assignment',
            onPressed: () {
              _openAssignmentForm();
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),

      // ========================================================
      // FLOATING BUTTON
      // ========================================================

      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadingTeacher || _teacherId == null
            ? null
            : () {
          _openAssignmentForm();
        },
        icon: const Icon(Icons.add),
        label: const Text('Assignment'),
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: _loadingTeacher
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _teacherId == null
          ? _buildTeacherNotFound(theme)
          : StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _assignmentStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _buildError(
              theme,
              snapshot.error.toString(),
            );
          }

          final docs =
              snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _buildEmptyState(theme);
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              100,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];

              return _buildAssignmentCard(
                doc.id,
                doc.data(),
                theme,
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // TEACHER NOT FOUND
  // ============================================================

  Widget _buildTeacherNotFound(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Data Guru Tidak Ditemukan',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Akun guru belum terhubung dengan data teachers.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadTeacherId,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError(
      ThemeData theme,
      String error,
      ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal mengambil data assignment.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _loadTeacherId,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 52,
                color:
                theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Belum ada Assignment',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat tugas pertama untuk siswa Anda.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                _openAssignmentForm();
              },
              icon: const Icon(Icons.add),
              label: const Text(
                'Tambah Assignment',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ASSIGNMENT CARD
  // ============================================================

  Widget _buildAssignmentCard(
      String assignmentId,
      Map<String, dynamic> data,
      ThemeData theme,
      ) {
    final title =
    (data['title'] ?? 'Tanpa Judul').toString();

    final description =
    (data['description'] ?? '').toString();

    final courseTitle =
    (data['courseTitle'] ??
        data['courseName'] ??
        '')
        .toString();

    final classId =
    (data['classId'] ?? '-').toString();

    final points =
    (data['points'] ??
        data['maxScore'] ??
        100)
        .toString();

    final dueDate = data['dueDate'];

    return Card(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                    theme.colorScheme.primaryContainer,
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.assignment_outlined,
                    color: theme
                        .colorScheme
                        .onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow:
                        TextOverflow.ellipsis,
                        style: theme
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),
                      if (courseTitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          courseTitle,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: theme
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color:
                            theme.colorScheme.primary,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _openAssignmentForm(
                        assignmentId: assignmentId,
                        assignmentData: data,
                      );
                    }

                    if (value == 'delete') {
                      _openDeleteAssignment(
                        assignmentId,
                        title,
                      );
                    }
                  },
                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(
                              Icons.edit_outlined,
                            ),
                            SizedBox(width: 10),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                            ),
                            SizedBox(width: 10),
                            Text('Hapus'),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
              ],
            ),

            if (description.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                description,
                maxLines: 3,
                overflow:
                TextOverflow.ellipsis,
                style:
                theme.textTheme.bodyMedium,
              ),
            ],

            const SizedBox(height: 14),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoChip(
                  icon: Icons.groups_outlined,
                  text: classId,
                ),
                _InfoChip(
                  icon: Icons.star_outline,
                  text: '$points poin',
                ),
                _InfoChip(
                  icon:
                  Icons.calendar_today_outlined,
                  text:
                  _formatDueDate(dueDate),
                ),
              ],
            ),

            const SizedBox(height: 14),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _openAssignmentSubmissions(
                    assignmentId,
                    data,
                  );
                },
                icon: const Icon(
                  Icons.people_outline,
                ),
                label: const Text(
                  'Lihat Pengumpulan Siswa',
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
// INFO CHIP
// ================================================================

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color:
        theme.colorScheme.surfaceContainerHighest,
        borderRadius:
        BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color:
            theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style:
            theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}