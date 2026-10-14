import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'teacher_schedule_form_screen.dart';

class TeacherScheduleScreen extends StatefulWidget {
  const TeacherScheduleScreen({
    super.key,
  });

  @override
  State<TeacherScheduleScreen> createState() =>
      _TeacherScheduleScreenState();
}

class _TeacherScheduleScreenState
    extends State<TeacherScheduleScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  String? _teacherId;
  String _teacherName = 'Guru';

  bool _loading = true;
  bool _deleting = false;

  List<Map<String, dynamic>> _schedules = [];

  final List<String> _days = const [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> _initialize() async {
    await _loadTeacher();
  }

  // ============================================================
  // GET TEACHER ID
  // ============================================================

  Future<String?> _getTeacherDocumentId() async {
    final user = _auth.currentUser;

    if (user == null) return null;

    try {
      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();

      // AccountCreationService menyimpan teacherDocId.
      final savedIds = [
        userData?['teacherDocId']?.toString().trim(),
        userData?['teacherId']?.toString().trim(),
      ];

      for (final id in savedIds) {
        if (id == null || id.isEmpty) continue;

        final teacherDoc = await _firestore
            .collection('teachers')
            .doc(id)
            .get();

        if (teacherDoc.exists) {
          final teacherData = teacherDoc.data() ?? {};
          final storedUid = teacherData['uid']?.toString();

          // Jika UID tersedia, pastikan cocok dengan akun login.
          if (storedUid != null &&
              storedUid.isNotEmpty &&
              storedUid != user.uid) {
            continue;
          }

          return teacherDoc.id;
        }
      }

      // Fallback: cari guru berdasarkan UID.
      final uidQuery = await _firestore
          .collection('teachers')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (uidQuery.docs.isNotEmpty) {
        return uidQuery.docs.first.id;
      }

      // Fallback untuk data lama berdasarkan email.
      final email = user.email?.trim();

      if (email != null && email.isNotEmpty) {
        final emailQuery = await _firestore
            .collection('teachers')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();

        for (final doc in emailQuery.docs) {
          final storedUid = doc.data()['uid']?.toString();

          if (storedUid == null ||
              storedUid.isEmpty ||
              storedUid == user.uid) {
            return doc.id;
          }
        }
      }
    } catch (e) {
      debugPrint('Gagal mendapatkan teacher ID: $e');
      rethrow;
    }

    return null;
  }

  // ============================================================
  // LOAD TEACHER
  // ============================================================

  Future<void> _loadTeacher() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage('User belum login.');
      return;
    }

    try {
      final teacherId = await _getTeacherDocumentId();

      if (!mounted) return;

      if (teacherId == null || teacherId.isEmpty) {
        setState(() {
          _teacherId = null;
          _schedules = [];
          _loading = false;
        });

        _showMessage(
          'Data guru tidak ditemukan. Periksa teacherDocId '
              'atau teacherId pada dokumen users.',
        );
        return;
      }

      final teacherDoc = await _firestore
          .collection('teachers')
          .doc(teacherId)
          .get();

      if (!teacherDoc.exists) {
        throw Exception('Dokumen guru tidak ditemukan.');
      }

      final teacherData = teacherDoc.data() ?? {};
      final storedUid = teacherData['uid']?.toString();

      if (storedUid != null &&
          storedUid.isNotEmpty &&
          storedUid != user.uid) {
        throw Exception(
          'Profil guru tidak sesuai dengan akun yang login.',
        );
      }

      var name = (
          teacherData['name'] ??
              teacherData['username'] ??
              teacherData['displayName'] ??
              ''
      ).toString().trim();

      if (name.isEmpty) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        final userData = userDoc.data() ?? {};

        name = (
            userData['name'] ??
                userData['username'] ??
                userData['displayName'] ??
                user.displayName ??
                'Guru'
        ).toString().trim();
      }

      if (!mounted) return;

      setState(() {
        _teacherId = teacherId;
        _teacherName = name.isEmpty ? 'Guru' : name;
      });

      await _loadSchedules();
    } catch (e) {
      debugPrint('Gagal load teacher: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage('Gagal mengambil data guru: $e');
    }
  }

  // ============================================================
  // LOAD SCHEDULES
  // ============================================================

  Future<void> _loadSchedules() async {
    final teacherId = _teacherId;

    if (teacherId == null || teacherId.isEmpty) {
      if (!mounted) return;

      setState(() {
        _schedules = [];
        _loading = false;
      });

      return;
    }

    try {
      final snapshot = await _firestore
          .collection('schedules')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      if (!mounted) return;

      final schedules = snapshot.docs.map((doc) {
        return <String, dynamic>{
          ...doc.data(),
          '_id': doc.id,
        };
      }).toList();

      // Urutkan berdasarkan hari, kemudian jam mulai.
      schedules.sort((a, b) {
        final dayA = _days.indexOf(
          (a['day'] ?? '').toString(),
        );

        final dayB = _days.indexOf(
          (b['day'] ?? '').toString(),
        );

        final normalizedDayA = dayA == -1 ? 999 : dayA;
        final normalizedDayB = dayB == -1 ? 999 : dayB;

        if (normalizedDayA != normalizedDayB) {
          return normalizedDayA.compareTo(normalizedDayB);
        }

        final startA = (a['startTime'] ?? '').toString();
        final startB = (b['startTime'] ?? '').toString();

        return startA.compareTo(startB);
      });

      setState(() {
        _schedules = schedules;
        _loading = false;
      });

      debugPrint(
        'Jumlah jadwal teacher $teacherId: ${schedules.length}',
      );
    } catch (e) {
      debugPrint('Gagal load schedules: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage('Gagal mengambil data jadwal: $e');
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refreshSchedules() async {
    if (_teacherId == null) {
      await _loadTeacher();
    } else {
      await _loadSchedules();
    }
  }

  // ============================================================
  // ADD SCHEDULE
  // ============================================================

  Future<void> _addSchedule() async {
    if (!mounted) return;

    if (_teacherId == null || _teacherId!.isEmpty) {
      _showMessage('Data guru belum tersedia.');
      return;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TeacherScheduleFormScreen(),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await _loadSchedules();

      if (!mounted) return;

      _showMessage('Jadwal berhasil ditambahkan.');
    }
  }

  // ============================================================
  // EDIT SCHEDULE
  // ============================================================

  Future<void> _editSchedule(
      Map<String, dynamic> schedule,
      ) async {
    if (!mounted) return;

    final scheduleId = schedule['_id']?.toString();
    final teacherId = _teacherId;

    if (scheduleId == null || scheduleId.isEmpty) {
      _showMessage('ID jadwal tidak ditemukan.');
      return;
    }

    if (teacherId == null || teacherId.isEmpty) {
      _showMessage('ID guru tidak ditemukan.');
      return;
    }

    // Pastikan jadwal masih dimiliki oleh guru yang login.
    if (schedule['teacherId']?.toString() != teacherId) {
      _showMessage('Anda tidak memiliki akses ke jadwal ini.');
      return;
    }

    // Form mengambil ulang data berdasarkan scheduleId.
    // Tidak mengirim scheduleData karena konstruktor form
    // sebelumnya hanya menerima scheduleId.
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TeacherScheduleFormScreen(
          scheduleId: scheduleId,
        ),
      ),
    );

    if (!mounted) return;

    if (result == true) {
      await _loadSchedules();

      if (!mounted) return;

      _showMessage('Jadwal berhasil diperbarui.');
    }
  }

  // ============================================================
  // DELETE CONFIRMATION
  // ============================================================

  Future<void> _confirmDelete(
      Map<String, dynamic> schedule,
      ) async {
    if (_deleting) return;

    final scheduleId = schedule['_id']?.toString();
    final teacherId = _teacherId;

    if (scheduleId == null || scheduleId.isEmpty) {
      _showMessage('ID jadwal tidak ditemukan.');
      return;
    }

    if (teacherId == null || teacherId.isEmpty) {
      _showMessage('ID guru tidak ditemukan.');
      return;
    }

    if (schedule['teacherId']?.toString() != teacherId) {
      _showMessage('Anda tidak memiliki akses ke jadwal ini.');
      return;
    }

    // Mendukung field nama mata pelajaran dari data lama maupun baru.
    final subject = (
        schedule['subject'] ??
            schedule['courseTitle'] ??
            schedule['courseName'] ??
            'Jadwal'
    ).toString();

    final day = (schedule['day'] ?? '').toString();
    final start = (schedule['startTime'] ?? '').toString();
    final end = (schedule['endTime'] ?? '').toString();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Jadwal?'),
          content: Text(
            'Jadwal "$subject"\n'
                '$day, $start - $end\n\n'
                'Jadwal yang dihapus tidak dapat dikembalikan.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await _deleteSchedule(scheduleId);
  }

  // ============================================================
  // DELETE SCHEDULE
  // ============================================================

  Future<void> _deleteSchedule(String scheduleId) async {
    if (_deleting) return;

    final teacherId = _teacherId;

    if (teacherId == null || teacherId.isEmpty) {
      _showMessage('ID guru tidak ditemukan.');
      return;
    }

    setState(() {
      _deleting = true;
    });

    try {
      final scheduleRef =
      _firestore.collection('schedules').doc(scheduleId);

      // Periksa kepemilikan dan hapus secara atomik.
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(scheduleRef);

        if (!snapshot.exists) {
          throw Exception('Jadwal tidak ditemukan.');
        }

        final data = snapshot.data() ?? {};

        if (data['teacherId']?.toString() != teacherId) {
          throw Exception(
            'Anda tidak memiliki izin menghapus jadwal ini.',
          );
        }

        transaction.delete(scheduleRef);
      });

      if (!mounted) return;

      setState(() {
        _schedules.removeWhere(
              (schedule) => schedule['_id'] == scheduleId,
        );
        _deleting = false;
      });

      _showMessage('Jadwal berhasil dihapus.');
    } catch (e) {
      debugPrint('Gagal menghapus jadwal: $e');

      if (!mounted) return;

      setState(() {
        _deleting = false;
      });

      _showMessage('Gagal menghapus jadwal: $e');
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
        SnackBar(content: Text(message)),
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
        title: const Text('Jadwal Mengajar'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _refreshSchedules,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _loading || _teacherId == null
          ? null
          : FloatingActionButton.extended(
        onPressed: _deleting ? null : _addSchedule,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Jadwal'),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : _teacherId == null
          ? _buildTeacherError(theme)
          : RefreshIndicator(
        onRefresh: _refreshSchedules,
        child: _schedules.isEmpty
            ? _buildEmptyState(theme)
            : ListView(
          padding: const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            100,
          ),
          children: [
            _buildHeader(theme),
            const SizedBox(height: 20),
            ..._schedules.map(
                  (schedule) => _buildScheduleCard(
                schedule,
                theme,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TEACHER ERROR
  // ============================================================

  Widget _buildTeacherError(ThemeData theme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 100),
        Icon(
          Icons.person_search_outlined,
          size: 64,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 20),
        const Text(
          'Data Guru Tidak Ditemukan',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pastikan akun guru memiliki teacherDocId atau teacherId '
              'yang mengarah ke dokumen pada koleksi teachers.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _loadTeacher,
          icon: const Icon(Icons.refresh),
          label: const Text('Coba Lagi'),
        ),
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color:
              theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
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
                const Text(
                  'Jadwal Mengajar',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _teacherName,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${_schedules.length} jadwal',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
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
      Map<String, dynamic> schedule,
      ThemeData theme,
      ) {
    // Mendukung nama field dari format data lama maupun baru.
    final subject = (
        schedule['subject'] ??
            schedule['courseTitle'] ??
            schedule['courseName'] ??
            ''
    ).toString();

    final courseName = (
        schedule['courseName'] ??
            schedule['courseTitle'] ??
            ''
    ).toString();

    final className = (
        schedule['className'] ??
            schedule['classId'] ??
            ''
    ).toString();

    final day = (schedule['day'] ?? '').toString();
    final startTime = (schedule['startTime'] ?? '').toString();
    final endTime = (schedule['endTime'] ?? '').toString();
    final room = (schedule['room'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject.isEmpty ? 'Mata Pelajaran' : subject,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (courseName.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          courseName,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  enabled: !_deleting,
                  onSelected: (value) {
                    if (value == 'edit') {
                      _editSchedule(schedule);
                    } else if (value == 'delete') {
                      _confirmDelete(schedule);
                    }
                  },
                  itemBuilder: (context) {
                    return const [
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
                    ];
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // DAY + TIME
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$day • $startTime - $endTime',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // INFO
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.groups_outlined,
                    text: className.isEmpty ? 'Kelas' : className,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    icon: Icons.meeting_room_outlined,
                    text: room.isEmpty
                        ? 'Ruangan belum diisi'
                        : room,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INFO ITEM
  // ============================================================

  Widget _buildInfoItem({
    required IconData icon,
    required String text,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: Colors.grey.shade600,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState(ThemeData theme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 90),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.calendar_month_outlined,
            size: 40,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Belum Ada Jadwal',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Belum ada jadwal mengajar yang tersimpan untuk akun guru ini.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade600,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _deleting ? null : _addSchedule,
            icon: const Icon(Icons.add),
            label: const Text('Tambah Jadwal'),
          ),
        ),
      ],
    );
  }
}