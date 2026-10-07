import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'teacher_schedule_form_screen.dart';

class TeacherScheduleScreen extends StatefulWidget {
  const TeacherScheduleScreen({super.key});

  @override
  State<TeacherScheduleScreen> createState() =>
      _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState extends State<TeacherScheduleScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _teacherName = 'Guru';
  String? _teacherId;

  bool _loadingTeacher = true;

  @override
  void initState() {
    super.initState();
    _loadTeacherProfile();
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
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();

      final teacherId = userData?['teacherId']?.toString().trim();

      if (teacherId != null && teacherId.isNotEmpty) {
        return teacherId;
      }

      final email = user.email?.trim();

      if (email != null && email.isNotEmpty) {
        final teacherQuery = await _firestore
            .collection('teachers')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        if (teacherQuery.docs.isNotEmpty) {
          return teacherQuery.docs.first.id;
        }
      }
    } catch (e) {
      debugPrint('Error get teacher document ID: $e');
    }

    return null;
  }

  // ============================================================
  // LOAD TEACHER PROFILE
  // ============================================================

  Future<void> _loadTeacherProfile() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingTeacher = false;
        });
      }
      return;
    }

    try {
      final teacherId = await _getTeacherDocumentId();

      _teacherId = teacherId;

      if (teacherId != null && teacherId.isNotEmpty) {
        final teacherDoc = await _firestore
            .collection('teachers')
            .doc(teacherId)
            .get();

        if (teacherDoc.exists) {
          final teacherData = teacherDoc.data() ?? {};

          final teacherName = (
              teacherData['name'] ??
                  teacherData['username'] ??
                  teacherData['displayName'] ??
                  ''
          ).toString().trim();

          if (teacherName.isNotEmpty) {
            _teacherName = teacherName;
          }
        }
      }

      // Fallback ke users jika data teacher tidak ditemukan.
      if (_teacherName == 'Guru') {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final data = userDoc.data() ?? {};

          final name = (
              data['name'] ??
                  data['username'] ??
                  data['displayName'] ??
                  user.displayName ??
                  ''
          ).toString().trim();

          if (name.isNotEmpty) {
            _teacherName = name;
          }
        }
      }

      if (_teacherName.trim().isEmpty) {
        _teacherName = 'Guru';
      }
    } catch (e) {
      debugPrint('Error load teacher profile: $e');

      _teacherName = user.displayName ?? 'Guru';

      if (_teacherName.trim().isEmpty) {
        _teacherName = 'Guru';
      }
    }

    if (mounted) {
      setState(() {
        _loadingTeacher = false;
      });
    }
  }

  // ============================================================
  // SCHEDULE STREAM
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> _scheduleStream() {
    final teacherId = _teacherId;

    if (teacherId == null || teacherId.isEmpty) {
      return const Stream.empty();
    }

    return _firestore
        .collection('schedules')
        .where(
      'teacherId',
      isEqualTo: teacherId,
    )
        .snapshots();
  }

  // ============================================================
  // SORT SCHEDULE
  // ============================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _sortSchedules(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) {
    const dayOrder = {
      'Senin': 1,
      'Selasa': 2,
      'Rabu': 3,
      'Kamis': 4,
      'Jumat': 5,
      'Sabtu': 6,
      'Minggu': 7,
    };

    final sorted = [...docs];

    sorted.sort((a, b) {
      final dataA = a.data();
      final dataB = b.data();

      final dayA =
          dayOrder[dataA['day']?.toString()] ?? 99;

      final dayB =
          dayOrder[dataB['day']?.toString()] ?? 99;

      if (dayA != dayB) {
        return dayA.compareTo(dayB);
      }

      final timeA =
          dataA['startTime']?.toString() ?? '';

      final timeB =
          dataB['startTime']?.toString() ?? '';

      return timeA.compareTo(timeB);
    });

    return sorted;
  }

  // ============================================================
  // ADD
  // ============================================================

  Future<void> _addSchedule() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TeacherScheduleFormScreen(),
      ),
    );

    if (result == true && mounted) {
      await _loadTeacherProfile();
      setState(() {});
    }
  }

  // ============================================================
  // EDIT
  // ============================================================

  Future<void> _editSchedule(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherScheduleFormScreen(
          scheduleId: doc.id,
          scheduleData: doc.data(),
        ),
      ),
    );

    if (result == true && mounted) {
      await _loadTeacherProfile();
      setState(() {});
    }
  }

  // ============================================================
  // DELETE CONFIRMATION
  // ============================================================

  Future<void> _deleteSchedule(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) async {
    final data = doc.data();

    final courseName =
    (data['courseName'] ?? data['subject'] ?? 'Jadwal')
        .toString();

    final day =
    (data['day'] ?? '').toString();

    final startTime =
    (data['startTime'] ?? '').toString();

    final endTime =
    (data['endTime'] ?? '').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Hapus Jadwal?'),
          content: Text(
            'Jadwal "$courseName"\n'
                '$day, $startTime - $endTime\n\n'
                'Jadwal yang dihapus tidak dapat dikembalikan.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _firestore
          .collection('schedules')
          .doc(doc.id)
          .delete();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jadwal berhasil dihapus.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus jadwal: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    await _loadTeacherProfile();

    if (mounted) {
      setState(() {});
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
        title: const Text('Jadwal Mengajar'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadingTeacher || _teacherId == null
            ? null
            : _addSchedule,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Jadwal'),
      ),
      body: _loadingTeacher
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _teacherId == null || _teacherId!.isEmpty
          ? _buildTeacherNotFound(theme)
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _scheduleStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildError(
              theme,
              snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _buildEmpty(theme);
          }

          final schedules = _sortSchedules(docs);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                100,
              ),
              children: [
                _buildHeader(
                  theme,
                  schedules.length,
                ),
                const SizedBox(height: 20),
                ...schedules.map(
                      (doc) => Padding(
                    padding: const EdgeInsets.only(
                      bottom: 14,
                    ),
                    child: _buildScheduleCard(
                      theme,
                      doc,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(
      ThemeData theme,
      int totalSchedule,
      ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(
            alpha: 0.12,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(
                alpha: 0.12,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.calendar_month_outlined,
              color: theme.colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jadwal Mengajar',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _teacherName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$totalSchedule Jadwal',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SCHEDULE CARD
  // ============================================================

  Widget _buildScheduleCard(
      ThemeData theme,
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      ) {
    final data = doc.data();

    final courseName =
    (data['courseName'] ?? data['subject'] ?? 'Course')
        .toString();

    final subject =
    (data['subject'] ?? '').toString();

    final className =
    (data['className'] ?? '').toString();

    final day =
    (data['day'] ?? '').toString();

    final startTime =
    (data['startTime'] ?? '').toString();

    final endTime =
    (data['endTime'] ?? '').toString();

    final room =
    (data['room'] ?? '').toString();

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    theme.colorScheme.primary.withValues(
                      alpha: 0.1,
                    ),
                    borderRadius:
                    BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.menu_book_outlined,
                    color:
                    theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: [
                      Text(
                        courseName,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subject.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subject,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(
                            color: theme.colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editSchedule(doc);
                    } else if (value == 'delete') {
                      _deleteSchedule(doc);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 10),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline),
                          SizedBox(width: 10),
                          Text('Hapus'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (day.isNotEmpty)
                  _buildInfoChip(
                    theme,
                    Icons.today_outlined,
                    day,
                  ),
                if (startTime.isNotEmpty ||
                    endTime.isNotEmpty)
                  _buildInfoChip(
                    theme,
                    Icons.access_time_outlined,
                    '$startTime - $endTime',
                  ),
                if (className.isNotEmpty)
                  _buildInfoChip(
                    theme,
                    Icons.groups_outlined,
                    className,
                  ),
                if (room.isNotEmpty)
                  _buildInfoChip(
                    theme,
                    Icons.meeting_room_outlined,
                    room,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INFO CHIP
  // ============================================================

  Widget _buildInfoChip(
      ThemeData theme,
      IconData icon,
      String text,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 17,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty(ThemeData theme) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.calendar_month_outlined,
            size: 72,
            color: theme.colorScheme.primary.withValues(
              alpha: 0.35,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Belum Ada Jadwal',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Jadwal mengajar yang kamu buat akan tampil di sini.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              onPressed: _addSchedule,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Jadwal'),
            ),
          ),
        ],
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
              'ID guru tidak ditemukan pada akun yang sedang login.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _refresh,
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal Memuat Jadwal',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}