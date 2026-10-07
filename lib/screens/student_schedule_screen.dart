import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class StudentScheduleScreen extends StatefulWidget {
  final String classId;

  const StudentScheduleScreen({
    super.key,
    required this.classId,
  });

  @override
  State<StudentScheduleScreen> createState() =>
      _StudentScheduleScreenState();
}

class _StudentScheduleScreenState extends State<StudentScheduleScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _loading = true;
  List<Map<String, dynamic>> _schedules = [];

  final List<String> _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    try {
      final snapshot = await _firestore
          .collection('schedules')
          .where('classId', isEqualTo: widget.classId)
          .get();

      final schedules = snapshot.docs.map((doc) {
        final data = doc.data();

        return {
          'id': doc.id,
          ...data,
        };
      }).toList();

      schedules.sort((a, b) {
        final dayA = _days.indexOf(
          (a['day'] ?? '').toString(),
        );

        final dayB = _days.indexOf(
          (b['day'] ?? '').toString(),
        );

        final safeDayA = dayA == -1 ? 99 : dayA;
        final safeDayB = dayB == -1 ? 99 : dayB;

        if (safeDayA != safeDayB) {
          return safeDayA.compareTo(safeDayB);
        }

        return _timeToMinutes(
          (a['startTime'] ?? '').toString(),
        ).compareTo(
          _timeToMinutes(
            (b['startTime'] ?? '').toString(),
          ),
        );
      });

      if (!mounted) return;

      setState(() {
        _schedules = schedules;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memuat jadwal: $e',
          ),
        ),
      );
    }
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');

    if (parts.length < 2) {
      return 9999;
    }

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    return (hour * 60) + minute;
  }

  List<Map<String, dynamic>> _getSchedulesByDay(String day) {
    return _schedules.where((schedule) {
      return (schedule['day'] ?? '').toString() == day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jadwal Pelajaran'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh: _loadSchedules,
        child: _schedules.isEmpty
            ? ListView(
          children: const [
            SizedBox(height: 180),
            Center(
              child: Text(
                'Belum ada jadwal pelajaran.',
              ),
            ),
          ],
        )
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            ..._buildScheduleSections(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: 0.08),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
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
                  'Jadwal Pelajaran',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Jadwal kelas ${widget.classId}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildScheduleSections() {
    final widgets = <Widget>[];

    for (final day in _days) {
      final schedules = _getSchedulesByDay(day);

      if (schedules.isEmpty) {
        continue;
      }

      widgets.add(
        Padding(
          padding: const EdgeInsets.only(
            bottom: 10,
            top: 6,
          ),
          child: Text(
            day,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );

      for (final schedule in schedules) {
        widgets.add(
          _buildScheduleCard(schedule),
        );

        widgets.add(
          const SizedBox(height: 12),
        );
      }

      widgets.add(
        const SizedBox(height: 8),
      );
    }

    return widgets;
  }

  Widget _buildScheduleCard(
      Map<String, dynamic> schedule,
      ) {
    final subject =
    (schedule['subject'] ?? 'Mata Pelajaran').toString();

    final teacher =
    (schedule['teacherName'] ?? 'Guru').toString();

    final startTime =
    (schedule['startTime'] ?? '-').toString();

    final endTime =
    (schedule['endTime'] ?? '-').toString();

    final room =
    (schedule['room'] ?? '-').toString();

    final className =
    (schedule['className'] ?? widget.classId).toString();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        _showScheduleDetail(schedule);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context).cardColor,
          border: Border.all(
            color: Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              padding: const EdgeInsets.symmetric(
                vertical: 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.10),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.access_time_rounded,
                    size: 22,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    startTime,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    subject,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline_rounded,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          teacher,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        room,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleDetail(
      Map<String, dynamic> schedule,
      ) {
    final subject =
    (schedule['subject'] ?? 'Mata Pelajaran').toString();

    final teacher =
    (schedule['teacherName'] ?? 'Guru').toString();

    final day =
    (schedule['day'] ?? '-').toString();

    final startTime =
    (schedule['startTime'] ?? '-').toString();

    final endTime =
    (schedule['endTime'] ?? '-').toString();

    final room =
    (schedule['room'] ?? '-').toString();

    final className =
    (schedule['className'] ?? widget.classId).toString();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            30,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                subject,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _detailRow(
                Icons.calendar_today_rounded,
                'Hari',
                day,
              ),
              _detailRow(
                Icons.access_time_rounded,
                'Jam',
                '$startTime - $endTime',
              ),
              _detailRow(
                Icons.person_rounded,
                'Guru',
                teacher,
              ),
              _detailRow(
                Icons.class_rounded,
                'Kelas',
                className,
              ),
              _detailRow(
                Icons.location_on_rounded,
                'Ruangan',
                room,
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(
      IconData icon,
      String title,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 22,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
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
}