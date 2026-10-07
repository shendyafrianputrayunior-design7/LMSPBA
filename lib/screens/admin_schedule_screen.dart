import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({super.key});

  @override
  State<AdminScheduleScreen> createState() =>
      _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  final FirestoreService _firestore = FirestoreService.instance;

  // ============================================================
  // TAMBAH / EDIT JADWAL
  // ============================================================

  Future<void> _showScheduleDialog({
    DocumentSnapshot<Map<String, dynamic>>? document,
  }) async {
    final result = await showDialog<_ScheduleFormResult>(
      context: context,
      builder: (_) {
        return _ScheduleFormDialog(
          document: document,
          firestore: _firestore,
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    try {
      if (result.isEdit) {
        await _firestore.updateSchedule(
          id: result.id!,
          classId: result.classId,
          subject: result.subject,
          teacherId: result.teacherId,
          day: result.day,
          startTime: result.startTime,
          endTime: result.endTime,
          room: result.room,
        );
      } else {
        await _firestore.addSchedule(
          classId: result.classId,
          subject: result.subject,
          teacherId: result.teacherId,
          day: result.day,
          startTime: result.startTime,
          endTime: result.endTime,
          room: result.room,
        );
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isEdit
                ? 'Jadwal berhasil diperbarui'
                : 'Jadwal berhasil ditambahkan',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isEdit
                ? 'Gagal memperbarui jadwal: $e'
                : 'Gagal menambahkan jadwal: $e',
          ),
        ),
      );
    }
  }

  // ============================================================
  // HAPUS JADWAL
  // ============================================================

  Future<void> _deleteSchedule(
      String id,
      String subject,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Hapus Jadwal',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'Apakah kamu yakin ingin menghapus jadwal '
                '"$subject"?',
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

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await _firestore.deleteSchedule(id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Jadwal berhasil dihapus',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: const Text(
          'Kelola Jadwal',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      // ==========================================================
      // TAMBAH
      // ==========================================================

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showScheduleDialog();
        },
        icon: const Icon(
          Icons.add_rounded,
        ),
        label: const Text(
          'Tambah Jadwal',
        ),
      ),

      // ==========================================================
      // DATA JADWAL
      // ==========================================================

      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.getSchedules(),
        builder: (
            context,
            snapshot,
            ) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Gagal memuat data jadwal.\n\n'
                      '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final documents = snapshot.data?.docs ?? [];

          if (documents.isEmpty) {
            return _buildEmptyState(
              context,
              colorScheme,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              20,
              20,
              20,
              100,
            ),
            itemCount: documents.length,
            separatorBuilder: (_, __) {
              return const SizedBox(
                height: 12,
              );
            },
            itemBuilder: (
                context,
                index,
                ) {
              final document = documents[index];

              final data = document.data();

              return _buildScheduleCard(
                context: context,
                document: document,
                data: data,
                colorScheme: colorScheme,
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // SCHEDULE CARD
  // ============================================================

  Widget _buildScheduleCard({
    required BuildContext context,
    required DocumentSnapshot<Map<String, dynamic>> document,
    required Map<String, dynamic> data,
    required ColorScheme colorScheme,
  }) {
    final theme = Theme.of(context);

    final subject =
        data['subject']?.toString() ?? '-';

    final day =
        data['day']?.toString() ?? '-';

    final startTime =
        data['startTime']?.toString() ?? '-';

    final endTime =
        data['endTime']?.toString() ?? '-';

    final room =
        data['room']?.toString() ?? '-';

    final classId =
        data['classId']?.toString() ?? '';

    final teacherId =
        data['teacherId']?.toString() ?? '';

    return FutureBuilder<List<String>>(
      future: _getRelatedNames(
        classId,
        teacherId,
      ),
      builder: (
          context,
          snapshot,
          ) {
        final names = snapshot.data ?? const [];

        final className = names.isNotEmpty
            ? names[0]
            : 'Memuat kelas...';

        final teacherName = names.length > 1
            ? names[1]
            : 'Memuat guru...';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorScheme.outline.withOpacity(0.35),
            ),
          ),
          child: Column(
            children: [
              // ==================================================
              // HEADER
              // ==================================================

              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.calendar_month_rounded,
                      color: colorScheme.primary,
                      size: 28,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          '$day • $startTime - $endTime',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // MENU
                  // ==================================================

                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showScheduleDialog(
                          document: document,
                        );
                      }

                      if (value == 'delete') {
                        _deleteSchedule(
                          document.id,
                          subject,
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
                              SizedBox(
                                width: 10,
                              ),
                              Text(
                                'Edit',
                              ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                              ),
                              SizedBox(
                                width: 10,
                              ),
                              Text(
                                'Hapus',
                              ),
                            ],
                          ),
                        ),
                      ];
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Divider(
                height: 1,
                color: colorScheme.outline.withOpacity(0.20),
              ),

              const SizedBox(height: 14),

              // ==================================================
              // KELAS
              // ==================================================

              _buildInfoRow(
                context,
                Icons.class_outlined,
                className,
              ),

              const SizedBox(height: 9),

              // ==================================================
              // GURU
              // ==================================================

              _buildInfoRow(
                context,
                Icons.person_outline_rounded,
                teacherName,
              ),

              const SizedBox(height: 9),

              // ==================================================
              // RUANG
              // ==================================================

              _buildInfoRow(
                context,
                Icons.meeting_room_outlined,
                room,
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // AMBIL NAMA KELAS + GURU
  // ============================================================

  Future<List<String>> _getRelatedNames(
      String classId,
      String teacherId,
      ) async {
    String className = '-';
    String teacherName = '-';

    if (classId.isNotEmpty) {
      final classDoc = await _firestore.classes
          .doc(classId)
          .get();

      if (classDoc.exists) {
        className =
            classDoc.data()?['name']?.toString() ?? '-';
      }
    }

    if (teacherId.isNotEmpty) {
      final teacherDoc = await _firestore.teachers
          .doc(teacherId)
          .get();

      if (teacherDoc.exists) {
        teacherName =
            teacherDoc.data()?['name']?.toString() ?? '-';
      }
    }

    return [
      className,
      teacherName,
    ];
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _buildInfoRow(
      BuildContext context,
      IconData icon,
      String text,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState(
      BuildContext context,
      ColorScheme colorScheme,
      ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),

            const SizedBox(height: 16),

            const Text(
              'Belum ada jadwal',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Tambahkan jadwal pelajaran '
                  'menggunakan tombol di bawah.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================================================================
// HASIL FORM JADWAL
// ==================================================================

class _ScheduleFormResult {
  final String? id;

  final String classId;
  final String teacherId;
  final String subject;
  final String day;
  final String startTime;
  final String endTime;
  final String room;

  const _ScheduleFormResult({
    this.id,
    required this.classId,
    required this.teacherId,
    required this.subject,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.room,
  });

  bool get isEdit => id != null;
}

// ==================================================================
// DIALOG FORM JADWAL
// ==================================================================

class _ScheduleFormDialog extends StatefulWidget {
  final DocumentSnapshot<Map<String, dynamic>>? document;
  final FirestoreService firestore;

  const _ScheduleFormDialog({
    required this.firestore,
    this.document,
  });

  @override
  State<_ScheduleFormDialog> createState() =>
      _ScheduleFormDialogState();
}

class _ScheduleFormDialogState
    extends State<_ScheduleFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _subjectController;
  late final TextEditingController _startTimeController;
  late final TextEditingController _endTimeController;
  late final TextEditingController _roomController;

  late String? _selectedClassId;
  late String? _selectedTeacherId;
  late String _selectedDay;

  static const List<String> _days = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
  ];

  bool get _isEdit => widget.document != null;

  @override
  void initState() {
    super.initState();

    final data = widget.document?.data();

    _selectedClassId =
        data?['classId']?.toString();

    _selectedTeacherId =
        data?['teacherId']?.toString();

    final savedDay =
    data?['day']?.toString().trim();

    _selectedDay = _days.firstWhere(
          (day) =>
      day.toLowerCase() ==
          savedDay?.toLowerCase(),
      orElse: () => 'Senin',
    );

    _subjectController = TextEditingController(
      text: data?['subject']?.toString() ?? '',
    );

    _startTimeController = TextEditingController(
      text: data?['startTime']?.toString() ?? '',
    );

    _endTimeController = TextEditingController(
      text: data?['endTime']?.toString() ?? '',
    );

    _roomController = TextEditingController(
      text: data?['room']?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _roomController.dispose();

    super.dispose();
  }

  // ============================================================
  // PILIH JAM MULAI
  // ============================================================

  Future<void> _selectStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _parseTime(
        _startTimeController.text,
      ) ??
          TimeOfDay.now(),
    );

    if (!mounted || time == null) {
      return;
    }

    setState(() {
      _startTimeController.text =
          time.format(context);
    });
  }

  // ============================================================
  // PILIH JAM SELESAI
  // ============================================================

  Future<void> _selectEndTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _parseTime(
        _endTimeController.text,
      ) ??
          TimeOfDay.now(),
    );

    if (!mounted || time == null) {
      return;
    }

    setState(() {
      _endTimeController.text =
          time.format(context);
    });
  }

  // ============================================================
  // PARSE JAM
  // ============================================================

  TimeOfDay? _parseTime(String value) {
    if (value.trim().isEmpty) {
      return null;
    }

    try {
      final parts = value.trim().split(' ');

      if (parts.isEmpty) {
        return null;
      }

      final timePart = parts[0];
      final timeParts = timePart.split(':');

      if (timeParts.length != 2) {
        return null;
      }

      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      if (parts.length > 1) {
        final period = parts[1].toUpperCase();

        if (period == 'PM' && hour < 12) {
          hour += 12;
        }

        if (period == 'AM' && hour == 12) {
          hour = 0;
        }
      }

      if (hour < 0 ||
          hour > 23 ||
          minute < 0 ||
          minute > 59) {
        return null;
      }

      return TimeOfDay(
        hour: hour,
        minute: minute,
      );
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedClassId == null ||
        _selectedClassId!.isEmpty) {
      return;
    }

    if (_selectedTeacherId == null ||
        _selectedTeacherId!.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      _ScheduleFormResult(
        id: widget.document?.id,
        classId: _selectedClassId!,
        teacherId: _selectedTeacherId!,
        subject: _subjectController.text.trim(),
        day: _selectedDay,
        startTime: _startTimeController.text.trim(),
        endTime: _endTimeController.text.trim(),
        room: _roomController.text.trim(),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEdit
            ? 'Edit Jadwal'
            : 'Tambah Jadwal',
        style: const TextStyle(
          fontWeight: FontWeight.w800,
        ),
      ),

      content: SizedBox(
        width: 500,
        child: StreamBuilder<
            QuerySnapshot<Map<String, dynamic>>>(
          stream: widget.firestore.classes.snapshots(),
          builder: (
              context,
              classSnapshot,
              ) {
            if (classSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (classSnapshot.hasError) {
              return Text(
                'Gagal memuat data kelas:\n'
                    '${classSnapshot.error}',
              );
            }

            final classes =
                classSnapshot.data?.docs ?? [];

            return StreamBuilder<
                QuerySnapshot<Map<String, dynamic>>>(
              stream:
              widget.firestore.teachers.snapshots(),
              builder: (
                  context,
                  teacherSnapshot,
                  ) {
                if (teacherSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const SizedBox(
                    height: 100,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                if (teacherSnapshot.hasError) {
                  return Text(
                    'Gagal memuat data guru:\n'
                        '${teacherSnapshot.error}',
                  );
                }

                final teachers =
                    teacherSnapshot.data?.docs ?? [];

                return Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ==================================================
                        // KELAS
                        // ==================================================

                        DropdownButtonFormField<String>(
                          initialValue: classes.any(
                                (doc) =>
                            doc.id ==
                                _selectedClassId,
                          )
                              ? _selectedClassId
                              : null,
                          decoration:
                          const InputDecoration(
                            labelText: 'Kelas',
                            prefixIcon: Icon(
                              Icons.class_outlined,
                            ),
                          ),
                          items: classes.map(
                                (doc) {
                              final data =
                              doc.data();

                              return DropdownMenuItem<
                                  String>(
                                value: doc.id,
                                child: Text(
                                  data['name']
                                      ?.toString() ??
                                      '-',
                                ),
                              );
                            },
                          ).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedClassId = value;
                            });
                          },
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty) {
                              return 'Pilih kelas';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        // ==================================================
                        // GURU
                        // ==================================================

                        DropdownButtonFormField<String>(
                          initialValue: teachers.any(
                                (doc) =>
                            doc.id ==
                                _selectedTeacherId,
                          )
                              ? _selectedTeacherId
                              : null,
                          decoration:
                          const InputDecoration(
                            labelText: 'Guru',
                            prefixIcon: Icon(
                              Icons.person_outline_rounded,
                            ),
                          ),
                          items: teachers.map(
                                (doc) {
                              final data =
                              doc.data();

                              return DropdownMenuItem<
                                  String>(
                                value: doc.id,
                                child: Text(
                                  data['name']
                                      ?.toString() ??
                                      '-',
                                ),
                              );
                            },
                          ).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedTeacherId =
                                  value;
                            });
                          },
                          validator: (value) {
                            if (value == null ||
                                value.isEmpty) {
                              return 'Pilih guru';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        // ==================================================
                        // MATA PELAJARAN
                        // ==================================================

                        TextFormField(
                          controller:
                          _subjectController,
                          textInputAction:
                          TextInputAction.next,
                          decoration:
                          const InputDecoration(
                            labelText:
                            'Mata Pelajaran',
                            hintText:
                            'Contoh: Pemrograman Mobile',
                            prefixIcon: Icon(
                              Icons.menu_book_outlined,
                            ),
                          ),
                          validator: (value) {
                            if (value == null ||
                                value.trim().isEmpty) {
                              return 'Mata pelajaran wajib diisi';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        // ==================================================
                        // HARI
                        // ==================================================

                        DropdownButtonFormField<String>(
                          initialValue: _selectedDay,
                          decoration:
                          const InputDecoration(
                            labelText: 'Hari',
                            prefixIcon: Icon(
                              Icons.calendar_today_outlined,
                            ),
                          ),
                          items: _days.map(
                                (day) {
                              return DropdownMenuItem<
                                  String>(
                                value: day,
                                child: Text(day),
                              );
                            },
                          ).toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              _selectedDay = value;
                            });
                          },
                        ),

                        const SizedBox(height: 14),

                        // ==================================================
                        // JAM
                        // ==================================================

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller:
                                _startTimeController,
                                readOnly: true,
                                onTap:
                                _selectStartTime,
                                decoration:
                                const InputDecoration(
                                  labelText: 'Mulai',
                                  prefixIcon: Icon(
                                    Icons
                                        .access_time_outlined,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().isEmpty) {
                                    return 'Pilih jam';
                                  }

                                  return null;
                                },
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: TextFormField(
                                controller:
                                _endTimeController,
                                readOnly: true,
                                onTap:
                                _selectEndTime,
                                decoration:
                                const InputDecoration(
                                  labelText:
                                  'Selesai',
                                  prefixIcon: Icon(
                                    Icons
                                        .access_time_filled_outlined,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().isEmpty) {
                                    return 'Pilih jam';
                                  }

                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ==================================================
                        // RUANGAN
                        // ==================================================

                        TextFormField(
                          controller:
                          _roomController,
                          textInputAction:
                          TextInputAction.done,
                          decoration:
                          const InputDecoration(
                            labelText: 'Ruangan',
                            hintText:
                            'Contoh: Lab Komputer 1',
                            prefixIcon: Icon(
                              Icons
                                  .meeting_room_outlined,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),

      // ============================================================
      // ACTIONS
      // ============================================================

      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Batal'),
        ),

        FilledButton(
          onPressed: _submit,
          child: Text(
            _isEdit
                ? 'Simpan Perubahan'
                : 'Simpan',
          ),
        ),
      ],
    );
  }
}