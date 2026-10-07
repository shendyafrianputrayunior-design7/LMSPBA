import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TeacherAssignmentSubmissionsScreen extends StatefulWidget {
  final String assignmentId;
  final Map<String, dynamic> assignmentData;

  const TeacherAssignmentSubmissionsScreen({
    super.key,
    required this.assignmentId,
    required this.assignmentData,
  });

  @override
  State<TeacherAssignmentSubmissionsScreen> createState() =>
      _TeacherAssignmentSubmissionsScreenState();
}

class _TeacherAssignmentSubmissionsScreenState
    extends State<TeacherAssignmentSubmissionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _formatDate(dynamic value) {
    if (value is Timestamp) {
      return _formatDateTime(value.toDate());
    }

    if (value is DateTime) {
      return _formatDateTime(value);
    }

    return '-';
  }

  String _formatDateTime(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatFileSize(dynamic value) {
    final bytes = int.tryParse(value?.toString() ?? '') ?? 0;

    if (bytes <= 0) {
      return '-';
    }

    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _studentName(Map<String, dynamic> data) {
    final value = data['studentName'] ??
        data['name'] ??
        data['displayName'] ??
        data['username'];

    if (value == null) {
      return 'Siswa';
    }

    final name = value.toString().trim();

    return name.isEmpty ? 'Siswa' : name;
  }

  Future<Map<String, dynamic>?> _getStudent(
      String studentId,
      ) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(studentId)
          .get();

      return doc.data();
    } catch (e) {
      debugPrint(
        'Gagal mengambil data siswa $studentId: $e',
      );

      return null;
    }
  }

  Future<void> _openFile(String url) async {
    if (url.trim().isEmpty) {
      _showMessage('File tugas tidak tersedia.');
      return;
    }

    try {
      final uri = Uri.parse(url);

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _showMessage('Tidak dapat membuka file tugas.');
      }
    } catch (e) {
      _showMessage(
        'Gagal membuka file:\n$e',
      );
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _showSubmissionDetail(
      QueryDocumentSnapshot<Map<String, dynamic>> submission,
      ) async {
    final data = submission.data();

    final studentId =
    (data['studentId'] ?? '').toString();

    Map<String, dynamic>? studentData;

    if (studentId.isNotEmpty) {
      studentData = await _getStudent(studentId);
    }

    if (!mounted) return;

    final studentName = studentData == null
        ? _studentName(data)
        : _studentName(studentData);

    final email = studentData?['email']?.toString() ?? '-';

    final fileName =
    (data['fileName'] ?? 'File tugas').toString();

    final fileUrl =
    (data['fileUrl'] ?? '').toString();

    final status =
    (data['status'] ?? 'Dikumpulkan').toString();

    final submittedAt =
    _formatDate(data['submittedAt']);

    final fileSize =
    _formatFileSize(data['fileSize']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detail Pengumpulan',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Center(
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor:
                      theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person,
                        size: 40,
                        color:
                        theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Center(
                    child: Text(
                      studentName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 4),

                  Center(
                    child: Text(
                      email,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(
                        color:
                        theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Card(
                    child: Padding(
                      padding:
                      const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: Icons.assignment_outlined,
                            label: 'Assignment',
                            value:
                            (widget.assignmentData['title'] ??
                                'Tanpa Judul')
                                .toString(),
                          ),

                          const Divider(height: 24),

                          _DetailRow(
                            icon: Icons.insert_drive_file_outlined,
                            label: 'File',
                            value: fileName,
                          ),

                          const Divider(height: 24),

                          _DetailRow(
                            icon: Icons.storage_outlined,
                            label: 'Ukuran',
                            value: fileSize,
                          ),

                          const Divider(height: 24),

                          _DetailRow(
                            icon: Icons.access_time_outlined,
                            label: 'Dikumpulkan',
                            value: submittedAt,
                          ),

                          const Divider(height: 24),

                          _DetailRow(
                            icon: Icons.info_outline,
                            label: 'Status',
                            value: status,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: fileUrl.isEmpty
                          ? null
                          : () {
                        _openFile(fileUrl);
                      },
                      icon: const Icon(
                        Icons.open_in_new,
                      ),
                      label: const Text(
                        'Buka File Tugas',
                      ),
                    ),
                  ),

                  if (fileUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),

                    Text(
                      'Link file',
                      style: theme.textTheme.labelLarge
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    SelectableText(
                      fileUrl,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(
                        color:
                        theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final title =
    (widget.assignmentData['title'] ??
        'Tanpa Judul')
        .toString();

    final courseTitle =
    (widget.assignmentData['courseTitle'] ??
        widget.assignmentData['courseName'] ??
        '')
        .toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hasil Pengumpulan',
        ),
      ),

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collectionGroup(
          'assignment_submissions',
        )
            .where(
          'assignmentId',
          isEqualTo: widget.assignmentId,
        )
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Gagal mengambil hasil tugas.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          }

          final docs =
              snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return _buildEmptyState(
              theme,
              title,
              courseTitle,
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  8,
                ),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color:
                  theme.colorScheme.primaryContainer,
                  borderRadius:
                  BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      size: 36,
                      color: theme
                          .colorScheme
                          .onPrimaryContainer,
                    ),

                    const SizedBox(width: 14),

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
                            style: theme.textTheme.titleMedium
                                ?.copyWith(
                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),

                          if (courseTitle.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              courseTitle,
                              style: theme
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: theme
                                    .colorScheme
                                    .onPrimaryContainer,
                              ),
                            ),
                          ],

                          const SizedBox(height: 8),

                          Text(
                            '${docs.length} siswa sudah mengumpulkan',
                            style: theme
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                              fontWeight:
                              FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView.separated(
                  padding:
                  const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    24,
                  ),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();

                    return _SubmissionCard(
                      data: data,
                      getStudent: _getStudent,
                      formatDate: _formatDate,
                      formatFileSize: _formatFileSize,
                      onTap: () {
                        _showSubmissionDetail(doc);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(
      ThemeData theme,
      String title,
      String courseTitle,
      ) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color:
                theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 52,
                color:
                theme.colorScheme.onPrimaryContainer,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Belum Ada Pengumpulan',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Belum ada siswa yang mengumpulkan '
                  'tugas "$title".',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),

            if (courseTitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                courseTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(
                  color:
                  theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubmissionCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final Future<Map<String, dynamic>?> Function(
      String studentId,
      ) getStudent;
  final String Function(dynamic value) formatDate;
  final String Function(dynamic value) formatFileSize;
  final VoidCallback onTap;

  const _SubmissionCard({
    required this.data,
    required this.getStudent,
    required this.formatDate,
    required this.formatFileSize,
    required this.onTap,
  });

  @override
  State<_SubmissionCard> createState() =>
      _SubmissionCardState();
}

class _SubmissionCardState
    extends State<_SubmissionCard> {
  String _name = 'Siswa';
  String _email = '';
  bool _loadingStudent = true;

  @override
  void initState() {
    super.initState();
    _loadStudent();
  }

  Future<void> _loadStudent() async {
    final studentId =
    (widget.data['studentId'] ?? '').toString();

    if (studentId.isEmpty) {
      if (!mounted) return;

      setState(() {
        _loadingStudent = false;
      });

      return;
    }

    final student =
    await widget.getStudent(studentId);

    if (!mounted) return;

    if (student != null) {
      final name = (
          student['name'] ??
              student['username'] ??
              student['displayName'] ??
              'Siswa'
      ).toString().trim();

      setState(() {
        _name = name.isEmpty ? 'Siswa' : name;
        _email =
            (student['email'] ?? '').toString();
        _loadingStudent = false;
      });
    } else {
      setState(() {
        _name = 'Siswa';
        _loadingStudent = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final fileName =
    (widget.data['fileName'] ??
        'File tugas')
        .toString();

    final status =
    (widget.data['status'] ??
        'Dikumpulkan')
        .toString();

    final submittedAt =
    widget.formatDate(
      widget.data['submittedAt'],
    );

    final fileSize =
    widget.formatFileSize(
      widget.data['fileSize'],
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor:
                theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.person,
                  color: theme
                      .colorScheme
                      .onPrimaryContainer,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    if (_loadingStudent)
                      const SizedBox(
                        height: 20,
                        width: 120,
                        child: LinearProgressIndicator(),
                      )
                    else
                      Text(
                        _name,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: theme
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                          fontWeight:
                          FontWeight.bold,
                        ),
                      ),

                    if (_email.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        _email,
                        maxLines: 1,
                        overflow:
                        TextOverflow.ellipsis,
                        style: theme
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                          color: theme
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),

                    Text(
                      fileName,
                      maxLines: 1,
                      overflow:
                      TextOverflow.ellipsis,
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _SmallInfoChip(
                          icon:
                          Icons.storage_outlined,
                          text: fileSize,
                        ),
                        _SmallInfoChip(
                          icon:
                          Icons.access_time_outlined,
                          text: submittedAt,
                        ),
                        _SmallInfoChip(
                          icon:
                          Icons.check_circle_outline,
                          text: status,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.chevron_right,
                color:
                theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
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
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 22,
          color: theme.colorScheme.primary,
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(
                  color:
                  theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                value,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SmallInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallInfoChip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: theme
            .colorScheme
            .surfaceContainerHighest,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color:
            theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}