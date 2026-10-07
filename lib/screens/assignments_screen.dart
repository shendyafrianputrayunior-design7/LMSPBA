import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/cloudinary_service.dart';

class AssignmentsScreen extends StatefulWidget {
  final String classId;

  const AssignmentsScreen({
    super.key,
    required this.classId,
  });

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Tugas',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('assignments')
            .where(
          'classId',
          isEqualTo: widget.classId,
        )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _ErrorState(
              message:
              'Gagal memuat tugas.\n${snapshot.error}',
            );
          }

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final documents =
              snapshot.data?.docs ?? [];

          if (documents.isEmpty) {
            return const _EmptyState();
          }

          final assignments = documents.map((doc) {
            final data =
            doc.data() as Map<String, dynamic>;

            return {
              'id': doc.id,
              ...data,
            };
          }).toList();

          assignments.sort((a, b) {
            final Timestamp? dateA =
            _timestampFrom(a['dueDate']);

            final Timestamp? dateB =
            _timestampFrom(b['dueDate']);

            if (dateA == null && dateB == null) {
              return 0;
            }

            if (dateA == null) {
              return 1;
            }

            if (dateB == null) {
              return -1;
            }

            return dateA
                .toDate()
                .compareTo(dateB.toDate());
          });

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                32,
              ),
              itemCount: assignments.length,
              itemBuilder: (context, index) {
                final assignment =
                assignments[index];

                return _AssignmentCard(
                  assignment: assignment,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AssignmentDetailScreen(
                              assignment: assignment,
                            ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }

  static Timestamp? _timestampFrom(
      dynamic value,
      ) {
    if (value is Timestamp) {
      return value;
    }

    if (value is DateTime) {
      return Timestamp.fromDate(value);
    }

    return null;
  }
}

// ============================================================
// ASSIGNMENT CARD
// ============================================================

class _AssignmentCard extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final VoidCallback onTap;

  const _AssignmentCard({
    required this.assignment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String title =
    (assignment['title'] ?? 'Tanpa Judul')
        .toString();

    final String courseTitle =
    (assignment['courseTitle'] ?? '-')
        .toString();

    final String teacherName =
    (assignment['teacherName'] ?? '-')
        .toString();

    final String description =
    (assignment['description'] ?? '')
        .toString();

    final int points =
    _parseInt(assignment['points']);

    final Timestamp? dueDate =
    assignment['dueDate'] is Timestamp
        ? assignment['dueDate'] as Timestamp
        : null;

    final DateTime? dueDateTime =
    dueDate?.toDate();

    final bool isOverdue =
        dueDateTime != null &&
            DateTime.now().isAfter(dueDateTime);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
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
                      const Color(0xFFEFF4FF),
                      borderRadius:
                      BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow:
                          TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight:
                            FontWeight.w700,
                            color:
                            Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          courseTitle,
                          maxLines: 1,
                          overflow:
                          TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                            Colors.grey.shade600,
                            fontWeight:
                            FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(
                    text: isOverdue
                        ? 'Lewat'
                        : 'Aktif',
                    color: isOverdue
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (description.isNotEmpty)
                Text(
                  description,
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color:
                    Colors.grey.shade700,
                  ),
                ),
              if (description.isNotEmpty)
                const SizedBox(height: 14),
              Divider(
                height: 1,
                color: Colors.grey.shade200,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _InfoItem(
                      icon:
                      Icons.person_outline,
                      label: teacherName,
                    ),
                  ),
                  Expanded(
                    child: _InfoItem(
                      icon: Icons
                          .calendar_today_outlined,
                      label: dueDateTime == null
                          ? 'Tidak ada deadline'
                          : _formatDate(
                        dueDateTime,
                      ),
                    ),
                  ),
                  _PointsBadge(
                    points: points,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }
}

// ============================================================
// ASSIGNMENT DETAIL
// ============================================================

class AssignmentDetailScreen
    extends StatefulWidget {
  final Map<String, dynamic> assignment;

  const AssignmentDetailScreen({
    super.key,
    required this.assignment,
  });

  @override
  State<AssignmentDetailScreen> createState() =>
      _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState
    extends State<AssignmentDetailScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  User? get _user =>
      FirebaseAuth.instance.currentUser;

  bool _uploading = false;

  PlatformFile? _selectedFile;

  static const int _maxFileSize =
      10 * 1024 * 1024;

  String get assignmentId =>
      (widget.assignment['id'] ?? '')
          .toString();

  String get assignmentTitle =>
      (widget.assignment['title'] ??
          'Tanpa Judul')
          .toString();

  String get courseTitle =>
      (widget.assignment['courseTitle'] ??
          '-')
          .toString();

  String get teacherName =>
      (widget.assignment['teacherName'] ??
          '-')
          .toString();

  String get description =>
      (widget.assignment['description'] ?? '')
          .toString();

  String get instructions =>
      (widget.assignment['instructions'] ?? '')
          .toString();

  int get points =>
      _parseInt(widget.assignment['points']);

  DateTime? get dueDate {
    final value =
    widget.assignment['dueDate'];

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }

  bool get isOverdue {
    final date = dueDate;

    if (date == null) {
      return false;
    }

    return DateTime.now().isAfter(date);
  }

  DocumentReference<Map<String, dynamic>>?
  get _submissionReference {
    final user = _user;

    if (user == null ||
        assignmentId.isEmpty) {
      return null;
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection(
      'assignment_submissions',
    )
        .doc(assignmentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
      const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Detail Tugas',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: StreamBuilder<
          DocumentSnapshot<
              Map<String, dynamic>>>(
        stream:
        _submissionReference?.snapshots(),
        builder: (context, snapshot) {
          final submission =
          snapshot.data?.data();

          return ListView(
            padding:
            const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              32,
            ),
            children: [
              _buildHeaderCard(),
              const SizedBox(height: 14),
              _buildInformationCard(),
              const SizedBox(height: 14),
              _buildDescriptionCard(),
              if (instructions.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildInstructionsCard(),
              ],
              const SizedBox(height: 14),
              _buildSubmissionCard(
                submission: submission,
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================================
  // HEADER
  // ==========================================================

  Widget _buildHeaderCard() {
    final bool overdue = isOverdue;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color:
                  const Color(0xFFEFF4FF),
                  borderRadius:
                  BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.assignment_rounded,
                  size: 28,
                  color:
                  Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  assignmentTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.25,
                    fontWeight:
                    FontWeight.w800,
                    color:
                    Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            courseTitle,
            style: const TextStyle(
              fontSize: 14,
              fontWeight:
              FontWeight.w600,
              color:
              Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.person_outline,
                size: 16,
                color:
                Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  teacherName,
                  style: TextStyle(
                    fontSize: 13,
                    color:
                    Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding:
            const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: overdue
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFF0FDF4),
              borderRadius:
              BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  overdue
                      ? Icons
                      .warning_amber_rounded
                      : Icons
                      .schedule_outlined,
                  size: 19,
                  color: overdue
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF16A34A),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dueDate == null
                        ? 'Tidak ada batas pengumpulan'
                        : overdue
                        ? 'Batas pengumpulan telah lewat: ${_formatDateTime(dueDate!)}'
                        : 'Batas pengumpulan: ${_formatDateTime(dueDate!)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                      FontWeight.w600,
                      color: overdue
                          ? const Color(
                        0xFFDC2626,
                      )
                          : const Color(
                        0xFF15803D,
                      ),
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

  // ==========================================================
  // INFORMATION
  // ==========================================================

  Widget _buildInformationCard() {
    return _SectionCard(
      title: 'Informasi Tugas',
      icon: Icons.info_outline,
      child: Column(
        children: [
          _DetailRow(
            icon:
            Icons.menu_book_outlined,
            label: 'Mata Pelajaran',
            value: courseTitle,
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon:
            Icons.person_outline,
            label: 'Guru',
            value: teacherName,
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon:
            Icons.stars_outlined,
            label: 'Poin',
            value: '$points poin',
          ),
          const SizedBox(height: 12),
          _DetailRow(
            icon:
            Icons.event_outlined,
            label:
            'Batas Pengumpulan',
            value: dueDate == null
                ? '-'
                : _formatDateTime(
              dueDate!,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================
  // DESCRIPTION
  // ==========================================================

  Widget _buildDescriptionCard() {
    return _SectionCard(
      title: 'Deskripsi',
      icon:
      Icons.description_outlined,
      child: Text(
        description.isEmpty
            ? 'Tidak ada deskripsi.'
            : description,
        style: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: description.isEmpty
              ? Colors.grey.shade500
              : Colors.grey.shade800,
        ),
      ),
    );
  }

  // ==========================================================
  // INSTRUCTIONS
  // ==========================================================

  Widget _buildInstructionsCard() {
    return _SectionCard(
      title: 'Instruksi Pengerjaan',
      icon: Icons.list_alt_outlined,
      child: Text(
        instructions,
        style: TextStyle(
          fontSize: 14,
          height: 1.6,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  // ==========================================================
  // SUBMISSION
  // ==========================================================

  Widget _buildSubmissionCard({
    required Map<String, dynamic>?
    submission,
  }) {
    final bool submitted =
        submission != null;

    final String fileName =
    (submission?['fileName'] ?? '')
        .toString();

    final String fileUrl =
    (submission?['fileUrl'] ?? '')
        .toString();

    final dynamic rawSize =
        submission?['fileSize'] ??
            submission?['size'];

    final int fileSize =
    _parseInt(rawSize);

    final Timestamp? submittedAt =
    submission?['submittedAt']
    is Timestamp
        ? submission!['submittedAt']
    as Timestamp
        : null;

    return _SectionCard(
      title: 'Pengumpulan Tugas',
      icon:
      Icons.upload_file_outlined,
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          if (submitted)
            _buildSubmittedFile(
              fileName: fileName,
              fileUrl: fileUrl,
              fileSize: fileSize,
              submittedAt: submittedAt,
            )
          else
            _buildNotSubmitted(),
          const SizedBox(height: 16),
          if (_selectedFile != null)
            _buildSelectedFile(),
          if (_selectedFile != null)
            const SizedBox(height: 12),
          if (!isOverdue) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                _uploading
                    ? null
                    : _pickFile,
                icon: const Icon(
                  Icons.attach_file,
                ),
                label: Text(
                  submitted
                      ? 'Ganti File'
                      : 'Pilih File',
                ),
                style:
                OutlinedButton.styleFrom(
                  padding:
                  const EdgeInsets
                      .symmetric(
                    vertical: 14,
                  ),
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
              ),
            ),
            if (_selectedFile != null) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _uploading
                      ? null
                      : _submitAssignment,
                  icon: _uploading
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                    CircularProgressIndicator(
                      strokeWidth: 2,
                      color:
                      Colors.white,
                    ),
                  )
                      : const Icon(
                    Icons
                        .cloud_upload_outlined,
                  ),
                  label: Text(
                    _uploading
                        ? 'Mengunggah...'
                        : submitted
                        ? 'Kirim Penggantian'
                        : 'Kumpulkan Tugas',
                  ),
                  style:
                  ElevatedButton.styleFrom(
                    backgroundColor:
                    const Color(
                      0xFF2563EB,
                    ),
                    foregroundColor:
                    Colors.white,
                    padding:
                    const EdgeInsets
                        .symmetric(
                      vertical: 14,
                    ),
                    shape:
                    RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ] else
            Container(
              width: double.infinity,
              padding:
              const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color:
                const Color(0xFFFEF2F2),
                borderRadius:
                BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons
                        .lock_clock_outlined,
                    color:
                    Color(0xFFDC2626),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Batas pengumpulan tugas sudah lewat.',
                      style: TextStyle(
                        color:
                        Color(0xFFB91C1C),
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (submitted &&
              !isOverdue) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed:
                _uploading
                    ? null
                    : () =>
                    _deleteSubmission(
                      fileName:
                      fileName,
                    ),
                icon: const Icon(
                  Icons.delete_outline,
                  color:
                  Color(0xFFDC2626),
                ),
                label: const Text(
                  'Hapus Pengumpulan',
                  style: TextStyle(
                    color:
                    Color(0xFFDC2626),
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotSubmitted() {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
        const Color(0xFFFFFBEB),
        borderRadius:
        BorderRadius.circular(14),
        border: Border.all(
          color:
          const Color(0xFFFDE68A),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons
                .pending_actions_outlined,
            color:
            Color(0xFFD97706),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Tugas belum dikumpulkan.',
              style: TextStyle(
                color:
                Color(0xFF92400E),
                fontWeight:
                FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedFile({
    required String fileName,
    required String fileUrl,
    required int fileSize,
    required Timestamp? submittedAt,
  }) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
        const Color(0xFFF0FDF4),
        borderRadius:
        BorderRadius.circular(14),
        border: Border.all(
          color:
          const Color(0xFFBBF7D0),
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.check_circle,
                color:
                Color(0xFF16A34A),
              ),
              SizedBox(width: 8),
              Text(
                'Sudah Dikumpulkan',
                style: TextStyle(
                  fontWeight:
                  FontWeight.w700,
                  color:
                  Color(0xFF15803D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons
                    .insert_drive_file_outlined,
                color:
                Color(0xFF2563EB),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName.isEmpty
                          ? 'File pengumpulan'
                          : fileName,
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                    if (fileSize > 0) ...[
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        _formatFileSize(
                          fileSize,
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors
                              .grey.shade600,
                        ),
                      ),
                    ],
                    if (submittedAt !=
                        null) ...[
                      const SizedBox(
                        height: 4,
                      ),
                      Text(
                        'Dikumpulkan ${_formatDateTime(submittedAt.toDate())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors
                              .grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (fileUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    _openFile(fileUrl),
                icon: const Icon(
                  Icons.open_in_new,
                  size: 18,
                ),
                label:
                const Text('Lihat File'),
                style:
                OutlinedButton.styleFrom(
                  foregroundColor:
                  const Color(
                    0xFF2563EB,
                  ),
                  padding:
                  const EdgeInsets
                      .symmetric(
                    vertical: 12,
                  ),
                  shape:
                  RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(
                      10,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================
  // SELECTED FILE
  // ==========================================================

  Widget _buildSelectedFile() {
    final file = _selectedFile!;

    return FutureBuilder<int>(
      future: _getSelectedFileSize(file),
      builder: (context, snapshot) {
        final int fileSize =
            snapshot.data ?? 0;

        return Container(
          width: double.infinity,
          padding:
          const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
            const Color(0xFFEFF6FF),
            borderRadius:
            BorderRadius.circular(12),
            border: Border.all(
              color:
              const Color(0xFFBFDBFE),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.attach_file,
                color:
                Color(0xFF2563EB),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      snapshot.connectionState ==
                          ConnectionState
                              .waiting
                          ? 'Menghitung ukuran...'
                          : _formatFileSize(
                        fileSize,
                      ),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                        Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _uploading
                    ? null
                    : () {
                  setState(() {
                    _selectedFile =
                    null;
                  });
                },
                icon:
                const Icon(Icons.close),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<int> _getSelectedFileSize(
      PlatformFile file,
      ) async {
    final path = file.path;

    if (path == null || path.isEmpty) {
      return 0;
    }

    final localFile = File(path);

    if (!await localFile.exists()) {
      return 0;
    }

    return localFile.length();
  }

  // ==========================================================
  // PICK FILE
  // ==========================================================

  Future<void> _pickFile() async {
    try {
      final result =
      await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: [
          'pdf',
          'doc',
          'docx',
          'ppt',
          'pptx',
          'xls',
          'xlsx',
          'jpg',
          'jpeg',
          'png',
          'zip',
          'rar',
        ],
      );

      if (result == null) {
        return;
      }

      if (result.path == null ||
          result.path!.isEmpty) {
        if (!mounted) return;

        _showSnackBar(
          'File tidak dapat diakses.',
          isError: true,
        );
        return;
      }

      final localFile =
      File(result.path!);

      if (!await localFile.exists()) {
        if (!mounted) return;

        _showSnackBar(
          'File tidak ditemukan.',
          isError: true,
        );
        return;
      }

      final fileSize =
      await localFile.length();

      if (fileSize > _maxFileSize) {
        if (!mounted) return;

        _showSnackBar(
          'Ukuran file maksimal 10 MB.',
          isError: true,
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _selectedFile = result;
      });
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Gagal memilih file: $e',
        isError: true,
      );
    }
  }

  // ==========================================================
  // SUBMIT
  // ==========================================================

  Future<void> _submitAssignment() async {
    final user = _user;

    if (user == null) {
      _showSnackBar(
        'Silakan login terlebih dahulu.',
        isError: true,
      );
      return;
    }

    if (_selectedFile == null) {
      _showSnackBar(
        'Pilih file terlebih dahulu.',
        isError: true,
      );
      return;
    }

    if (isOverdue) {
      _showSnackBar(
        'Batas pengumpulan tugas sudah lewat.',
        isError: true,
      );
      return;
    }

    final path =
        _selectedFile!.path;

    if (path == null || path.isEmpty) {
      _showSnackBar(
        'File tidak dapat diakses.',
        isError: true,
      );
      return;
    }

    final localFile = File(path);

    if (!await localFile.exists()) {
      _showSnackBar(
        'File tidak ditemukan.',
        isError: true,
      );
      return;
    }

    final actualFileSize =
    await localFile.length();

    if (actualFileSize > _maxFileSize) {
      _showSnackBar(
        'Ukuran file maksimal 10 MB.',
        isError: true,
      );
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      final fileUrl =
      await CloudinaryService
          .uploadAssignmentFile(
        localFile,
      );

      if (fileUrl == null ||
          fileUrl.isEmpty) {
        throw Exception(
          'Upload ke Cloudinary gagal.',
        );
      }

      final submissionRef =
      _firestore
          .collection('users')
          .doc(user.uid)
          .collection(
        'assignment_submissions',
      )
          .doc(assignmentId);

      await submissionRef.set(
        {
          'assignmentId':
          assignmentId,
          'studentId':
          user.uid,

          'classId':
          (widget.assignment[
          'classId'] ??
              '')
              .toString(),

          'courseId':
          (widget.assignment[
          'courseId'] ??
              '')
              .toString(),

          'courseTitle':
          (widget.assignment[
          'courseTitle'] ??
              '')
              .toString(),

          'assignmentTitle':
          assignmentTitle,

          'teacherId':
          (widget.assignment[
          'teacherId'] ??
              '')
              .toString(),

          'teacherName':
          (widget.assignment[
          'teacherName'] ??
              '')
              .toString(),

          'fileName':
          _selectedFile!.name,

          'fileUrl':
          fileUrl,

          'fileSize':
          actualFileSize,

          'storagePath':
          'cloudinary/$assignmentId/${_selectedFile!.name}',

          'status':
          'Dikumpulkan',

          'submittedAt':
          FieldValue.serverTimestamp(),

          'updatedAt':
          FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _selectedFile = null;
      });

      _showSnackBar(
        'Tugas berhasil dikumpulkan.',
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Gagal mengumpulkan tugas: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  // ==========================================================
  // DELETE SUBMISSION
  // ==========================================================

  Future<void> _deleteSubmission({
    required String fileName,
  }) async {
    if (isOverdue) {
      _showSnackBar(
        'Pengumpulan tidak dapat dihapus setelah deadline.',
        isError: true,
      );
      return;
    }

    final confirmed =
    await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Hapus Pengumpulan?',
          ),
          content: Text(
            fileName.isEmpty
                ? 'File pengumpulan akan dihapus dari data tugas.'
                : 'File "$fileName" akan dihapus dari data pengumpulan.',
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
              const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              style:
              ElevatedButton.styleFrom(
                backgroundColor:
                const Color(
                  0xFFDC2626,
                ),
                foregroundColor:
                Colors.white,
              ),
              child:
              const Text('Hapus'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final ref =
        _submissionReference;

    if (ref == null) {
      _showSnackBar(
        'Data pengguna tidak ditemukan.',
        isError: true,
      );
      return;
    }

    setState(() {
      _uploading = true;
    });

    try {
      await ref.delete();

      if (!mounted) return;

      _showSnackBar(
        'Pengumpulan berhasil dihapus.',
      );
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Gagal menghapus pengumpulan: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploading = false;
        });
      }
    }
  }

  // ==========================================================
  // OPEN FILE
  // ==========================================================

  Future<void> _openFile(
      String url,
      ) async {
    try {
      final uri =
      Uri.tryParse(url);

      if (uri == null) {
        _showSnackBar(
          'URL file tidak valid.',
          isError: true,
        );
        return;
      }

      final opened =
      await launchUrl(
        uri,
        mode:
        LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        _showSnackBar(
          'File tidak dapat dibuka.',
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        'Gagal membuka file: $e',
        isError: true,
      );
    }
  }

  // ==========================================================
  // SNACKBAR
  // ==========================================================

  void _showSnackBar(
      String message, {
        bool isError = false,
      }) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFDC2626)
            : const Color(0xFF16A34A),
        behavior:
        SnackBarBehavior.floating,
      ),
    );
  }

  static int _parseInt(
      dynamic value,
      ) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(
      value?.toString() ?? '',
    ) ??
        0;
  }
}

// ============================================================
// SECTION CARD
// ============================================================

class _SectionCard
    extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color:
                const Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight:
                  FontWeight.w700,
                  color:
                  Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ============================================================
// DETAIL ROW
// ============================================================

class _DetailRow
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color:
            const Color(0xFFF3F4F6),
            borderRadius:
            BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color:
            Colors.grey.shade700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color:
                  Colors.grey.shade500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style:
                const TextStyle(
                  fontSize: 14,
                  fontWeight:
                  FontWeight.w600,
                  color:
                  Color(0xFF111827),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// INFO ITEM
// ============================================================

class _InfoItem
    extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color:
          Colors.grey.shade500,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color:
              Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// STATUS BADGE
// ============================================================

class _StatusBadge
    extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius:
        BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight:
          FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ============================================================
// POINTS BADGE
// ============================================================

class _PointsBadge
    extends StatelessWidget {
  final int points;

  const _PointsBadge({
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color:
        const Color(0xFFFFF7ED),
        borderRadius:
        BorderRadius.circular(8),
      ),
      child: Text(
        '$points poin',
        style: const TextStyle(
          fontSize: 10,
          fontWeight:
          FontWeight.w700,
          color:
          Color(0xFFC2410C),
        ),
      ),
    );
  }
}

// ============================================================
// EMPTY STATE
// ============================================================

class _EmptyState
    extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color:
                const Color(0xFFEFF4FF),
                borderRadius:
                BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 42,
                color:
                Color(0xFF2563EB),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Belum Ada Tugas',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Belum ada tugas untuk kelas ini.',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ERROR STATE
// ============================================================

class _ErrorState
    extends StatelessWidget {
  final String message;

  const _ErrorState({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 50,
              color:
              Color(0xFFDC2626),
            ),
            const SizedBox(height: 14),
            const Text(
              'Terjadi Kesalahan',
              style: TextStyle(
                fontSize: 18,
                fontWeight:
                FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color:
                Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FORMAT DATE
// ============================================================

String _formatDate(
    DateTime date,
    ) {
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

  return '${date.day} '
      '${months[date.month - 1]} '
      '${date.year}';
}

String _formatDateTime(
    DateTime date,
    ) {
  final hour =
  date.hour.toString().padLeft(
    2,
    '0',
  );

  final minute =
  date.minute.toString().padLeft(
    2,
    '0',
  );

  return '${_formatDate(date)}, '
      '$hour:$minute';
}

// ============================================================
// FORMAT FILE SIZE
// ============================================================

String _formatFileSize(
    int bytes,
    ) {
  if (bytes <= 0) {
    return '0 B';
  }

  if (bytes < 1024) {
    return '$bytes B';
  }

  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  if (bytes <
      1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}