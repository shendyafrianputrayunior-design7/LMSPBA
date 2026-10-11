
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  State<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState extends State<TeacherAttendanceScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _teacherName = '';
  String? _teacherId;
  List<String> _teacherIds = [];
  List<Map<String, dynamic>> _courses = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // =========================================================
  // MENDAPATKAN ID DOKUMEN GURU
  // =========================================================

  Future<String?> _getTeacherDocumentId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final userDoc =
    await _firestore.collection('users').doc(user.uid).get();

    final userData = userDoc.data() ?? <String, dynamic>{};
    final savedTeacherId = userData['teacherId']?.toString().trim();

    if (savedTeacherId != null && savedTeacherId.isNotEmpty) {
      final teacherDoc = await _firestore
          .collection('teachers')
          .doc(savedTeacherId)
          .get();

      if (teacherDoc.exists) return savedTeacherId;
    }

    final email = user.email?.trim();

    if (email != null && email.isNotEmpty) {
      final result = await _firestore
          .collection('teachers')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (result.docs.isNotEmpty) return result.docs.first.id;
    }

    return null;
  }

  // =========================================================
  // MEMUAT COURSE GURU
  // =========================================================

  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);

    final user = _auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _courses = [];
      });
      return;
    }

    try {
      final teacherId = await _getTeacherDocumentId();

      if (teacherId == null || teacherId.isEmpty) {
        if (!mounted) return;

        setState(() {
          _teacherId = null;
          _teacherIds = [];
          _teacherName = '';
          _courses = [];
          _loading = false;
        });

        _showMessage('Data guru tidak ditemukan.');
        return;
      }

      final userDoc =
      await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? <String, dynamic>{};

      final teacherName = (userData['name'] ??
          userData['username'] ??
          user.displayName ??
          'Guru')
          .toString();

      final teacherIds = <String>{
        teacherId,
        user.uid,
      }.where((id) => id.isNotEmpty).toList();

      final courseSnapshot = await _firestore
          .collection('courses')
          .where('teacherId', whereIn: teacherIds)
          .get();

      // Setiap dokumen course hanya ditampilkan satu kali.
      final courseMap = <String, Map<String, dynamic>>{};

      for (final doc in courseSnapshot.docs) {
        final data = doc.data();

        courseMap[doc.id] = {
          'id': doc.id,
          'title': (data['title'] ?? 'Course').toString(),
          'classId': (data['classId'] ?? '').toString(),
          'className':
          (data['className'] ?? data['classId'] ?? '-').toString(),
          'teacherId': (data['teacherId'] ?? teacherId).toString(),
        };
      }

      final courses = courseMap.values.toList()
        ..sort((a, b) => a['title']
            .toString()
            .toLowerCase()
            .compareTo(b['title'].toString().toLowerCase()));

      if (!mounted) return;

      setState(() {
        _teacherId = teacherId;
        _teacherIds = teacherIds;
        _teacherName = teacherName;
        _courses = courses;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Gagal memuat course absensi: $e');

      if (!mounted) return;

      setState(() => _loading = false);
      _showMessage('Gagal memuat data course.');
    }
  }

  // =========================================================
  // MEMBUKA DAFTAR PERTEMUAN
  // =========================================================

  Future<void> _openCourse(Map<String, dynamic> course) async {
    if (_teacherId == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeacherAttendanceMeetingsPage(
          course: course,
          teacherId: _teacherId!,
          teacherIds: _teacherIds,
          teacherName: _teacherName,
        ),
      ),
    );

    if (mounted) _loadData();
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadData,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: _courses.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.18,
            ),
            Icon(
              Icons.menu_book_rounded,
              size: 64,
              color: colors.primary.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum Ada Course',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Course yang terhubung dengan akun guru akan muncul di sini.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        )
            : ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: _courses.length,
          separatorBuilder: (_, __) =>
          const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildCourseCard(_courses[index]);
          },
        ),
      ),
    );
  }

  Widget _buildCourseCard(Map<String, dynamic> course) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _openCourse(course),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors.outline.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  color: colors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['title'].toString(),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Kelas: ${course['className']}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 17,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Kelola Pertemuan',
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// HALAMAN KELOLA PERTEMUAN
// =====================================================================

