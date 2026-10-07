import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TeacherAttendanceScreen extends StatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  State<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState
    extends State<TeacherAttendanceScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  String _teacherName = '';
  String? _teacherId;

  bool _loading = true;

  List<Map<String, dynamic>> _courses = [];
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // =========================================================
  // GET TEACHER DOCUMENT ID
  // =========================================================

  Future<String?> _getTeacherDocumentId() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    // =======================================================
    // 1. CEK users/{uid}.teacherId
    // =======================================================

    final userDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    final userData =
        userDoc.data() ?? <String, dynamic>{};

    final teacherId =
    userData['teacherId']?.toString().trim();

    if (teacherId != null && teacherId.isNotEmpty) {
      final teacherDoc = await _firestore
          .collection('teachers')
          .doc(teacherId)
          .get();

      if (teacherDoc.exists) {
        return teacherId;
      }
    }

    // =======================================================
    // 2. FALLBACK BERDASARKAN EMAIL
    // =======================================================

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

    return null;
  }

  // =========================================================
  // LOAD DATA
  // =========================================================

  Future<void> _loadData() async {
    final user = _auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      return;
    }

    try {
      // =====================================================
      // RESOLVE TEACHER ID
      // =====================================================

      final teacherId =
      await _getTeacherDocumentId();

      if (teacherId == null ||
          teacherId.isEmpty) {
        if (!mounted) return;

        setState(() {
          _teacherId = null;
          _teacherName = '';
          _courses = [];
          _sessions = [];
          _loading = false;
        });

        _showMessage(
          'Data guru tidak ditemukan.',
        );

        return;
      }

      // =====================================================
      // USER PROFILE
      // =====================================================

      final userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final userData =
          userDoc.data() ??
              <String, dynamic>{};

      final teacherName =
      (userData['name'] ??
          userData['username'] ??
          user.displayName ??
          'Guru')
          .toString();

      // =====================================================
      // ID YANG BOLEH DIGUNAKAN UNTUK DATA LAMA
      //
      // teacherId utama = document ID teachers
      // fallback lama = Firebase Auth UID
      // =====================================================

      final teacherIds = <String>{
        teacherId,
        user.uid,
      }.where((id) => id.isNotEmpty).toList();

      // =====================================================
      // LOAD COURSES
      //
      // Data course lama bisa menggunakan:
      // - Auth UID
      // - teacher document ID
      // =====================================================

      QuerySnapshot<Map<String, dynamic>> courseSnapshot;

      if (teacherIds.length == 1) {
        courseSnapshot = await _firestore
            .collection('courses')
            .where(
          'teacherId',
          isEqualTo: teacherIds.first,
        )
            .get();
      } else {
        courseSnapshot = await _firestore
            .collection('courses')
            .where(
          'teacherId',
          whereIn: teacherIds,
        )
            .get();
      }

      final courseMap =
      <String, Map<String, dynamic>>{};

      for (final doc in courseSnapshot.docs) {
        final data = doc.data();

        courseMap[doc.id] = {
          'id': doc.id,
          'title':
          (data['title'] ?? 'Course').toString(),
          'classId':
          (data['classId'] ?? '').toString(),
          'className':
          (data['className'] ??
              data['classId'] ??
              '')
              .toString(),
        };
      }

      final courses =
      courseMap.values.toList();

      // =====================================================
      // LOAD ATTENDANCE SESSIONS
      //
      // PENTING:
      // Ambil data menggunakan teacher document ID DAN UID
      // agar data lama tetap muncul.
      // =====================================================

      QuerySnapshot<Map<String, dynamic>>
      sessionSnapshot;

      if (teacherIds.length == 1) {
        sessionSnapshot = await _firestore
            .collection('attendance_sessions')
            .where(
          'teacherId',
          isEqualTo: teacherIds.first,
        )
            .get();
      } else {
        sessionSnapshot = await _firestore
            .collection('attendance_sessions')
            .where(
          'teacherId',
          whereIn: teacherIds,
        )
            .get();
      }

      final sessionMap =
      <String, Map<String, dynamic>>{};

      for (final doc in sessionSnapshot.docs) {
        final data = doc.data();

        sessionMap[doc.id] = {
          'id': doc.id,
          ...data,
        };
      }

      final sessions =
      sessionMap.values.toList();

      // =====================================================
      // SORT SESSION TERBARU
      // =====================================================

      sessions.sort((a, b) {
        final aDate =
        _parseDate(a['date']);

        final bDate =
        _parseDate(b['date']);

        return bDate.compareTo(aDate);
      });

      if (!mounted) return;

      setState(() {
        _teacherId = teacherId;
        _teacherName = teacherName;
        _courses = courses;
        _sessions = sessions;
        _loading = false;
      });

      debugPrint(
        '==========================================',
      );
      debugPrint(
        'TEACHER ATTENDANCE',
      );
      debugPrint(
        'Auth UID       : ${user.uid}',
      );
      debugPrint(
        'Teacher Doc ID : $teacherId',
      );
      debugPrint(
        'Jumlah Course  : ${courses.length}',
      );
      debugPrint(
        'Jumlah Session : ${sessions.length}',
      );
      debugPrint(
        '==========================================',
      );
    } catch (e) {
      debugPrint(
        'Gagal memuat attendance guru: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        'Gagal memuat data absensi.',
      );
    }
  }

  // =========================================================
  // PARSE DATE
  // =========================================================

  DateTime _parseDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value != null) {
      final parsed =
      DateTime.tryParse(
        value.toString(),
      );

      if (parsed != null) {
        return parsed;
      }

      // Format dd/MM/yyyy
      final parts =
      value.toString().split('/');

      if (parts.length == 3) {
        final day =
        int.tryParse(parts[0]);

        final month =
        int.tryParse(parts[1]);

        final year =
        int.tryParse(parts[2]);

        if (day != null &&
            month != null &&
            year != null) {
          return DateTime(
            year,
            month,
            day,
          );
        }
      }
    }

    return DateTime(2000);
  }

  // =========================================================
  // CREATE SESSION
  // =========================================================

  Future<void> _createSession() async {
    if (_courses.isEmpty) {
      _showMessage(
        'Belum ada course yang diajarkan guru ini.',
      );
      return;
    }

    final teacherId =
        _teacherId ??
            await _getTeacherDocumentId();

    if (teacherId == null ||
        teacherId.isEmpty) {
      _showMessage(
        'Data guru tidak ditemukan.',
      );
      return;
    }

    String? selectedCourseId =
    _courses.first['id']?.toString();

    final dateController =
    TextEditingController(
      text: _formatDate(
        DateTime.now(),
      ),
    );

    final startTimeController =
    TextEditingController(
      text: '07:00',
    );

    final endTimeController =
    TextEditingController(
      text: '08:00',
    );

    final formKey =
    GlobalKey<FormState>();

    final result =
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (
              context,
              setDialogState,
              ) {
            return AlertDialog(
              title: const Text(
                'Buat Sesi Absensi',
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,
                    children: [
                      // =================================================
                      // COURSE
                      // =================================================

                      DropdownButtonFormField<
                          String>(
                        value:
                        selectedCourseId,
                        decoration:
                        const InputDecoration(
                          labelText:
                          'Course',
                          border:
                          OutlineInputBorder(),
                        ),
                        items:
                        _courses.map(
                              (course) {
                            return DropdownMenuItem<
                                String>(
                              value: course[
                              'id']
                                  .toString(),
                              child: Text(
                                course[
                                'title']
                                    .toString(),
                                overflow:
                                TextOverflow
                                    .ellipsis,
                              ),
                            );
                          },
                        ).toList(),
                        onChanged:
                            (value) {
                          setDialogState(() {
                            selectedCourseId =
                                value;
                          });
                        },
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      // =================================================
                      // DATE
                      // =================================================

                      TextFormField(
                        controller:
                        dateController,
                        readOnly: true,
                        decoration:
                        const InputDecoration(
                          labelText:
                          'Tanggal',
                          border:
                          OutlineInputBorder(),
                          suffixIcon:
                          Icon(
                            Icons
                                .calendar_month_rounded,
                          ),
                        ),
                        onTap: () async {
                          final selected =
                          await showDatePicker(
                            context:
                            context,
                            firstDate:
                            DateTime(
                              2020,
                            ),
                            lastDate:
                            DateTime(
                              2100,
                            ),
                            initialDate:
                            DateTime
                                .now(),
                          );

                          if (selected !=
                              null) {
                            dateController
                                .text =
                                _formatDate(
                                  selected,
                                );
                          }
                        },
                        validator:
                            (value) {
                          if (value ==
                              null ||
                              value
                                  .isEmpty) {
                            return 'Tanggal wajib diisi';
                          }

                          return null;
                        },
                      ),

                      const SizedBox(
                        height: 14,
                      ),

                      // =================================================
                      // TIME
                      // =================================================

                      Row(
                        children: [
                          Expanded(
                            child:
                            TextFormField(
                              controller:
                              startTimeController,
                              readOnly:
                              true,
                              decoration:
                              const InputDecoration(
                                labelText:
                                'Mulai',
                                border:
                                OutlineInputBorder(),
                                suffixIcon:
                                Icon(
                                  Icons
                                      .access_time_rounded,
                                ),
                              ),
                              onTap:
                                  () async {
                                final time =
                                await showTimePicker(
                                  context:
                                  context,
                                  initialTime:
                                  const TimeOfDay(
                                    hour:
                                    7,
                                    minute:
                                    0,
                                  ),
                                );

                                if (time !=
                                    null) {
                                  startTimeController
                                      .text =
                                      _formatTime(
                                        time,
                                      );
                                }
                              },
                            ),
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Expanded(
                            child:
                            TextFormField(
                              controller:
                              endTimeController,
                              readOnly:
                              true,
                              decoration:
                              const InputDecoration(
                                labelText:
                                'Selesai',
                                border:
                                OutlineInputBorder(),
                                suffixIcon:
                                Icon(
                                  Icons
                                      .access_time_rounded,
                                ),
                              ),
                              onTap:
                                  () async {
                                final time =
                                await showTimePicker(
                                  context:
                                  context,
                                  initialTime:
                                  const TimeOfDay(
                                    hour:
                                    8,
                                    minute:
                                    0,
                                  ),
                                );

                                if (time !=
                                    null) {
                                  endTimeController
                                      .text =
                                      _formatTime(
                                        time,
                                      );
                                }
                              },
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
                  onPressed: () {
                    Navigator.pop(
                      context,
                      false,
                    );
                  },
                  child:
                  const Text(
                    'Batal',
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    if (!formKey
                        .currentState!
                        .validate()) {
                      return;
                    }

                    Navigator.pop(
                      context,
                      true,
                    );
                  },
                  child:
                  const Text(
                    'Buat',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true ||
        selectedCourseId == null) {
      dateController.dispose();
      startTimeController.dispose();
      endTimeController.dispose();
      return;
    }

    final selectedCourse =
    _courses.firstWhere(
          (course) =>
      course['id'].toString() ==
          selectedCourseId,
    );

    final user =
        _auth.currentUser;

    if (user == null) {
      dateController.dispose();
      startTimeController.dispose();
      endTimeController.dispose();
      return;
    }

    try {
      // =====================================================
      // CREATE SESSION
      //
      // teacherId menggunakan document ID teachers
      // =====================================================

      await _firestore
          .collection(
        'attendance_sessions',
      )
          .add({
        'teacherId': teacherId,
        'teacherName': _teacherName,

        'classId':
        selectedCourse['classId']
            .toString(),

        'className':
        selectedCourse['className']
            .toString(),

        'courseId':
        selectedCourse['id']
            .toString(),

        'courseName':
        selectedCourse['title']
            .toString(),

        'date':
        dateController.text,

        'startTime':
        startTimeController.text,

        'endTime':
        endTimeController.text,

        'status': 'open',

        'createdAt':
        FieldValue.serverTimestamp(),

        'updatedAt':
        FieldValue.serverTimestamp(),
      });

      _showMessage(
        'Sesi absensi berhasil dibuat.',
      );

      await _loadData();
    } catch (e) {
      debugPrint(
        'Gagal membuat sesi absensi: $e',
      );

      _showMessage(
        'Gagal membuat sesi absensi.',
      );
    } finally {
      dateController.dispose();
      startTimeController.dispose();
      endTimeController.dispose();
    }
  }

  // =========================================================
  // OPEN SESSION
  // =========================================================

  void _openSession(
      Map<String, dynamic> session,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _TeacherAttendanceSessionPage(
              session: session,
            ),
      ),
    ).then((_) {
      _loadData();
    });
  }

  // =========================================================
  // DELETE SESSION
  // =========================================================

  Future<void> _deleteSession(
      Map<String, dynamic> session,
      ) async {
    final sessionId =
        session['id']?.toString() ??
            '';

    if (sessionId.isEmpty) {
      return;
    }

    final confirm =
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Hapus Sesi?',
          ),
          content: const Text(
            'Sesi absensi dan seluruh data absensinya akan dihapus.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                    context,
                    false,
                  ),
              child: const Text(
                'Batal',
              ),
            ),
            FilledButton(
              style:
              FilledButton.styleFrom(
                backgroundColor:
                Colors.red,
              ),
              onPressed: () =>
                  Navigator.pop(
                    context,
                    true,
                  ),
              child: const Text(
                'Hapus',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }

    try {
      final records =
      await _firestore
          .collection(
        'attendance_records',
      )
          .where(
        'sessionId',
        isEqualTo: sessionId,
      )
          .get();

      final batch =
      _firestore.batch();

      for (final doc
      in records.docs) {
        batch.delete(
          doc.reference,
        );
      }

      batch.delete(
        _firestore
            .collection(
          'attendance_sessions',
        )
            .doc(sessionId),
      );

      await batch.commit();

      _showMessage(
        'Sesi berhasil dihapus.',
      );

      await _loadData();
    } catch (e) {
      debugPrint(
        'Gagal menghapus sesi: $e',
      );

      _showMessage(
        'Gagal menghapus sesi.',
      );
    }
  }

  // =========================================================
  // HELPERS
  // =========================================================

  String _formatDate(
      DateTime date,
      ) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(
      TimeOfDay time,
      ) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
        SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title:
        const Text(
          'Attendance',
        ),
        actions: [
          IconButton(
            onPressed:
            _loadData,
            icon:
            const Icon(
              Icons
                  .refresh_rounded,
            ),
          ),
        ],
      ),

      floatingActionButton:
      FloatingActionButton.extended(
        onPressed:
        _createSession,
        icon:
        const Icon(
          Icons.add_rounded,
        ),
        label:
        const Text(
          'Buat Absensi',
        ),
      ),

      body: _loading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : RefreshIndicator(
        onRefresh:
        _loadData,
        child: _sessions.isEmpty
            ? ListView(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets
              .all(
            24,
          ),
          children: [
            SizedBox(
              height:
              MediaQuery.sizeOf(
                context,
              ).height *
                  0.20,
            ),
            Icon(
              Icons
                  .fact_check_outlined,
              size: 64,
              color: colorScheme
                  .primary
                  .withOpacity(
                0.55,
              ),
            ),
            const SizedBox(
              height: 16,
            ),
            Text(
              'Belum Ada Sesi Absensi',
              textAlign:
              TextAlign
                  .center,
              style: theme
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight:
                FontWeight
                    .w800,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              _courses.isEmpty
                  ? 'Belum ada course yang terhubung dengan akun guru ini.'
                  : 'Belum ada sesi absensi. Tekan tombol "Buat Absensi" untuk membuat sesi baru.',
              textAlign:
              TextAlign
                  .center,
              style: theme
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color: colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        )
            : ListView
            .separated(
          physics:
          const AlwaysScrollableScrollPhysics(),
          padding:
          const EdgeInsets
              .fromLTRB(
            16,
            16,
            16,
            100,
          ),
          itemCount:
          _sessions.length,
          separatorBuilder:
              (_, __) =>
          const SizedBox(
            height: 12,
          ),
          itemBuilder:
              (
              context,
              index,
              ) {
            final session =
            _sessions[
            index];

            return _buildSessionCard(
              session,
            );
          },
        ),
      ),
    );
  }

  // =========================================================
  // SESSION CARD
  // =========================================================

  Widget _buildSessionCard(
      Map<String, dynamic> session,
      ) {
    final theme =
    Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    final title =
    (session['courseName'] ??
        'Course')
        .toString();

    final className =
    (session['className'] ??
        session['classId'] ??
        '-')
        .toString();

    final date =
    (session['date'] ?? '-')
        .toString();

    final startTime =
    (session['startTime'] ??
        '-')
        .toString();

    final endTime =
    (session['endTime'] ??
        '-')
        .toString();

    final status =
    (session['status'] ??
        'open')
        .toString();

    final isClosed =
        status == 'closed' ||
            status == 'selesai';

    return Material(
      color:
      colorScheme.surface,
      borderRadius:
      BorderRadius.circular(
        18,
      ),
      child: InkWell(
        onTap: () =>
            _openSession(
              session,
            ),
        borderRadius:
        BorderRadius.circular(
          18,
        ),
        child: Container(
          padding:
          const EdgeInsets.all(
            16,
          ),
          decoration:
          BoxDecoration(
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
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
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
                          .fact_check_rounded,
                      color:
                      colorScheme
                          .primary,
                    ),
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child:
                    Column(
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          title,
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
                          height: 4,
                        ),
                        Text(
                          className,
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
                  PopupMenuButton<
                      String>(
                    onSelected:
                        (value) {
                      if (value ==
                          'delete') {
                        _deleteSession(
                          session,
                        );
                      }
                    },
                    itemBuilder:
                        (context) =>
                    const [
                      PopupMenuItem(
                        value:
                        'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons
                                  .delete_outline_rounded,
                              color: Colors
                                  .red,
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
                    ],
                  ),
                ],
              ),

              const SizedBox(
                height: 16,
              ),

              Row(
                children: [
                  _buildSessionInfo(
                    Icons
                        .calendar_today_rounded,
                    date,
                  ),
                  const SizedBox(
                    width: 18,
                  ),
                  _buildSessionInfo(
                    Icons
                        .access_time_rounded,
                    '$startTime - $endTime',
                  ),
                ],
              ),

              const SizedBox(
                height: 14,
              ),

              Row(
                children: [
                  Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration:
                    BoxDecoration(
                      color: isClosed
                          ? Colors.grey
                          .withOpacity(
                        0.12,
                      )
                          : Colors.green
                          .withOpacity(
                        0.12,
                      ),
                      borderRadius:
                      BorderRadius
                          .circular(
                        99,
                      ),
                    ),
                    child: Text(
                      isClosed
                          ? 'Selesai'
                          : 'Aktif',
                      style:
                      TextStyle(
                        fontSize: 12,
                        fontWeight:
                        FontWeight
                            .w700,
                        color: isClosed
                            ? Colors.grey
                            : Colors.green,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Kelola Absensi',
                    style:
                    TextStyle(
                      color:
                      colorScheme
                          .primary,
                      fontWeight:
                      FontWeight
                          .w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(
                    width: 4,
                  ),
                  Icon(
                    Icons
                        .arrow_forward_rounded,
                    size: 17,
                    color:
                    colorScheme
                        .primary,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionInfo(
      IconData icon,
      String text,
      ) {
    final colorScheme =
        Theme.of(context)
            .colorScheme;

    return Row(
      mainAxisSize:
      MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme
              .onSurfaceVariant,
        ),
        const SizedBox(
          width: 6,
        ),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme
                .onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// =================================================================
// SESSION DETAIL PAGE
// =================================================================

class _TeacherAttendanceSessionPage
    extends StatefulWidget {
  final Map<String, dynamic> session;

  const _TeacherAttendanceSessionPage({
    required this.session,
  });

  @override
  State<
      _TeacherAttendanceSessionPage>
  createState() =>
      _TeacherAttendanceSessionPageState();
}

class _TeacherAttendanceSessionPageState
    extends State<
        _TeacherAttendanceSessionPage> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool _loading = true;
  bool _saving = false;

  List<Map<String, dynamic>>
  _students = [];

  final Map<String, String>
  _statuses = {};

  final Map<String, String>
  _notes = {};

  String get _sessionId =>
      widget.session['id']
          ?.toString() ??
          '';

  String get _classId =>
      widget.session['classId']
          ?.toString() ??
          '';

  bool get _isClosed {
    final status = widget
        .session['status']
        ?.toString()
        .toLowerCase();

    return status == 'closed' ||
        status == 'selesai';
  }

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  // =========================================================
  // LOAD STUDENTS
  // =========================================================

  Future<void> _loadStudents() async {
    try {
      final snapshot =
      await _firestore
          .collection('users')
          .where(
        'role',
        isEqualTo: 'student',
      )
          .get();

      final students = snapshot.docs
          .where((doc) {
        final data =
        doc.data();

        final studentClass =
        (data['classId'] ??
            '')
            .toString();

        return studentClass ==
            _classId;
      })
          .map((doc) {
        final data =
        doc.data();

        return <String, dynamic>{
          'id': doc.id,
          ...data,
        };
      })
          .toList();

      students.sort(
            (a, b) {
          final aName =
          (a['name'] ??
              a['username'] ??
              '')
              .toString()
              .toLowerCase();

          final bName =
          (b['name'] ??
              b['username'] ??
              '')
              .toString()
              .toLowerCase();

          return aName.compareTo(
            bName,
          );
        },
      );

      // =====================================================
      // LOAD ATTENDANCE RECORDS
      // =====================================================

      final recordSnapshot =
      await _firestore
          .collection(
        'attendance_records',
      )
          .where(
        'sessionId',
        isEqualTo: _sessionId,
      )
          .get();

      for (final record
      in recordSnapshot.docs) {
        final data =
        record.data();

        final studentId =
        (data['studentId'] ??
            '')
            .toString();

        final status =
        (data['status'] ??
            'Alpa')
            .toString();

        final note =
        (data['note'] ?? '')
            .toString();

        if (studentId
            .isNotEmpty) {
          _statuses[
          studentId] =
              status;

          _notes[studentId] =
              note;
        }
      }

      // =====================================================
      // DEFAULT STATUS
      // =====================================================

      for (final student
      in students) {
        final studentId =
        student['id']
            .toString();

        _statuses.putIfAbsent(
          studentId,
              () => 'Alpa',
        );

        _notes.putIfAbsent(
          studentId,
              () => '',
        );
      }

      if (!mounted) return;

      setState(() {
        _students =
            students;
        _loading = false;
      });
    } catch (e) {
      debugPrint(
        'Gagal memuat siswa: $e',
      );

      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        'Gagal memuat daftar siswa.',
      );
    }
  }

  // =========================================================
  // SAVE ATTENDANCE
  // =========================================================

  Future<void> _saveAttendance() async {
    if (_students.isEmpty) {
      _showMessage(
        'Tidak ada siswa di kelas ini.',
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final batch =
      _firestore.batch();

      for (final student
      in _students) {
        final studentId =
        student['id']
            .toString();

        final studentName =
        (student['name'] ??
            student['username'] ??
            'Siswa')
            .toString();

        final status =
            _statuses[
            studentId] ??
                'Alpa';

        final note =
            _notes[studentId] ??
                '';

        final docId =
            '${_sessionId}_$studentId';

        final reference =
        _firestore
            .collection(
          'attendance_records',
        )
            .doc(docId);

        batch.set(
          reference,
          {
            'sessionId':
            _sessionId,
            'studentId':
            studentId,
            'studentName':
            studentName,
            'classId':
            _classId,
            'status':
            status,
            'note':
            note,
            'submittedAt':
            FieldValue
                .serverTimestamp(),
            'updatedAt':
            FieldValue
                .serverTimestamp(),
          },
          SetOptions(
            merge: true,
          ),
        );
      }

      await batch.commit();

      if (!mounted) return;

      _showMessage(
        'Absensi berhasil disimpan.',
      );
    } catch (e) {
      debugPrint(
        'Gagal menyimpan attendance: $e',
      );

      if (!mounted) return;

      _showMessage(
        'Gagal menyimpan absensi.',
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });
    }
  }

  // =========================================================
  // CLOSE SESSION
  // =========================================================

  Future<void> _closeSession() async {
    if (_isClosed) return;

    final confirm =
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Tutup Absensi?',
          ),
          content: const Text(
            'Setelah ditutup, sesi absensi tidak dapat diubah lagi oleh siswa.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                    context,
                    false,
                  ),
              child: const Text(
                'Batal',
              ),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                    context,
                    true,
                  ),
              child: const Text(
                'Tutup Absensi',
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _firestore
          .collection(
        'attendance_sessions',
      )
          .doc(_sessionId)
          .update({
        'status': 'closed',
        'updatedAt':
        FieldValue
            .serverTimestamp(),
      });

      if (!mounted) return;

      _showMessage(
        'Sesi absensi ditutup.',
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint(
        'Gagal menutup session: $e',
      );

      if (!mounted) return;

      _showMessage(
        'Gagal menutup sesi absensi.',
      );
    }
  }

  // =========================================================
  // STATUS COLOR
  // =========================================================

  Color _statusColor(
      String status,
      ) {
    switch (status) {
      case 'Hadir':
        return Colors.green;

      case 'Izin':
        return Colors.orange;

      case 'Sakit':
        return Colors.blue;

      case 'Alpa':
      default:
        return Colors.red;
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.session[
          'courseName']
              ?.toString() ??
              'Attendance',
        ),
        actions: [
          if (!_isClosed)
            IconButton(
              onPressed:
              _saving
                  ? null
                  : _saveAttendance,
              icon: const Icon(
                Icons
                    .save_rounded,
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
        child:
        CircularProgressIndicator(),
      )
          : Column(
        children: [
          _buildSessionHeader(),
          _buildSummary(),
          Expanded(
            child: _students.isEmpty
                ? Center(
              child:
              Text(
                'Tidak ada siswa di kelas ini.',
                style: theme
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                  color: colorScheme
                      .onSurfaceVariant,
                ),
              ),
            )
                : RefreshIndicator(
              onRefresh:
              _loadStudents,
              child:
              ListView
                  .separated(
                padding:
                const EdgeInsets
                    .fromLTRB(
                  16,
                  10,
                  16,
                  100,
                ),
                itemCount:
                _students
                    .length,
                separatorBuilder:
                    (_, __) =>
                const SizedBox(
                  height: 8,
                ),
                itemBuilder:
                    (
                    context,
                    index,
                    ) {
                  return _buildStudentCard(
                    _students[
                    index],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
      !_isClosed &&
          !_loading
          ? SafeArea(
        child:
        Padding(
          padding:
          const EdgeInsets
              .fromLTRB(
            16,
            8,
            16,
            12,
          ),
          child:
          Row(
            children: [
              Expanded(
                child:
                OutlinedButton
                    .icon(
                  onPressed:
                  _saving
                      ? null
                      : _closeSession,
                  icon:
                  const Icon(
                    Icons
                        .lock_outline_rounded,
                  ),
                  label:
                  const Text(
                    'Tutup Absensi',
                  ),
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child:
                FilledButton
                    .icon(
                  onPressed:
                  _saving
                      ? null
                      : _saveAttendance,
                  icon: _saving
                      ? const SizedBox(
                    width:
                    17,
                    height:
                    17,
                    child:
                    CircularProgressIndicator(
                      strokeWidth:
                      2,
                      color:
                      Colors.white,
                    ),
                  )
                      : const Icon(
                    Icons
                        .save_rounded,
                  ),
                  label:
                  const Text(
                    'Simpan',
                  ),
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
  // SESSION HEADER
  // =========================================================

  Widget _buildSessionHeader() {
    final theme =
    Theme.of(context);

    return Container(
      width: double.infinity,
      margin:
      const EdgeInsets
          .fromLTRB(
        16,
        12,
        16,
        10,
      ),
      padding:
      const EdgeInsets.all(
        16,
      ),
      decoration:
      BoxDecoration(
        color: theme
            .colorScheme
            .primary
            .withOpacity(
          0.08,
        ),
        borderRadius:
        BorderRadius.circular(
          18,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment
            .start,
        children: [
          Text(
            widget.session[
            'courseName']
                ?.toString() ??
                'Course',
            style: theme
                .textTheme
                .titleMedium
                ?.copyWith(
              fontWeight:
              FontWeight.w800,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            'Kelas: ${widget.session['className'] ?? '-'}',
          ),
          Text(
            'Tanggal: ${widget.session['date'] ?? '-'}',
          ),
          Text(
            'Waktu: ${widget.session['startTime'] ?? '-'} - ${widget.session['endTime'] ?? '-'}',
          ),
        ],
      ),
    );
  }

  // =========================================================
  // SUMMARY
  // =========================================================

  Widget _buildSummary() {
    int hadir = 0;
    int izin = 0;
    int sakit = 0;
    int alpa = 0;

    for (final status
    in _statuses.values) {
      switch (status) {
        case 'Hadir':
          hadir++;
          break;

        case 'Izin':
          izin++;
          break;

        case 'Sakit':
          sakit++;
          break;

        case 'Alpa':
          alpa++;
          break;
      }
    }

    return SizedBox(
      height: 78,
      child: ListView(
        scrollDirection:
        Axis.horizontal,
        padding:
        const EdgeInsets
            .symmetric(
          horizontal: 16,
        ),
        children: [
          _buildSummaryItem(
            'Hadir',
            hadir,
            Colors.green,
          ),
          _buildSummaryItem(
            'Izin',
            izin,
            Colors.orange,
          ),
          _buildSummaryItem(
            'Sakit',
            sakit,
            Colors.blue,
          ),
          _buildSummaryItem(
            'Alpa',
            alpa,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
      String title,
      int count,
      Color color,
      ) {
    return Container(
      width: 82,
      margin:
      const EdgeInsets.only(
        right: 8,
      ),
      padding:
      const EdgeInsets.all(
        10,
      ),
      decoration:
      BoxDecoration(
        color: color.withOpacity(
          0.08,
        ),
        borderRadius:
        BorderRadius.circular(
          14,
        ),
      ),
      child: Column(
        mainAxisAlignment:
        MainAxisAlignment
            .center,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontWeight:
              FontWeight.w800,
              fontSize: 18,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
              FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // STUDENT CARD
  // =========================================================

  Widget _buildStudentCard(
      Map<String, dynamic> student,
      ) {
    final studentId =
    student['id'].toString();

    final name =
    (student['name'] ??
        student['username'] ??
        'Siswa')
        .toString();

    final status =
        _statuses[studentId] ??
            'Alpa';

    final note =
        _notes[studentId] ?? '';

    final color =
    _statusColor(status);

    return Container(
      padding:
      const EdgeInsets.all(
        14,
      ),
      decoration:
      BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surface,
        borderRadius:
        BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outline
              .withOpacity(0.30),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor:
                color.withOpacity(
                  0.10,
                ),
                child: Text(
                  name.isNotEmpty
                      ? name[0]
                      .toUpperCase()
                      : 'S',
                  style:
                  TextStyle(
                    color: color,
                    fontWeight:
                    FontWeight
                        .w800,
                  ),
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Text(
                  name,
                  style:
                  const TextStyle(
                    fontWeight:
                    FontWeight
                        .w700,
                  ),
                ),
              ),
              if (!_isClosed)
                PopupMenuButton<
                    String>(
                  initialValue:
                  status,
                  onSelected:
                      (value) {
                    setState(() {
                      _statuses[
                      studentId] =
                          value;
                    });
                  },
                  itemBuilder:
                      (context) {
                    return const [
                      PopupMenuItem(
                        value:
                        'Hadir',
                        child:
                        Text(
                          'Hadir',
                        ),
                      ),
                      PopupMenuItem(
                        value:
                        'Izin',
                        child:
                        Text(
                          'Izin',
                        ),
                      ),
                      PopupMenuItem(
                        value:
                        'Sakit',
                        child:
                        Text(
                          'Sakit',
                        ),
                      ),
                      PopupMenuItem(
                        value:
                        'Alpa',
                        child:
                        Text(
                          'Alpa',
                        ),
                      ),
                    ];
                  },
                )
              else
                Container(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration:
                  BoxDecoration(
                    color: color
                        .withOpacity(
                      0.10,
                    ),
                    borderRadius:
                    BorderRadius
                        .circular(
                      99,
                    ),
                  ),
                  child: Text(
                    status,
                    style:
                    TextStyle(
                      fontSize: 11,
                      fontWeight:
                      FontWeight
                          .w700,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),

          if (!_isClosed) ...[
            const SizedBox(
              height: 12,
            ),

            Row(
              children: [
                Expanded(
                  child:
                  _buildStatusButton(
                    studentId,
                    'Hadir',
                    Icons
                        .check_circle_outline_rounded,
                    Colors.green,
                  ),
                ),
                const SizedBox(
                  width: 6,
                ),
                Expanded(
                  child:
                  _buildStatusButton(
                    studentId,
                    'Izin',
                    Icons
                        .event_note_rounded,
                    Colors.orange,
                  ),
                ),
                const SizedBox(
                  width: 6,
                ),
                Expanded(
                  child:
                  _buildStatusButton(
                    studentId,
                    'Sakit',
                    Icons
                        .medical_services_outlined,
                    Colors.blue,
                  ),
                ),
                const SizedBox(
                  width: 6,
                ),
                Expanded(
                  child:
                  _buildStatusButton(
                    studentId,
                    'Alpa',
                    Icons
                        .cancel_outlined,
                    Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 10,
            ),

            TextField(
              controller:
              TextEditingController(
                text: note,
              ),
              decoration:
              const InputDecoration(
                labelText:
                'Catatan (opsional)',
                border:
                OutlineInputBorder(),
                isDense: true,
              ),
              onChanged:
                  (value) {
                _notes[studentId] =
                    value;
              },
            ),
          ] else if (note.isNotEmpty) ...[
            const SizedBox(
              height: 8,
            ),
            Align(
              alignment:
              Alignment.centerLeft,
              child: Text(
                'Catatan: $note',
                style:
                TextStyle(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  )
                      .colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =========================================================
  // STATUS BUTTON
  // =========================================================

  Widget _buildStatusButton(
      String studentId,
      String status,
      IconData icon,
      Color color,
      ) {
    final selected =
        _statuses[studentId] ==
            status;

    return InkWell(
      onTap: () {
        setState(() {
          _statuses[studentId] =
              status;
        });
      },
      borderRadius:
      BorderRadius.circular(
        10,
      ),
      child: Container(
        padding:
        const EdgeInsets
            .symmetric(
          vertical: 8,
          horizontal: 4,
        ),
        decoration:
        BoxDecoration(
          color: selected
              ? color.withOpacity(
            0.15,
          )
              : color.withOpacity(
            0.04,
          ),
          borderRadius:
          BorderRadius.circular(
            10,
          ),
          border: Border.all(
            color: selected
                ? color
                : color.withOpacity(
              0.18,
            ),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 17,
              color: color,
            ),
            const SizedBox(
              height: 3,
            ),
            Text(
              status,
              style:
              TextStyle(
                fontSize: 10,
                fontWeight:
                FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
        SnackBarBehavior
            .floating,
      ),
    );
  }
}