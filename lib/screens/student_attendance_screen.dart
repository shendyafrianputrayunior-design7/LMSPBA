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
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  bool _loading = true;
  String? _errorMessage;

  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  // ============================================================
  // LOAD DATA ABSENSI
  // ============================================================

  Future<void> _loadAttendance() async {
    if (widget.classId.isEmpty) {
      setState(() {
        _loading = false;
        _errorMessage = 'Data kelas siswa belum tersedia.';
      });
      return;
    }

    final user = _auth.currentUser;

    if (user == null) {
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
          .where(
        'classId',
        isEqualTo: widget.classId,
      )
          .get();

      final List<Map<String, dynamic>> sessions = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final sessionId = doc.id;

        // Hanya membaca record absensi milik siswa.
        final recordDoc = await _firestore
            .collection('attendance_records')
            .doc('${sessionId}_${user.uid}')
            .get();

        String status = '';
        String note = '';

        if (recordDoc.exists) {
          final recordData = recordDoc.data();

          status =
              (recordData?['status'] ?? '').toString();

          note =
              (recordData?['note'] ?? '').toString();
        }

        sessions.add({
          'id': sessionId,
          ...data,
          'studentStatus': status,
          'studentNote': note,
        });
      }

      // Urutkan dari sesi terbaru.
      sessions.sort((a, b) {
        final dateA = _parseDate(a['date']);
        final dateB = _parseDate(b['date']);

        return dateB.compareTo(dateA);
      });

      if (!mounted) return;

      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage =
        'Gagal memuat data absensi.';
      });
    }
  }

  // ============================================================
  // DATE
  // ============================================================

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value != null) {
      final parsed =
      DateTime.tryParse(value.toString());

      if (parsed != null) {
        return parsed;
      }
    }

    return DateTime(2000);
  }

  String _formatDate(dynamic value) {
    final date = _parseDate(value);

    if (date.year == 2000) {
      return '-';
    }

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

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
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

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
      String message, {
        bool success = false,
      }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
        success ? Colors.green : Colors.red,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Absensi'),
        centerTitle: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildError();
    }

    if (_sessions.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAttendance,
        child: ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height:
              MediaQuery.of(context).size.height *
                  0.35,
            ),

            const Icon(
              Icons.fact_check_outlined,
              size: 64,
              color: Colors.grey,
            ),

            const SizedBox(height: 16),

            const Center(
              child: Text(
                'Belum ada data absensi.',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                  FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 6),

            Center(
              child: Text(
                'Data absensi dari guru akan muncul di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAttendance,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24,
        ),
        itemCount: _sessions.length,
        itemBuilder: (context, index) {
          final session = _sessions[index];

          return _buildAttendanceCard(session);
        },
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return RefreshIndicator(
      onRefresh: _loadAttendance,
      child: ListView(
        physics:
        const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height:
            MediaQuery.of(context).size.height *
                0.3,
          ),

          const Icon(
            Icons.error_outline,
            size: 56,
            color: Colors.redAccent,
          ),

          const SizedBox(height: 16),

          Center(
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Center(
            child: OutlinedButton(
              onPressed: _loadAttendance,
              child: const Text('Coba Lagi'),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ATTENDANCE CARD
  // ============================================================

  Widget _buildAttendanceCard(
      Map<String, dynamic> session,
      ) {
    final courseName =
    (session['courseName'] ??
        session['courseTitle'] ??
        session['subject'] ??
        'Mata Pelajaran')
        .toString();

    final teacherName =
    (session['teacherName'] ??
        session['teacher'] ??
        'Guru')
        .toString();

    final date =
    _formatDate(session['date']);

    final startTime =
    (session['startTime'] ?? '').toString();

    final endTime =
    (session['endTime'] ?? '').toString();

    final room =
    (session['room'] ?? '').toString();

    final status =
    (session['studentStatus'] ?? '')
        .toString();

    final note =
    (session['studentNote'] ?? '')
        .toString();

    final statusLabel =
    _getStatusLabel(status);

    final statusColor =
    _getStatusColor(status);

    final sessionStatus =
    (session['status'] ?? 'open')
        .toString()
        .toLowerCase();

    final isClosed =
        sessionStatus == 'closed' ||
            sessionStatus == 'selesai';

    return Card(
      margin:
      const EdgeInsets.only(bottom: 14),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.circular(18),
      ),
      child: Padding(
        padding:
        const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Row(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration:
                  BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(
                      alpha: 0.1,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Icon(
                    Icons.fact_check_outlined,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
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
                        style:
                        const TextStyle(
                          fontSize: 16,
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        teacherName,
                        style: TextStyle(
                          fontSize: 13,
                          color:
                          Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Container(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration:
                  BoxDecoration(
                    color: statusColor
                        .withValues(
                      alpha: 0.1,
                    ),
                    borderRadius:
                    BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                      FontWeight.w600,
                      color:
                      statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Divider(height: 1),

            const SizedBox(height: 14),

            // ==================================================
            // INFO
            // ==================================================

            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                _InfoItem(
                  icon: Icons
                      .calendar_today_outlined,
                  text: date,
                ),

                if (startTime.isNotEmpty)
                  _InfoItem(
                    icon: Icons
                        .access_time_outlined,
                    text: endTime.isEmpty
                        ? startTime
                        : '$startTime - $endTime',
                  ),

                if (room.isNotEmpty)
                  _InfoItem(
                    icon: Icons
                        .room_outlined,
                    text: room,
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // ==================================================
            // STATUS ABSENSI
            // ==================================================

            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.all(14),
              decoration:
              BoxDecoration(
                color: statusColor
                    .withValues(
                  alpha: 0.06,
                ),
                borderRadius:
                BorderRadius.circular(
                  12,
                ),
                border: Border.all(
                  color: statusColor
                      .withValues(
                    alpha: 0.2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(status),
                    color: statusColor,
                    size: 22,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          'Status Absensi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors
                                .grey.shade600,
                          ),
                        ),

                        const SizedBox(height: 2),

                        Text(
                          statusLabel,
                          style:
                          TextStyle(
                            fontSize: 14,
                            fontWeight:
                            FontWeight.w600,
                            color:
                            statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // CATATAN DARI GURU
            // ==================================================

            if (note.isNotEmpty) ...[
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(14),
                decoration:
                BoxDecoration(
                  color:
                  Colors.grey.shade50,
                  borderRadius:
                  BorderRadius.circular(
                    12,
                  ),
                ),
                child: Row(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Icon(
                      Icons
                          .notes_outlined,
                      size: 20,
                      color:
                      Colors.grey.shade600,
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                        children: [
                          Text(
                            'Catatan Guru',
                            style:
                            TextStyle(
                              fontSize: 12,
                              color: Colors
                                  .grey.shade600,
                            ),
                          ),

                          const SizedBox(
                            height: 3,
                          ),

                          Text(
                            note,
                            style:
                            const TextStyle(
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // ==================================================
            // INFO SESI
            // ==================================================

            Container(
              width: double.infinity,
              padding:
              const EdgeInsets
                  .symmetric(
                vertical: 10,
                horizontal: 12,
              ),
              decoration:
              BoxDecoration(
                color:
                Colors.grey.shade100,
                borderRadius:
                BorderRadius.circular(
                  10,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isClosed
                        ? Icons.lock_outline
                        : Icons
                        .visibility_outlined,
                    size: 17,
                    color:
                    Colors.grey.shade600,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      isClosed
                          ? 'Sesi absensi sudah ditutup.'
                          : 'Absensi dikelola oleh guru.',
                      style:
                      TextStyle(
                        fontSize: 12.5,
                        color:
                        Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STATUS ICON
  // ============================================================

  IconData _getStatusIcon(
      String status,
      ) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return Icons
            .check_circle_outline;

      case 'izin':
        return Icons
            .assignment_outlined;

      case 'sakit':
        return Icons
            .local_hospital_outlined;

      case 'alpa':
        return Icons
            .cancel_outlined;

      default:
        return Icons
            .hourglass_empty_outlined;
    }
  }
}

// ============================================================
// INFO ITEM
// ============================================================

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoItem({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
      BuildContext context,
      ) {
    return Row(
      mainAxisSize:
      MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),

        const SizedBox(width: 6),

        Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            color:
            Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}