class TeacherAttendanceMeetingsPage extends StatefulWidget {
  final Map<String, dynamic> course;
  final String teacherId;
  final List<String> teacherIds;
  final String teacherName;

  const TeacherAttendanceMeetingsPage({
    super.key,
    required this.course,
    required this.teacherId,
    required this.teacherIds,
    required this.teacherName,
  });

  @override
  State<TeacherAttendanceMeetingsPage> createState() =>
      _TeacherAttendanceMeetingsPageState();
}

class _TeacherAttendanceMeetingsPageState
    extends State<TeacherAttendanceMeetingsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  bool _creating = false;
  List<Map<String, dynamic>> _meetings = [];

  String get _courseId => widget.course['id'].toString();
  String get _classId => widget.course['classId'].toString();

  @override
  void initState() {
    super.initState();
    _loadMeetings();
  }

  // =========================================================
  // MEMUAT PERTEMUAN BERDASARKAN COURSE
  // =========================================================

  Future<void> _loadMeetings() async {
    if (mounted) setState(() => _loading = true);

    try {
      final snapshot = await _firestore
          .collection('attendance_sessions')
          .where('courseId', isEqualTo: _courseId)
          .get();

      final meetings = snapshot.docs
          .where((doc) {
        final data = doc.data();

        final sessionClassId =
        (data['classId'] ?? '').toString();
        final sessionTeacherId =
        (data['teacherId'] ?? '').toString();

        return sessionClassId == _classId &&
            widget.teacherIds.contains(sessionTeacherId);
      })
          .map((doc) => <String, dynamic>{
        'id': doc.id,
        ...doc.data(),
      })
          .toList();

      meetings.sort((a, b) {
        final aNumber = _meetingNumber(a);
        final bNumber = _meetingNumber(b);

        if (aNumber != bNumber) {
          return aNumber.compareTo(bNumber);
        }

        return _parseAttendanceDate(a['date'])
            .compareTo(_parseAttendanceDate(b['date']));
      });

      if (!mounted) return;

      setState(() {
        _meetings = meetings;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Gagal memuat pertemuan: $e');

      if (!mounted) return;

      setState(() => _loading = false);
      _showMessage('Gagal memuat daftar pertemuan.');
    }
  }

  int _meetingNumber(Map<String, dynamic> meeting) {
    final value = meeting['meetingNumber'];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  // =========================================================
  // MEMBUAT PERTEMUAN
  // =========================================================

  Future<void> _createMeeting() async {
    if (_creating) return;

    final dateController = TextEditingController(
      text: _formatAttendanceDate(DateTime.now()),
    );
    final startController = TextEditingController(text: '07:00');
    final endController = TextEditingController(text: '08:00');
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Buat Pertemuan'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.course['title'].toString(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: dateController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Tanggal',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_month_rounded),
                    ),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: dialogContext,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );

                      if (selected != null) {
                        dateController.text =
                            _formatAttendanceDate(selected);
                      }
                    },
                    validator: (value) =>
                    value == null || value.isEmpty
                        ? 'Tanggal wajib diisi'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: startController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Mulai',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.access_time_rounded),
                          ),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: dialogContext,
                              initialTime:
                              const TimeOfDay(hour: 7, minute: 0),
                            );

                            if (time != null) {
                              startController.text =
                                  _formatAttendanceTime(time);
                            }
                          },
                          validator: (value) =>
                          value == null || value.isEmpty
                              ? 'Pilih waktu'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: endController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Selesai',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.access_time_rounded),
                          ),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: dialogContext,
                              initialTime:
                              const TimeOfDay(hour: 8, minute: 0),
                            );

                            if (time != null) {
                              endController.text =
                                  _formatAttendanceTime(time);
                            }
                          },
                          validator: (value) =>
                          value == null || value.isEmpty
                              ? 'Pilih waktu'
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: const Text('Buat Pertemuan'),
            ),
          ],
        );
      },
    );

    if (result != true) {
      dateController.dispose();
      startController.dispose();
      endController.dispose();
      return;
    }

    if (!mounted) {
      dateController.dispose();
      startController.dispose();
      endController.dispose();
      return;
    }

    setState(() => _creating = true);

    try {
      // Nomor pertemuan selalu lebih besar daripada nomor yang sudah ada.
      final highestNumber = _meetings.fold<int>(
        0,
            (highest, meeting) =>
        _meetingNumber(meeting) > highest
            ? _meetingNumber(meeting)
            : highest,
      );

      final nextNumber =
          (_meetings.length > highestNumber
              ? _meetings.length
              : highestNumber) +
              1;

      await _firestore.collection('attendance_sessions').add({
        'teacherId': widget.teacherId,
        'teacherName': widget.teacherName,
        'courseId': _courseId,
        'courseName': widget.course['title'].toString(),
        'classId': _classId,
        'className': widget.course['className'].toString(),
        'meetingNumber': nextNumber,
        'date': dateController.text,
        'startTime': startController.text,
        'endTime': endController.text,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _showMessage('Pertemuan $nextNumber berhasil dibuat.');
      await _loadMeetings();
    } catch (e) {
      debugPrint('Gagal membuat pertemuan: $e');
      _showMessage('Gagal membuat pertemuan.');
    } finally {
      dateController.dispose();
      startController.dispose();
      endController.dispose();

      if (mounted) setState(() => _creating = false);
    }
  }

  // =========================================================
  // MEMBUKA DAFTAR SISWA
  // =========================================================

  Future<void> _openMeeting(Map<String, dynamic> meeting) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _TeacherAttendanceSessionPage(
          session: meeting,
        ),
      ),
    );

    if (mounted) _loadMeetings();
  }

  // =========================================================
  // MENGHAPUS PERTEMUAN DAN RECORD ABSENSI
  // =========================================================

  Future<void> _deleteMeeting(Map<String, dynamic> meeting) async {
    final sessionId = meeting['id']?.toString() ?? '';
    if (sessionId.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus Pertemuan?'),
        content: const Text(
          'Pertemuan dan seluruh catatan absensi siswa di dalamnya akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final records = await _firestore
          .collection('attendance_records')
          .where('sessionId', isEqualTo: sessionId)
          .get();

      // Batasi jumlah operasi per batch agar aman untuk banyak siswa.
      for (var i = 0; i < records.docs.length; i += 400) {
        final batch = _firestore.batch();
        final end = (i + 400 < records.docs.length)
            ? i + 400
            : records.docs.length;

        for (final doc in records.docs.sublist(i, end)) {
          batch.delete(doc.reference);
        }

        await batch.commit();
      }

      await _firestore
          .collection('attendance_sessions')
          .doc(sessionId)
          .delete();

      _showMessage('Pertemuan berhasil dihapus.');
      await _loadMeetings();
    } catch (e) {
      debugPrint('Gagal menghapus pertemuan: $e');
      _showMessage('Gagal menghapus pertemuan.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Pertemuan'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadMeetings,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : _createMeeting,
        icon: _creating
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : const Icon(Icons.add_rounded),
        label: const Text('Buat Pertemuan'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadMeetings,
        child: _meetings.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.16,
            ),
            Icon(
              Icons.calendar_month_rounded,
              size: 64,
              color: colors.primary.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Pertemuan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat pertemuan pertama untuk ${widget.course['title']}.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 100),
          ],
        )
            : ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: _meetings.length,
          separatorBuilder: (_, __) =>
          const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildMeetingCard(_meetings[index]);
          },
        ),
      ),
    );
  }

  Widget _buildMeetingCard(Map<String, dynamic> meeting) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final number = _meetingNumber(meeting);
    final date = (meeting['date'] ?? '-').toString();
    final start = (meeting['startTime'] ?? '-').toString();
    final end = (meeting['endTime'] ?? '-').toString();
    final status = (meeting['status'] ?? 'open').toString().toLowerCase();
    final isClosed = status == 'closed' || status == 'selesai';

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () => _openMeeting(meeting),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: colors.outline.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.event_note_rounded,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          number > 0 ? 'Pertemuan $number' : 'Pertemuan',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.course['title'].toString(),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        _deleteMeeting(meeting);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text('Hapus Pertemuan'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 16),
                  const SizedBox(width: 6),
                  Expanded(child: Text(date)),
                  const Icon(Icons.access_time_rounded, size: 16),
                  const SizedBox(width: 6),
                  Text('$start - $end'),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isClosed
                          ? Colors.grey.withOpacity(0.12)
                          : Colors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      isClosed ? 'Selesai' : 'Aktif',
                      style: TextStyle(
                        color: isClosed ? Colors.grey : Colors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Kelola Absensi',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 17,
                    color: colors.primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// HALAMAN KELOLA ABSENSI SISWA PADA SATU PERTEMUAN
// =====================================================================

class _TeacherAttendanceSessionPage extends StatefulWidget {
  final Map<String, dynamic> session;

  const _TeacherAttendanceSessionPage({
    required this.session,
  });

  @override
  State<_TeacherAttendanceSessionPage> createState() =>
      _TeacherAttendanceSessionPageState();
}

class _TeacherAttendanceSessionPageState
    extends State<_TeacherAttendanceSessionPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>> _students = [];

  final Map<String, String> _statuses = {};
  final Map<String, TextEditingController> _noteControllers = {};

  String get _sessionId => widget.session['id']?.toString() ?? '';
  String get _classId => widget.session['classId']?.toString() ?? '';

  bool get _isClosed {
    final status =
    widget.session['status']?.toString().toLowerCase();
    return status == 'closed' || status == 'selesai';
  }

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // =========================================================
  // MEMUAT SISWA DAN ABSENSI YANG SUDAH TERSIMPAN
  // =========================================================

  Future<void> _loadStudents() async {
    if (mounted) setState(() => _loading = true);

    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      final students = snapshot.docs
          .where((doc) {
        final data = doc.data();
        return (data['classId'] ?? '').toString() == _classId;
      })
          .map((doc) => <String, dynamic>{
        'id': doc.id,
        ...doc.data(),
      })
          .toList();

      students.sort((a, b) {
        final aName =
        (a['name'] ?? a['username'] ?? '').toString().toLowerCase();
        final bName =
        (b['name'] ?? b['username'] ?? '').toString().toLowerCase();
        return aName.compareTo(bName);
      });

      final recordSnapshot = await _firestore
          .collection('attendance_records')
          .where('sessionId', isEqualTo: _sessionId)
          .get();

      final savedStatuses = <String, String>{};
      final savedNotes = <String, String>{};

      for (final record in recordSnapshot.docs) {
        final data = record.data();
        final studentId = (data['studentId'] ?? '').toString();

        if (studentId.isNotEmpty) {
          savedStatuses[studentId] =
              (data['status'] ?? 'Alpa').toString();
          savedNotes[studentId] = (data['note'] ?? '').toString();
        }
      }

      // Hindari controller ganda ketika daftar dimuat ulang.
      for (final controller in _noteControllers.values) {
        controller.dispose();
      }

      _noteControllers.clear();
      _statuses.clear();

      for (final student in students) {
        final id = student['id'].toString();
        _statuses[id] = savedStatuses[id] ?? 'Alpa';
        _noteControllers[id] = TextEditingController(
          text: savedNotes[id] ?? '',
        );
      }

      if (!mounted) return;

      setState(() {
        _students = students;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Gagal memuat daftar siswa: $e');

      if (!mounted) return;

      setState(() => _loading = false);
      _showMessage('Gagal memuat daftar siswa.');
    }
  }

  // =========================================================
  // SIMPAN ABSENSI
  // =========================================================

  Future<void> _saveAttendance() async {
    if (_isClosed || _saving) return;

    if (_students.isEmpty) {
      _showMessage('Tidak ada siswa di kelas ini.');
      return;
    }

    setState(() => _saving = true);

    try {
      // Batasi operasi per batch untuk menghindari batas Firestore.
      for (var i = 0; i < _students.length; i += 400) {
        final batch = _firestore.batch();
        final end =
        (i + 400 < _students.length) ? i + 400 : _students.length;

        for (final student in _students.sublist(i, end)) {
          final studentId = student['id'].toString();
          final studentName =
          (student['name'] ?? student['username'] ?? 'Siswa')
              .toString();

          final status = _statuses[studentId] ?? 'Alpa';
          final note = _noteControllers[studentId]?.text.trim() ?? '';
          final docId = '${_sessionId}_$studentId';

          final reference =
          _firestore.collection('attendance_records').doc(docId);

          batch.set(
            reference,
            {
              'sessionId': _sessionId,
              'studentId': studentId,
              'studentName': studentName,
              'classId': _classId,
              'status': status,
              'note': note,
              'submittedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        await batch.commit();
      }

      if (!mounted) return;
      _showMessage('Absensi berhasil disimpan.');
    } catch (e) {
      debugPrint('Gagal menyimpan absensi: $e');

      if (!mounted) return;
      _showMessage('Gagal menyimpan absensi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // =========================================================
  // TUTUP ABSENSI
  // Simpan perubahan terlebih dahulu, lalu tutup sesi.
  // =========================================================

  Future<void> _closeSession() async {
    if (_isClosed || _saving) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tutup Absensi?'),
        content: const Text(
          'Perubahan absensi akan disimpan terlebih dahulu. Setelah sesi ditutup, absensi tidak dapat diubah lagi melalui halaman ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Simpan dan Tutup'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _saveAttendance();

    if (!mounted) return;

    // Jika penyimpanan gagal, jangan tutup sesi.
    // Status saving sudah kembali false setelah _saveAttendance.
    // Periksa kembali bahwa data dapat ditulis sebelum mengubah status.
    try {
      await _firestore
          .collection('attendance_sessions')
          .doc(_sessionId)
          .update({
        'status': 'closed',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showMessage('Pertemuan berhasil ditutup.');
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Gagal menutup absensi: $e');

      if (!mounted) return;
      _showMessage('Gagal menutup absensi.');
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Hadir':
        return Colors.green;
      case 'Izin':
        return Colors.orange;
      case 'Sakit':
        return Colors.blue;
      default:
        return Colors.red;
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final meetingNumber = widget.session['meetingNumber'];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          meetingNumber == null
              ? 'Kelola Absensi'
              : 'Absensi Pertemuan $meetingNumber',
        ),
        actions: [
          if (!_isClosed)
            IconButton(
              onPressed: _saving ? null : _saveAttendance,
              icon: const Icon(Icons.save_rounded),
              tooltip: 'Simpan absensi',
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          _buildSessionHeader(),
          _buildSummary(),
          Expanded(
            child: _students.isEmpty
                ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Tidak ada siswa yang ditemukan untuk kelas ${widget.session['className'] ?? _classId}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            )
                : RefreshIndicator(
              onRefresh: _loadStudents,
              child: ListView.separated(
                physics:
                const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  24,
                ),
                itemCount: _students.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  return _buildStudentCard(_students[index]);
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: !_isClosed && !_loading
          ? SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _closeSession,
                  icon: const Icon(Icons.lock_outline_rounded),
                  label: const Text('Tutup Absensi'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _saveAttendance,
                  icon: _saving
                      ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.save_rounded),
                  label: const Text('Simpan'),
                ),
              ),
            ],
          ),
        ),
      )
          : null,
    );
  }

  // =========================================================
  // HEADER PERTEMUAN
  // =========================================================

  Widget _buildSessionHeader() {
    final theme = Theme.of(context);
    final meetingNumber = widget.session['meetingNumber'];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meetingNumber == null
                ? (widget.session['courseName'] ?? 'Course').toString()
                : 'Pertemuan $meetingNumber',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text('Course: ${widget.session['courseName'] ?? '-'}'),
          Text('Kelas: ${widget.session['className'] ?? _classId}'),
          Text('Tanggal: ${widget.session['date'] ?? '-'}'),
          Text(
            'Waktu: ${widget.session['startTime'] ?? '-'} - ${widget.session['endTime'] ?? '-'}',
          ),
          if (_isClosed) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.lock_rounded, size: 16, color: Colors.grey),
                SizedBox(width: 6),
                Text(
                  'Absensi sudah ditutup',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================
  // RINGKASAN ABSENSI
  // =========================================================

  Widget _buildSummary() {
    int hadir = 0;
    int izin = 0;
    int sakit = 0;
    int alpa = 0;

    for (final student in _students) {
      switch (_statuses[student['id'].toString()] ?? 'Alpa') {
        case 'Hadir':
          hadir++;
          break;
        case 'Izin':
          izin++;
          break;
        case 'Sakit':
          sakit++;
          break;
        default:
          alpa++;
      }
    }

    return SizedBox(
      height: 78,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildSummaryItem('Hadir', hadir, Colors.green),
          _buildSummaryItem('Izin', izin, Colors.orange),
          _buildSummaryItem('Sakit', sakit, Colors.blue),
          _buildSummaryItem('Alpa', alpa, Colors.red),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String title, int count, Color color) {
    return Container(
      width: 82,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // KARTU SISWA
  // =========================================================

  Widget _buildStudentCard(Map<String, dynamic> student) {
    final colors = Theme.of(context).colorScheme;

    final studentId = student['id'].toString();
    final name =
    (student['name'] ?? student['username'] ?? 'Siswa').toString();
    final status = _statuses[studentId] ?? 'Alpa';
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: color.withOpacity(0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'S',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_isClosed)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (!_isClosed) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatusButton(
                    studentId,
                    'Hadir',
                    Icons.check_circle_outline_rounded,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildStatusButton(
                    studentId,
                    'Izin',
                    Icons.event_note_rounded,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildStatusButton(
                    studentId,
                    'Sakit',
                    Icons.medical_services_outlined,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildStatusButton(
                    studentId,
                    'Alpa',
                    Icons.cancel_outlined,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteControllers[studentId],
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ] else if ((_noteControllers[studentId]?.text ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Catatan: ${_noteControllers[studentId]!.text}',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusButton(
      String studentId,
      String status,
      IconData icon,
      Color color,
      ) {
    final selected = _statuses[studentId] == status;

    return InkWell(
      onTap: () {
        setState(() => _statuses[studentId] = status);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(
          vertical: 8,
          horizontal: 3,
        ),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.15)
              : color.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? color : color.withOpacity(0.18),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(height: 3),
            Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
// HELPER FORMAT TANGGAL DAN WAKTU
// =====================================================================

DateTime _parseAttendanceDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;

  if (value != null) {
    final text = value.toString();

    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;

    final parts = text.split('/');
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      final year = int.tryParse(parts[2]);

      if (day != null && month != null && year != null) {
        return DateTime(year, month, day);
      }
    }
  }

  return DateTime(2000);
}

String _formatAttendanceDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}

String _formatAttendanceTime(TimeOfDay time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}
