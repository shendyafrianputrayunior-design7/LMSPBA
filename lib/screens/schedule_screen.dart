import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // =========================================================
  // STATE
  // =========================================================

  bool _loading = true;
  String? _errorMessage;

  String _classId = '';
  String _className = '';

  List<Map<String, String>> _scheduleData = [];

  // =========================================================
  // INIT
  // =========================================================

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  // =========================================================
  // LOAD SCHEDULE
  // =========================================================

  Future<void> _loadSchedule() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          'Akun siswa tidak ditemukan.',
        );
      }

      // =====================================================
      // GET USER DATA
      // =====================================================

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData =
          userDoc.data() ?? <String, dynamic>{};

      final classId =
          userData['classId']?.toString() ?? '';

      if (classId.isEmpty) {
        throw Exception(
          'Data kelas siswa belum tersedia.',
        );
      }

      // =====================================================
      // GET CLASS DATA
      // =====================================================

      String className = classId;

      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .get();

      if (classDoc.exists) {
        final classData =
            classDoc.data() ?? <String, dynamic>{};

        className =
            classData['name']?.toString() ?? classId;
      }

      // =====================================================
      // GET SCHEDULE
      // =====================================================

      final scheduleSnapshot =
      await FirebaseFirestore.instance
          .collection('schedules')
          .where(
        'classId',
        isEqualTo: classId,
      )
          .get();

      // =====================================================
      // COLLECT TEACHER IDS
      // =====================================================

      final teacherIds = <String>{};

      for (final doc in scheduleSnapshot.docs) {
        final data =
        doc.data();

        final teacherId =
            data['teacherId']?.toString() ?? '';

        if (teacherId.isNotEmpty) {
          teacherIds.add(teacherId);
        }
      }

      // =====================================================
      // LOAD TEACHERS
      // =====================================================

      final teachers = <String, String>{};

      for (final teacherId in teacherIds) {
        final teacherDoc =
        await FirebaseFirestore.instance
            .collection('teachers')
            .doc(teacherId)
            .get();

        if (teacherDoc.exists) {
          final teacherData =
              teacherDoc.data() ??
                  <String, dynamic>{};

          teachers[teacherId] =
              teacherData['name']?.toString() ??
                  '-';
        }
      }

      // =====================================================
      // CONVERT FIRESTORE DATA
      // =====================================================

      final schedules =
      <Map<String, String>>[];

      for (final doc in scheduleSnapshot.docs) {
        final data =
        doc.data();

        final day =
            data['day']?.toString() ?? '';

        final subject =
            data['subject']?.toString() ?? '';

        final teacherId =
            data['teacherId']?.toString() ?? '';

        final startTime =
            data['startTime']?.toString() ?? '';

        final endTime =
            data['endTime']?.toString() ?? '';

        final room =
            data['room']?.toString() ?? '';

        // -----------------------------------------------------
        // DATE
        // -----------------------------------------------------

        final date =
            data['date']?.toString() ?? '';

        // -----------------------------------------------------
        // TYPE
        // -----------------------------------------------------

        final type =
            data['type']?.toString() ?? 'Pelajaran';

        // -----------------------------------------------------
        // TEACHER
        // -----------------------------------------------------

        final teacher =
            teachers[teacherId] ?? '-';

        schedules.add({
          'day': day,
          'date': date,
          'subject': subject,
          'teacher': teacher,
          'time':
          '$startTime - $endTime',
          'room': room,
          'type': type,
        });
      }

      // =====================================================
      // SORT SCHEDULE
      // =====================================================

      const dayOrder = {
        'Senin': 1,
        'Selasa': 2,
        'Rabu': 3,
        'Kamis': 4,
        'Jumat': 5,
        'Sabtu': 6,
        'Minggu': 7,
      };

      schedules.sort((a, b) {
        final dayA =
            dayOrder[a['day']] ?? 99;

        final dayB =
            dayOrder[b['day']] ?? 99;

        if (dayA != dayB) {
          return dayA.compareTo(dayB);
        }

        final timeA =
            a['time'] ?? '';

        final timeB =
            b['time'] ?? '';

        return timeA.compareTo(timeB);
      });

      // =====================================================
      // UPDATE STATE
      // =====================================================

      if (!mounted) return;

      setState(() {
        _classId = classId;
        _className = className;
        _scheduleData = schedules;
        _loading = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint(
        'Gagal mengambil jadwal: $e',
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
          'Schedule',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading
                ? null
                : _loadSchedule,
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
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState(
        context,
        _errorMessage!,
      );
    }

    return SingleChildScrollView(
      physics:
      const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
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
            'Jadwal Pelajaran',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(
              fontWeight:
              FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            _className.isNotEmpty
                ? 'Jadwal pelajaran kelas $_className.'
                : 'Lihat jadwal pelajaran dan kegiatan belajar kamu.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(
              color: colorScheme
                  .onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 20),

          // =================================================
          // TODAY CARD
          // =================================================

          _buildTodayCard(
            context,
            colorScheme,
          ),

          const SizedBox(height: 26),

          // =================================================
          // SCHEDULE TITLE
          // =================================================

          Text(
            'Jadwal Minggu Ini',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
              fontWeight:
              FontWeight.w800,
            ),
          ),

          const SizedBox(height: 14),

          // =================================================
          // EMPTY
          // =================================================

          if (_scheduleData.isEmpty)
            _buildEmptyState(
              context,
            ),

          // =================================================
          // SCHEDULE LIST
          // =================================================

          ..._scheduleData.map(
                (schedule) =>
                _buildScheduleCard(
                  context,
                  schedule,
                ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // TODAY CARD
  // =========================================================

  Widget _buildTodayCard(
      BuildContext context,
      ColorScheme colorScheme,
      ) {
    final theme =
    Theme.of(context);

    final today =
    _getTodayInIndonesian();

    final todaySchedules =
    _scheduleData
        .where(
          (schedule) =>
      schedule['day'] ==
          today,
    )
        .toList();

    return InkWell(
      borderRadius:
      BorderRadius.circular(22),
      onTap: todaySchedules.isEmpty
          ? null
          : () {
        _showTodaySchedule(
          context,
          todaySchedules,
        );
      },
      child: Container(
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
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration:
              BoxDecoration(
                color: Colors.white
                    .withOpacity(0.16),
                borderRadius:
                BorderRadius.circular(
                  16,
                ),
              ),
              child: const Icon(
                Icons
                    .calendar_month_rounded,
                color: Colors.white,
                size: 27,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jadwal Hari Ini',
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
                      height: 4),

                  Text(
                    todaySchedules.isEmpty
                        ? 'Tidak ada pelajaran hari ini'
                        : '${todaySchedules.length} mata pelajaran',
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

            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // TODAY SCHEDULE
  // =========================================================

  void _showTodaySchedule(
      BuildContext context,
      List<Map<String, String>>
      schedules,
      ) {
    final theme =
    Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor:
      theme.colorScheme.surface,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
            const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child: Column(
              mainAxisSize:
              MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'Jadwal Hari Ini',
                  style: theme
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),

                const SizedBox(
                    height: 16),

                ...schedules.map(
                      (schedule) =>
                      _buildTodayItem(
                        context,
                        schedule,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // TODAY ITEM
  // =========================================================

  Widget _buildTodayItem(
      BuildContext context,
      Map<String, String> schedule,
      ) {
    final theme =
    Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    return Container(
      margin:
      const EdgeInsets.only(
        bottom: 10,
      ),
      padding:
      const EdgeInsets.all(14),
      decoration:
      BoxDecoration(
        color:
        colorScheme.surface,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: colorScheme
              .outline
              .withOpacity(0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration:
            BoxDecoration(
              color: colorScheme
                  .primary
                  .withOpacity(
                0.10,
              ),
              borderRadius:
              BorderRadius.circular(
                13,
              ),
            ),
            child: Icon(
              Icons
                  .menu_book_rounded,
              color:
              colorScheme.primary,
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
                  schedule[
                  'subject'] ??
                      '-',
                  style: theme
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w800,
                  ),
                ),

                const SizedBox(
                    height: 4),

                Text(
                  schedule[
                  'teacher'] ??
                      '-',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: colorScheme
                        .onSurfaceVariant,
                  ),
                ),

                const SizedBox(
                    height: 5),

                Text(
                  '${schedule['time']} • ${schedule['room']}',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: colorScheme
                        .primary,
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SCHEDULE CARD
  // =========================================================

  Widget _buildScheduleCard(
      BuildContext context,
      Map<String, String> schedule,
      ) {
    final theme =
    Theme.of(context);
    final colorScheme =
        theme.colorScheme;

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
              .withOpacity(0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          // =================================================
          // DAY + DATE
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
                  schedule['day'] ??
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

              const SizedBox(
                  width: 10),

              Expanded(
                child: Text(
                  _displayDate(
                    schedule['date'] ??
                        '',
                  ),
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: colorScheme
                        .onSurfaceVariant,
                    fontWeight:
                    FontWeight.w600,
                  ),
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
                      schedule[
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
                        height: 4),

                    Text(
                      schedule[
                      'teacher'] ??
                          '',
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
                .withOpacity(0.25),
          ),

          const SizedBox(
              height: 12),

          // =================================================
          // TIME + ROOM
          // =================================================

          Row(
            children: [
              Icon(
                Icons
                    .access_time_rounded,
                size: 17,
                color: colorScheme
                    .onSurfaceVariant,
              ),

              const SizedBox(
                  width: 6),

              Text(
                schedule['time'] ??
                    '',
                style: theme
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),

              const SizedBox(
                  width: 18),

              Icon(
                Icons
                    .location_on_outlined,
                size: 17,
                color: colorScheme
                    .onSurfaceVariant,
              ),

              const SizedBox(
                  width: 5),

              Expanded(
                child: Text(
                  schedule['room'] ??
                      '',
                  maxLines: 1,
                  overflow:
                  TextOverflow.ellipsis,
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

          // =================================================
          // TYPE
          // =================================================

          if ((schedule['type'] ??
              '')
              .isNotEmpty) ...[
            const SizedBox(
                height: 12),
            Align(
              alignment:
              Alignment.centerLeft,
              child: Container(
                padding:
                const EdgeInsets
                    .symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration:
                BoxDecoration(
                  color: colorScheme
                      .secondary
                      .withOpacity(
                    0.10,
                  ),
                  borderRadius:
                  BorderRadius
                      .circular(
                    8,
                  ),
                ),
                child: Text(
                  schedule['type'] ??
                      '',
                  style: TextStyle(
                    color: colorScheme
                        .secondary,
                    fontSize: 11,
                    fontWeight:
                    FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
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
              .withOpacity(0.35),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons
                .calendar_month_outlined,
            size: 50,
            color:
            colorScheme.primary,
          ),

          const SizedBox(
              height: 12),

          Text(
            'Belum Ada Jadwal',
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
            'Belum ada jadwal pelajaran untuk kelas $_className.',
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
              'Gagal Memuat Jadwal',
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
              _loadSchedule,
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
  // DAY NAME
  // =========================================================

  String _getTodayInIndonesian() {
    final weekday =
        DateTime.now().weekday;

    switch (weekday) {
      case DateTime.monday:
        return 'Senin';

      case DateTime.tuesday:
        return 'Selasa';

      case DateTime.wednesday:
        return 'Rabu';

      case DateTime.thursday:
        return 'Kamis';

      case DateTime.friday:
        return 'Jumat';

      case DateTime.saturday:
        return 'Sabtu';

      case DateTime.sunday:
        return 'Minggu';

      default:
        return '';
    }
  }

  // =========================================================
  // DISPLAY DATE
  // =========================================================

  String _displayDate(String date) {
    if (date.trim().isEmpty) {
      return '';
    }

    return date;
  }
}