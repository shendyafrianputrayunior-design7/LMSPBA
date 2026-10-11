
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class StudentAttendanceScreen extends StatefulWidget {
  final String classId;

  const StudentAttendanceScreen({
    super.key,
    required this.classId,
  });

  @override
  State<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState
    extends State<StudentAttendanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _loading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  // ============================================================
  // LOAD DATA ABSENSI SISWA
  // ============================================================

  Future<void> _loadAttendance() async {
    if (widget.classId.trim().isEmpty) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = 'Data kelas siswa belum tersedia.';
      });
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = 'Sesi login siswa tidak ditemukan.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _firestore
          .collection('attendance_sessions')
          .where('classId', isEqualTo: widget.classId)
          .get();

      final List<Map<String, dynamic>> sessions = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final sessionId = doc.id;

        // Membaca catatan absensi milik siswa yang sedang login.
        final recordDoc = await _firestore
            .collection('attendance_records')
            .doc('${sessionId}_${user.uid}')
            .get();

        final recordData = recordDoc.data();

        sessions.add({
          'id': sessionId,
          ...data,
          'studentStatus':
          recordData?['status']?.toString() ?? '',
          'studentNote':
          recordData?['note']?.toString() ?? '',
        });
      }

      // Urutkan berdasarkan nomor pertemuan.
      // Jika nomor sama, urutkan berdasarkan tanggal terbaru.
      sessions.sort((a, b) {
        final meetingA =
            int.tryParse('${a['meetingNumber'] ?? 0}') ?? 0;
        final meetingB =
            int.tryParse('${b['meetingNumber'] ?? 0}') ?? 0;

        if (meetingA != meetingB) {
          return meetingA.compareTo(meetingB);
        }

        return _parseDate(b['date']).compareTo(
          _parseDate(a['date']),
        );
      });

      if (!mounted) return;

      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Gagal memuat absensi siswa: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage = 'Gagal memuat data absensi. Silakan coba lagi.';
      });
    }
  }

  // ============================================================
  // DATE & TIME
  // ============================================================

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value != null) {
      final text = value.toString().trim();

      // Format dd/MM/yyyy
      final parts = text.split('/');
      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);

        if (day != null && month != null && year != null) {
          try {
            final parsed = DateTime(year, month, day);

            if (parsed.day == day &&
                parsed.month == month &&
                parsed.year == year) {
              return parsed;
            }
          } catch (_) {
            // Lanjut mencoba format lain.
          }
        }
      }

      final parsed = DateTime.tryParse(text);
      if (parsed != null) {
        return parsed;
      }
    }

    return DateTime(2000);
  }

  String _formatDate(dynamic value) {
    final date = _parseDate(value);

    if (date.year == 2000) return '-';

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _getTimeRange(Map<String, dynamic> session) {
    final start = (session['startTime'] ?? '').toString().trim();
    final end = (session['endTime'] ?? '').toString().trim();

    if (start.isEmpty && end.isEmpty) return 'Waktu belum ditentukan';
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;

    return '$start - $end';
  }

  // ============================================================
  // COURSE GROUPING
  // ============================================================

  List<Map<String, dynamic>> _getCourses() {
    final Map<String, Map<String, dynamic>> grouped = {};

    for (final session in _sessions) {
      final courseId = (session['courseId'] ?? '').toString().trim();

      // Data lama yang tidak mempunyai courseId tetap dikelompokkan
      // menggunakan nama mata pelajaran.
      final courseName = _getCourseName(session);
      final key = courseId.isNotEmpty
          ? courseId
          : 'name_$courseName';

      if (!grouped.containsKey(key)) {
        grouped[key] = {
          'id': key,
          'courseId': courseId,
          'courseName': courseName,
          'teacherName': _getTeacherName(session),
          'sessions': <Map<String, dynamic>>[],
        };
      }

      (grouped[key]!['sessions'] as List<Map<String, dynamic>>)
          .add(session);

      if ((grouped[key]!['teacherName'] as String).isEmpty) {
        grouped[key]!['teacherName'] = _getTeacherName(session);
      }
    }

    final courses = grouped.values.toList();

    courses.sort((a, b) {
      return (a['courseName'] as String)
          .toLowerCase()
          .compareTo((b['courseName'] as String).toLowerCase());
    });

    return courses;
  }

  String _getCourseName(Map<String, dynamic> session) {
    return (session['courseName'] ??
        session['courseTitle'] ??
        session['subject'] ??
        'Mata Pelajaran')
        .toString();
  }

  String _getTeacherName(Map<String, dynamic> session) {
    return (session['teacherName'] ?? session['teacher'] ?? '')
        .toString();
  }

  int _countRecorded(List<Map<String, dynamic>> sessions) {
    return sessions.where((session) {
      final status = (session['studentStatus'] ?? '')
          .toString()
          .toLowerCase();

      return ['hadir', 'izin', 'sakit', 'alpa'].contains(status);
    }).length;
  }

  // ============================================================
  // STATUS
  // ============================================================

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return 'Hadir';
      case 'izin':
        return 'Izin';
      case 'sakit':
        return 'Sakit';
      case 'alpa':
        return 'Alpa';
      default:
        return 'Belum Diabsen';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return Colors.green;
      case 'izin':
        return Colors.orange;
      case 'sakit':
        return Colors.blue;
      case 'alpa':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return Icons.check_circle_outline;
      case 'izin':
        return Icons.assignment_outlined;
      case 'sakit':
        return Icons.local_hospital_outlined;
      case 'alpa':
        return Icons.cancel_outlined;
      default:
        return Icons.hourglass_empty;
    }
  }

  bool _isClosed(Map<String, dynamic> session) {
    final status = (session['status'] ?? 'open')
        .toString()
        .toLowerCase();

    return status == 'closed' || status == 'selesai';
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  Future<void> _openCourse(
      Map<String, dynamic> course,
      ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _StudentCourseMeetingsPage(
          course: course,
          onRefresh: _loadAttendance,
        ),
      ),
    );

    if (mounted) {
      await _loadAttendance();
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
          'Absensi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _loadAttendance,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _buildMessageState(
        icon: Icons.error_outline,
        title: _errorMessage!,
        subtitle: 'Periksa koneksi internet lalu coba lagi.',
        actionLabel: 'Coba Lagi',
        onAction: _loadAttendance,
      );
    }

    final courses = _getCourses();

    if (courses.isEmpty) {
      return _buildMessageState(
        icon: Icons.fact_check_outlined,
        title: 'Belum ada absensi',
        subtitle:
        'Mata pelajaran akan muncul di sini setelah guru membuat pertemuan absensi.',
        actionLabel: 'Muat Ulang',
        onAction: _loadAttendance,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAttendance,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.fact_check_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rekap Kehadiran',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '${courses.length} mata pelajaran · '
                            '${_sessions.length} pertemuan',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Mata Pelajaran',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Pilih mata pelajaran untuk melihat riwayat absensi.',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          ...courses.map((course) => _buildCourseCard(course)),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    final theme = Theme.of(context);
    final sessions =
    course['sessions'] as List<Map<String, dynamic>>;
    final recorded = _countRecorded(sessions);
    final teacherName = (course['teacherName'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _openCourse(course),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.menu_book_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['courseName'].toString(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (teacherName.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        teacherName,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _SmallTag(
                          icon: Icons.calendar_month_outlined,
                          text: '${sessions.length} pertemuan',
                        ),
                        _SmallTag(
                          icon: Icons.check_circle_outline,
                          text: '$recorded tercatat',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: _loadAttendance,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 100),
          Icon(
            icon,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh),
              label: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HALAMAN DAFTAR PERTEMUAN PER MATA PELAJARAN
// ============================================================

class _StudentCourseMeetingsPage extends StatelessWidget {
  final Map<String, dynamic> course;
  final Future<void> Function() onRefresh;

  const _StudentCourseMeetingsPage({
    required this.course,
    required this.onRefresh,
  });

  String _formatDate(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value != null) {
      final text = value.toString().trim();
      final parts = text.split('/');

      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);

        if (day != null && month != null && year != null) {
          date = DateTime(year, month, day);
        }
      }

      date ??= DateTime.tryParse(text);
    }

    if (date == null || date.year == 2000) return '-';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  bool _isClosed(Map<String, dynamic> session) {
    final status = (session['status'] ?? 'open')
        .toString()
        .toLowerCase();

    return status == 'closed' || status == 'selesai';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessions =
    course['sessions'] as List<Map<String, dynamic>>;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          course['courseName'].toString(),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: sessions.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 150),
            Icon(
              Icons.event_busy_outlined,
              size: 60,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Center(child: Text('Belum ada pertemuan.')),
          ],
        )
            : ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_note_outlined,
                    size: 30,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${sessions.length} Pertemuan',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pilih pertemuan untuk melihat status kehadiran.',
                          style: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Riwayat Pertemuan',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...sessions.map((session) {
              final number = session['meetingNumber'] ?? '-';
              final date = _formatDate(session['date']);
              final start =
              (session['startTime'] ?? '').toString();
              final end =
              (session['endTime'] ?? '').toString();
              final time = start.isEmpty
                  ? (end.isEmpty ? 'Waktu belum ditentukan' : end)
                  : (end.isEmpty ? start : '$start - $end');
              final closed = _isClosed(session);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor:
                    theme.colorScheme.onPrimaryContainer,
                    child: Text(
                      '$number',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Text(
                    'Pertemuan $number',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MeetingInfo(
                          icon: Icons.calendar_today_outlined,
                          text: date,
                        ),
                        const SizedBox(height: 5),
                        _MeetingInfo(
                          icon: Icons.access_time_outlined,
                          text: time,
                        ),
                        const SizedBox(height: 9),
                        _MeetingStatus(closed: closed),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            _StudentAttendanceDetailPage(
                              session: session,
                            ),
                      ),
                    );
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HALAMAN DETAIL ABSENSI SISWA
// ============================================================

class _StudentAttendanceDetailPage extends StatelessWidget {
  final Map<String, dynamic> session;

  const _StudentAttendanceDetailPage({
    required this.session,
  });

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return 'Hadir';
      case 'izin':
        return 'Izin';
      case 'sakit':
        return 'Sakit';
      case 'alpa':
        return 'Alpa';
      default:
        return 'Belum Diabsen';
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return Colors.green;
      case 'izin':
        return Colors.orange;
      case 'sakit':
        return Colors.blue;
      case 'alpa':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return Icons.check_circle_outline;
      case 'izin':
        return Icons.assignment_outlined;
      case 'sakit':
        return Icons.local_hospital_outlined;
      case 'alpa':
        return Icons.cancel_outlined;
      default:
        return Icons.hourglass_empty;
    }
  }

  String _formatDate(dynamic value) {
    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value != null) {
      final text = value.toString().trim();
      final parts = text.split('/');

      if (parts.length == 3) {
        final day = int.tryParse(parts[0]);
        final month = int.tryParse(parts[1]);
        final year = int.tryParse(parts[2]);

        if (day != null && month != null && year != null) {
          date = DateTime(year, month, day);
        }
      }

      date ??= DateTime.tryParse(text);
    }

    if (date == null || date.year == 2000) return '-';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final courseName = (session['courseName'] ??
        session['courseTitle'] ??
        session['subject'] ??
        'Mata Pelajaran')
        .toString();
    final teacherName =
    (session['teacherName'] ?? session['teacher'] ?? 'Guru')
        .toString();
    final status = (session['studentStatus'] ?? '').toString();
    final note = (session['studentNote'] ?? '').toString().trim();
    final color = _getStatusColor(status);
    final number = session['meetingNumber'] ?? '-';
    final closed = (session['status'] ?? 'open')
        .toString()
        .toLowerCase() ==
        'closed' ||
        (session['status'] ?? '').toString().toLowerCase() == 'selesai';

    final start = (session['startTime'] ?? '').toString();
    final end = (session['endTime'] ?? '').toString();
    final time = start.isEmpty
        ? (end.isEmpty ? 'Belum ditentukan' : end)
        : (end.isEmpty ? start : '$start - $end');

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detail Absensi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.fact_check_outlined,
                  size: 34,
                  color: Colors.white,
                ),
                const SizedBox(height: 16),
                Text(
                  courseName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pertemuan $number',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.person_outline,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        teacherName,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Informasi Pertemuan',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _DetailInfoCard(
            items: [
              _DetailInfo(
                icon: Icons.calendar_today_outlined,
                label: 'Tanggal',
                value: _formatDate(session['date']),
              ),
              _DetailInfo(
                icon: Icons.access_time_outlined,
                label: 'Waktu',
                value: time,
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Status Kehadiran Saya',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: color.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  _getStatusIcon(status),
                  color: color,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  _getStatusLabel(status),
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  status.isEmpty
                      ? 'Guru belum mencatat status kehadiranmu.'
                      : 'Status ini dicatat oleh guru.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 22),
            const Text(
              'Catatan Guru',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  closed ? Icons.lock_outline : Icons.visibility_outlined,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    closed
                        ? 'Pertemuan telah ditutup oleh guru. Riwayat tetap dapat dilihat.'
                        : 'Absensi dikelola oleh guru. Status kehadiran tidak dapat diubah dari akun siswa.',
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// WIDGET PENDUKUNG
// ============================================================

class _SmallTag extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallTag({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MeetingInfo({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _MeetingStatus extends StatelessWidget {
  final bool closed;

  const _MeetingStatus({required this.closed});

  @override
  Widget build(BuildContext context) {
    final color = closed ? Colors.grey : Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            closed ? Icons.lock_outline : Icons.lock_open_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            closed ? 'Ditutup' : 'Tersedia',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailInfo {
  final IconData icon;
  final String label;
  final String value;

  const _DetailInfo({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _DetailInfoCard extends StatelessWidget {
  final List<_DetailInfo> items;

  const _DetailInfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    items[i].icon,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].label,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        items[i].value,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (i != items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }
}
