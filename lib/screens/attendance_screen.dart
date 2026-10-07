import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() =>
      _AttendanceScreenState();
}

class _AttendanceScreenState
    extends State<AttendanceScreen> {
  // =========================================================
  // STATE
  // =========================================================

  bool _loading = true;
  String? _errorMessage;

  String _classId = '';
  String _className = '';

  List<Map<String, String>> _attendanceData = [];

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  // =========================================================
  // LOAD ATTENDANCE
  // =========================================================

  Future<void> _loadAttendance() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          'Akun siswa tidak ditemukan.',
        );
      }

      // =====================================================
      // GET USER
      // =====================================================

      final userDoc =
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData =
          userDoc.data() ??
              <String, dynamic>{};

      final classId =
          userData['classId']?.toString() ??
              '';

      if (classId.isEmpty) {
        throw Exception(
          'Data kelas siswa belum tersedia.',
        );
      }

      // =====================================================
      // GET CLASS
      // =====================================================

      String className = classId;

      final classDoc =
      await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .get();

      if (classDoc.exists) {
        final classData =
            classDoc.data() ??
                <String, dynamic>{};

        className =
            classData['name']?.toString() ??
                classId;
      }

      // =====================================================
      // GET ATTENDANCE
      // =====================================================

      final attendanceSnapshot =
      await FirebaseFirestore.instance
          .collection('attendance')
          .where(
        'userId',
        isEqualTo: user.uid,
      )
          .get();

      // =====================================================
      // CONVERT DATA
      // =====================================================

      final attendance =
      <Map<String, String>>[];

      for (final doc
      in attendanceSnapshot.docs) {
        final data =
        doc.data();

        attendance.add({
          'id': doc.id,
          'subject':
          data['subject']
              ?.toString() ??
              '-',
          'date':
          data['date']
              ?.toString() ??
              '-',
          'status':
          data['status']
              ?.toString() ??
              '-',
          'note':
          data['note']
              ?.toString() ??
              '-',
        });
      }

      // =====================================================
      // SORT DATA
      // =====================================================

      attendance.sort(
            (a, b) {
          return b['id']!
              .compareTo(a['id']!);
        },
      );

      // =====================================================
      // UPDATE STATE
      // =====================================================

      if (!mounted) return;

      setState(() {
        _classId = classId;
        _className = className;
        _attendanceData = attendance;
        _loading = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint(
        'Gagal mengambil data attendance: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
        _errorMessage =
            e.toString().replaceFirst(
              'Exception: ',
              '',
            );
      });
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final theme =
    Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    return Scaffold(
      backgroundColor:
      theme.scaffoldBackgroundColor,

      // =====================================================
      // APP BAR
      // =====================================================

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
        theme.scaffoldBackgroundColor,
        title: const Text(
          'Attendance',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed:
            _loading
                ? null
                : _loadAttendance,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            tooltip: 'Refresh',
          ),
        ],
      ),

      // =====================================================
      // BODY
      // =====================================================

      body: SafeArea(
        child: _buildBody(
          context,
          colorScheme,
        ),
      ),
    );
  }

  // =========================================================
  // BODY
  // =========================================================

  Widget _buildBody(
      BuildContext context,
      ColorScheme colorScheme,
      ) {
    if (_loading) {
      return const Center(
        child:
        CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState(
        context,
        _errorMessage!,
      );
    }

    return RefreshIndicator(
      onRefresh:
      _loadAttendance,
      child: SingleChildScrollView(
        physics:
        const AlwaysScrollableScrollPhysics(
          parent:
          BouncingScrollPhysics(),
        ),
        padding:
        const EdgeInsets.fromLTRB(
          20,
          8,
          20,
          28,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // =================================================
            // HEADER
            // =================================================

            Text(
              'Kehadiran',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                fontWeight:
                FontWeight.w800,
              ),
            ),

            const SizedBox(
                height: 6),

            Text(
              _className.isNotEmpty
                  ? 'Riwayat kehadiran kamu di kelas $_className.'
                  : 'Lihat riwayat kehadiran kamu.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(
                height: 20),

            // =================================================
            // SUMMARY
            // =================================================

            _buildSummaryCard(
              context,
              colorScheme,
            ),

            const SizedBox(
                height: 26),

            // =================================================
            // TITLE
            // =================================================

            Text(
              'Riwayat Kehadiran',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                FontWeight.w800,
              ),
            ),

            const SizedBox(
                height: 14),

            // =================================================
            // EMPTY
            // =================================================

            if (_attendanceData.isEmpty)
              _buildEmptyState(
                context,
              ),

            // =================================================
            // ATTENDANCE LIST
            // =================================================

            ..._attendanceData.map(
                  (attendance) =>
                  _buildAttendanceCard(
                    context,
                    attendance,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // SUMMARY CARD
  // =========================================================

  Widget _buildSummaryCard(
      BuildContext context,
      ColorScheme colorScheme,
      ) {
    final theme =
    Theme.of(context);

    final total =
        _attendanceData.length;

    final hadir =
    _countStatus('Hadir');

    final izin =
    _countStatus('Izin');

    final sakit =
    _countStatus('Sakit');

    final alpha =
        _countStatus('Alpa') +
            _countStatus('Alpha');

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(22),
        gradient: LinearGradient(
          begin:
          Alignment.topLeft,
          end:
          Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.primary
                .withOpacity(0.78),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme
                .primary
                .withOpacity(0.20),
            blurRadius: 18,
            offset:
            const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                BoxDecoration(
                  color: Colors.white
                      .withOpacity(
                    0.16,
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    15,
                  ),
                ),
                child: const Icon(
                  Icons
                      .fact_check_rounded,
                  color:
                  Colors.white,
                  size: 26,
                ),
              ),

              const SizedBox(
                  width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      'Ringkasan Kehadiran',
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        color:
                        Colors.white,
                        fontWeight:
                        FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                        height: 3),

                    Text(
                      '$total catatan kehadiran',
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: Colors
                            .white
                            .withOpacity(
                          0.85,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
              height: 20),

          Row(
            children: [
              Expanded(
                child:
                _buildSummaryItem(
                  context,
                  'Hadir',
                  hadir,
                  Icons
                      .check_circle_rounded,
                ),
              ),
              Expanded(
                child:
                _buildSummaryItem(
                  context,
                  'Izin',
                  izin,
                  Icons
                      .event_note_rounded,
                ),
              ),
              Expanded(
                child:
                _buildSummaryItem(
                  context,
                  'Sakit',
                  sakit,
                  Icons
                      .medical_services_rounded,
                ),
              ),
              Expanded(
                child:
                _buildSummaryItem(
                  context,
                  'Alpa',
                  alpha,
                  Icons
                      .cancel_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SUMMARY ITEM
  // =========================================================

  Widget _buildSummaryItem(
      BuildContext context,
      String label,
      int value,
      IconData icon,
      ) {
    return Column(
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 21,
        ),

        const SizedBox(
            height: 6),

        Text(
          value.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight:
            FontWeight.w800,
          ),
        ),

        const SizedBox(
            height: 2),

        Text(
          label,
          style: TextStyle(
            color: Colors.white
                .withOpacity(0.80),
            fontSize: 11,
            fontWeight:
            FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // ATTENDANCE CARD
  // =========================================================

  Widget _buildAttendanceCard(
      BuildContext context,
      Map<String, String> attendance,
      ) {
    final theme =
    Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    final status =
        attendance['status'] ?? '-';

    final statusColor =
    _getStatusColor(
      context,
      status,
    );

    final statusIcon =
    _getStatusIcon(status);

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
      const EdgeInsets.all(16),
      decoration:
      BoxDecoration(
        color:
        colorScheme.surface,
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: colorScheme
              .outline
              .withOpacity(
            0.45,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          // =================================================
          // DATE + STATUS
          // =================================================

          Row(
            children: [
              Container(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration:
                BoxDecoration(
                  color: colorScheme
                      .primary
                      .withOpacity(
                    0.10,
                  ),
                  borderRadius:
                  BorderRadius
                      .circular(
                    10,
                  ),
                ),
                child: Text(
                  attendance[
                  'date'] ??
                      '',
                  style: TextStyle(
                    color: colorScheme
                        .primary,
                    fontSize: 12,
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),
              ),

              const Spacer(),

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
                      .withOpacity(
                    0.10,
                  ),
                  borderRadius:
                  BorderRadius
                      .circular(
                    10,
                  ),
                ),
                child: Row(
                  mainAxisSize:
                  MainAxisSize.min,
                  children: [
                    Icon(
                      statusIcon,
                      size: 15,
                      color:
                      statusColor,
                    ),
                    const SizedBox(
                        width: 5),
                    Text(
                      status,
                      style: TextStyle(
                        color:
                        statusColor,
                        fontSize: 12,
                        fontWeight:
                        FontWeight
                            .w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
              height: 14),

          // =================================================
          // SUBJECT
          // =================================================

          Row(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                BoxDecoration(
                  color: colorScheme
                      .primary
                      .withOpacity(
                    0.10,
                  ),
                  borderRadius:
                  BorderRadius
                      .circular(
                    14,
                  ),
                ),
                child: Icon(
                  Icons
                      .menu_book_rounded,
                  color:
                  colorScheme
                      .primary,
                  size: 23,
                ),
              ),

              const SizedBox(
                  width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      attendance[
                      'subject'] ??
                          '',
                      style: theme
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                        fontWeight:
                        FontWeight
                            .w800,
                      ),
                    ),

                    const SizedBox(
                        height: 5),

                    Text(
                      'Kehadiran siswa',
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
              height: 14),

          Divider(
            height: 1,
            color: colorScheme
                .outline
                .withOpacity(
              0.25,
            ),
          ),

          const SizedBox(
              height: 12),

          // =================================================
          // NOTE
          // =================================================

          Row(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
              Icon(
                Icons
                    .notes_rounded,
                size: 17,
                color: colorScheme
                    .onSurfaceVariant,
              ),

              const SizedBox(
                  width: 7),

              Expanded(
                child: Text(
                  'Catatan: ${attendance['note'] ?? '-'}',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // EMPTY STATE
  // =========================================================

  Widget _buildEmptyState(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(30),
      decoration:
      BoxDecoration(
        color:
        colorScheme.surface,
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: colorScheme
              .outline
              .withOpacity(
            0.35,
          ),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons
                .fact_check_outlined,
            size: 50,
            color:
            colorScheme.primary,
          ),

          const SizedBox(
              height: 12),

          Text(
            'Belum Ada Data Kehadiran',
            style: theme
                .textTheme
                .titleMedium
                ?.copyWith(
              fontWeight:
              FontWeight.w800,
            ),
          ),

          const SizedBox(
              height: 6),

          Text(
            'Belum ada riwayat kehadiran yang tercatat untuk akun kamu.',
            textAlign:
            TextAlign.center,
            style: theme
                .textTheme
                .bodySmall
                ?.copyWith(
              color: colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ERROR STATE
  // =========================================================

  Widget _buildErrorState(
      BuildContext context,
      String message,
      ) {
    final theme =
    Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration:
              BoxDecoration(
                color: colorScheme
                    .error
                    .withOpacity(
                  0.10,
                ),
                borderRadius:
                BorderRadius
                    .circular(
                  20,
                ),
              ),
              child: Icon(
                Icons
                    .error_outline_rounded,
                size: 36,
                color:
                colorScheme.error,
              ),
            ),

            const SizedBox(
                height: 16),

            Text(
              'Gagal Memuat Kehadiran',
              textAlign:
              TextAlign.center,
              style: theme
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                fontWeight:
                FontWeight.w800,
              ),
            ),

            const SizedBox(
                height: 8),

            Text(
              message,
              textAlign:
              TextAlign.center,
              style: theme
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                color: colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(
                height: 18),

            FilledButton.icon(
              onPressed:
              _loadAttendance,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label:
              const Text(
                'Coba Lagi',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // COUNT STATUS
  // =========================================================

  int _countStatus(
      String targetStatus,
      ) {
    return _attendanceData
        .where(
          (item) =>
      (item['status'] ?? '')
          .toLowerCase() ==
          targetStatus
              .toLowerCase(),
    )
        .length;
  }

  // =========================================================
  // STATUS COLOR
  // =========================================================

  Color _getStatusColor(
      BuildContext context,
      String status,
      ) {
    final colorScheme =
        Theme.of(context)
            .colorScheme;

    switch (status.toLowerCase()) {
      case 'hadir':
        return Colors.green;

      case 'izin':
        return Colors.orange;

      case 'sakit':
        return Colors.blue;

      case 'alpa':
      case 'alpha':
        return colorScheme.error;

      default:
        return colorScheme
            .onSurfaceVariant;
    }
  }

  // =========================================================
  // STATUS ICON
  // =========================================================

  IconData _getStatusIcon(
      String status,
      ) {
    switch (status.toLowerCase()) {
      case 'hadir':
        return Icons
            .check_circle_rounded;

      case 'izin':
        return Icons
            .event_note_rounded;

      case 'sakit':
        return Icons
            .medical_services_rounded;

      case 'alpa':
      case 'alpha':
        return Icons
            .cancel_rounded;

      default:
        return Icons
            .help_outline_rounded;
    }
  }
}