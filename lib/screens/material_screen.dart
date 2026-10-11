import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MaterialScreen extends StatefulWidget {
  const MaterialScreen({super.key});

  @override
  State<MaterialScreen> createState() => _MaterialScreenState();
}

class _MaterialScreenState extends State<MaterialScreen> {
  bool _loading = true;
  String? _errorMessage;

  String _classId = '';
  String _className = '';

  List<Map<String, dynamic>> _materials = [];

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  // =========================================================
  // LOAD MATERIALS
  // =========================================================

  Future<void> _loadMaterials() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('Akun siswa tidak ditemukan.');
      }

      // =====================================================
      // GET USER
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
      // GET CLASS
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
      // GET MATERIALS
      // =====================================================

      final snapshot = await FirebaseFirestore.instance
          .collection('materials')
          .where(
        'classId',
        isEqualTo: classId,
      )
          .get();

      final materials =
      <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // ===================================================
        // TEACHER
        // ===================================================

        String teacherName = 'Guru';

        final teacherId =
            data['teacherId']?.toString() ?? '';

        if (teacherId.isNotEmpty) {
          // -----------------------------------------------
          // PRIORITAS: teachers/{teacherId}
          // -----------------------------------------------

          final teacherDoc =
          await FirebaseFirestore.instance
              .collection('teachers')
              .doc(teacherId)
              .get();

          if (teacherDoc.exists) {
            final teacherData =
                teacherDoc.data() ??
                    <String, dynamic>{};

            final name =
            (teacherData['name'] ??
                teacherData['username'] ??
                teacherData['displayName'] ??
                '')
                .toString()
                .trim();

            if (name.isNotEmpty) {
              teacherName = name;
            }
          }

          // -----------------------------------------------
          // FALLBACK: teacherName dari material
          // -----------------------------------------------

          if (teacherName == 'Guru') {
            final materialTeacherName =
            (data['teacherName'] ?? '')
                .toString()
                .trim();

            if (materialTeacherName.isNotEmpty) {
              teacherName =
                  materialTeacherName;
            }
          }
        }

        // ===================================================
        // ATTACHMENT URL
        // ===================================================
        //
        // Data baru:
        // attachmentUrl
        //
        // Data lama:
        // fileUrl
        //
        // attachmentUrl menjadi prioritas.
        // ===================================================

        final attachmentUrl =
        (data['attachmentUrl'] ??
            data['fileUrl'] ??
            '')
            .toString()
            .trim();

        // ===================================================
        // VIDEO URL
        // ===================================================

        final videoUrl =
        (data['videoUrl'] ?? '')
            .toString()
            .trim();

        // ===================================================
        // COURSE
        // ===================================================

        final courseId =
        (data['courseId'] ?? '')
            .toString();

        final courseName =
        (data['courseName'] ?? '')
            .toString();

        // ===================================================
        // COURSE LESSON
        // ===================================================

        final courseLessonId =
        (data['courseLessonId'] ?? '')
            .toString();

        materials.add({
          'id': doc.id,

          'subject':
          data['subject']?.toString() ?? '-',

          'title':
          data['title']?.toString() ?? '-',

          'description':
          data['description']?.toString() ?? '-',

          'content':
          data['content']?.toString() ?? '',

          'type':
          data['type']?.toString() ?? 'Materi',

          // -----------------------------------------------
          // CANONICAL ATTACHMENT
          // -----------------------------------------------

          'attachmentUrl':
          attachmentUrl,

          // -----------------------------------------------
          // LEGACY FILE URL
          // -----------------------------------------------

          'fileUrl':
          data['fileUrl']?.toString() ?? '',

          // -----------------------------------------------
          // VIDEO
          // -----------------------------------------------

          'videoUrl':
          videoUrl,

          'videoFileName':
          data['videoFileName']?.toString() ?? '',

          'videoSize':
          data['videoSize'] ?? 0,

          // -----------------------------------------------
          // COURSE
          // -----------------------------------------------

          'courseId':
          courseId,

          'courseName':
          courseName,

          // -----------------------------------------------
          // COURSE LESSON
          // -----------------------------------------------

          'courseLessonId':
          courseLessonId,

          // -----------------------------------------------
          // TEACHER
          // -----------------------------------------------

          'teacher':
          teacherName,

          'teacherId':
          teacherId,
        });
      }

      // =====================================================
      // SORT MATERIAL
      // =====================================================

      materials.sort((a, b) {
        final titleA =
            a['title']?.toString().toLowerCase() ?? '';

        final titleB =
            b['title']?.toString().toLowerCase() ?? '';

        return titleA.compareTo(titleB);
      });

      // =====================================================
      // UPDATE STATE
      // =====================================================

      if (!mounted) return;

      setState(() {
        _classId = classId;
        _className = className;
        _materials = materials;
        _loading = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint(
        'Gagal mengambil materi: $e',
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
  // GET MATERIAL URL
  // =========================================================

  String _getMaterialUrl(
      Map<String, dynamic> material,
      ) {
    final attachmentUrl =
        material['attachmentUrl']
            ?.toString()
            .trim() ??
            '';

    if (attachmentUrl.isNotEmpty) {
      return attachmentUrl;
    }

    final fileUrl =
        material['fileUrl']
            ?.toString()
            .trim() ??
            '';

    if (fileUrl.isNotEmpty) {
      return fileUrl;
    }

    return '';
  }

  // =========================================================
  // GET VIDEO URL
  // =========================================================

  String _getVideoUrl(
      Map<String, dynamic> material,
      ) {
    return material['videoUrl']
        ?.toString()
        .trim() ??
        '';
  }

  // =========================================================
  // OPEN URL
  // =========================================================

  Future<void> _openUrl(
      String url,
      ) async {
    final cleanUrl = url.trim();

    if (cleanUrl.isEmpty) {
      _showMessage(
        'URL materi tidak tersedia.',
      );
      return;
    }

    Uri? uri;

    try {
      uri = Uri.parse(cleanUrl);
    } catch (_) {
      _showMessage(
        'URL materi tidak valid.',
      );
      return;
    }

    if (!uri.hasScheme) {
      _showMessage(
        'URL materi tidak valid.',
      );
      return;
    }

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        _showMessage(
          'Materi tidak dapat dibuka.',
        );
      }
    } catch (e) {
      debugPrint(
        'Gagal membuka URL: $e',
      );

      _showMessage(
        'Gagal membuka materi.',
      );
    }
  }

  // =========================================================
  // MESSAGE
  // =========================================================

  void _showMessage(
      String message,
      ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
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
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
        theme.scaffoldBackgroundColor,
        title: const Text(
          'Materials',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed:
            _loading ? null : _loadMaterials,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
            tooltip: 'Refresh',
          ),
        ],
      ),
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

    return RefreshIndicator(
      onRefresh: _loadMaterials,
      child: SingleChildScrollView(
        physics:
        const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding:
        const EdgeInsets.fromLTRB(
          20,
          8,
          20,
          30,
        ),
        child: Column(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // =================================================
            // HEADER
            // =================================================

            Text(
              'Materi Pembelajaran',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              _className.isNotEmpty
                  ? 'Materi pembelajaran untuk kelas $_className.'
                  : 'Pelajari materi pembelajaran dari guru.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                color:
                colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 20),

            // =================================================
            // SUMMARY
            // =================================================

            _buildSummaryCard(
              context,
              colorScheme,
            ),

            const SizedBox(height: 26),

            Text(
              'Daftar Materi',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 14),

            if (_materials.isEmpty)
              _buildEmptyState(context),

            ..._materials.map(
                  (material) =>
                  _buildMaterialCard(
                    context,
                    material,
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
    final theme = Theme.of(context);

    final pdfCount = _materials.where(
          (item) {
        return item['type']
            .toString()
            .toLowerCase() ==
            'pdf';
      },
    ).length;

    final videoCount = _materials.where(
          (item) {
        return item['type']
            .toString()
            .toLowerCase() ==
            'video';
      },
    ).length;

    final otherCount =
        _materials.length -
            pdfCount -
            videoCount;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius:
        BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            colorScheme.primary
                .withOpacity(0.78),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary
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
                      .withOpacity(0.16),
                  borderRadius:
                  BorderRadius.circular(
                      15),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      'Materi Tersedia',
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
                      '${_materials.length} materi pembelajaran',
                      style: theme
                          .textTheme
                          .bodySmall
                          ?.copyWith(
                        color: Colors
                            .white
                            .withOpacity(
                            0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child:
                _buildSummaryItem(
                  'Total',
                  _materials.length,
                ),
              ),
              Expanded(
                child:
                _buildSummaryItem(
                  'PDF',
                  pdfCount,
                ),
              ),
              Expanded(
                child:
                _buildSummaryItem(
                  'Video',
                  videoCount,
                ),
              ),
              Expanded(
                child:
                _buildSummaryItem(
                  'Lainnya',
                  otherCount,
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
      String label,
      int value,
      ) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight:
            FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
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
  // MATERIAL CARD
  // =========================================================

  Widget _buildMaterialCard(
      BuildContext context,
      Map<String, dynamic> material,
      ) {
    final theme =
    Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    final type =
        material['type']
            ?.toString() ??
            'Materi';

    final videoUrl =
    _getVideoUrl(material);

    final attachmentUrl =
    _getMaterialUrl(material);

    final hasVideo =
        videoUrl.isNotEmpty;

    final hasAttachment =
        attachmentUrl.isNotEmpty;

    return InkWell(
      borderRadius:
      BorderRadius.circular(20),
      onTap: () {
        _showMaterialDetail(
          context,
          material,
        );
      },
      child: Container(
        width: double.infinity,
        margin:
        const EdgeInsets.only(
            bottom: 14),
        padding:
        const EdgeInsets.all(16),
        decoration:
        BoxDecoration(
          color:
          colorScheme.surface,
          borderRadius:
          BorderRadius.circular(
              20),
          border: Border.all(
            color: colorScheme
                .outline
                .withOpacity(0.40),
          ),
        ),
        child: Row(
          crossAxisAlignment:
          CrossAxisAlignment.start,
          children: [
            // =================================================
            // ICON
            // =================================================

            Container(
              width: 54,
              height: 54,
              decoration:
              BoxDecoration(
                color: colorScheme
                    .primary
                    .withOpacity(0.10),
                borderRadius:
                BorderRadius.circular(
                    16),
              ),
              child: Icon(
                _getMaterialIcon(
                    type),
                color:
                colorScheme.primary,
                size: 27,
              ),
            ),

            const SizedBox(
                width: 13),

            // =================================================
            // CONTENT
            // =================================================

            Expanded(
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
                      Expanded(
                        child: Text(
                          material[
                          'title']
                              ?.toString() ??
                              '-',
                          maxLines: 2,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style: theme
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight:
                            FontWeight
                                .w800,
                          ),
                        ),
                      ),
                      const SizedBox(
                          width: 8),
                      Container(
                        padding:
                        const EdgeInsets
                            .symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration:
                        BoxDecoration(
                          color: colorScheme
                              .primary
                              .withOpacity(
                              0.10),
                          borderRadius:
                          BorderRadius
                              .circular(
                              8),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            color:
                            colorScheme
                                .primary,
                            fontSize: 10,
                            fontWeight:
                            FontWeight
                                .w800,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                      height: 7),

                  Text(
                    material['subject']
                        ?.toString() ??
                        '-',
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: colorScheme
                          .primary,
                      fontWeight:
                      FontWeight
                          .w700,
                    ),
                  ),

                  const SizedBox(
                      height: 5),

                  Text(
                    material[
                    'description']
                        ?.toString() ??
                        '-',
                    maxLines: 2,
                    overflow:
                    TextOverflow
                        .ellipsis,
                    style: theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color: colorScheme
                          .onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(
                      height: 10),

                  Row(
                    children: [
                      Icon(
                        Icons
                            .person_outline_rounded,
                        size: 15,
                        color: colorScheme
                            .onSurfaceVariant,
                      ),
                      const SizedBox(
                          width: 5),
                      Expanded(
                        child: Text(
                          material[
                          'teacher']
                              ?.toString() ??
                              'Guru',
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
                  // RESOURCE CHIPS
                  // =================================================

                  if (hasVideo ||
                      hasAttachment)
                    Padding(
                      padding:
                      const EdgeInsets
                          .only(
                        top: 10,
                      ),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (hasVideo)
                            _buildResourceChip(
                              context,
                              Icons
                                  .play_circle_outline,
                              'Video',
                            ),
                          if (hasAttachment)
                            _buildResourceChip(
                              context,
                              Icons
                                  .attach_file,
                              'Lampiran',
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(
                      height: 8),

                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .end,
                    children: [
                      Text(
                        'Lihat materi',
                        style: TextStyle(
                          color: colorScheme
                              .primary,
                          fontSize: 12,
                          fontWeight:
                          FontWeight
                              .w700,
                        ),
                      ),
                      const SizedBox(
                          width: 6),
                      Icon(
                        Icons
                            .arrow_forward_ios_rounded,
                        size: 14,
                        color: colorScheme
                            .primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // RESOURCE CHIP
  // =========================================================

  Widget _buildResourceChip(
      BuildContext context,
      IconData icon,
      String label,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      padding:
      const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration:
      BoxDecoration(
        color: colorScheme
            .surfaceContainerHighest,
        borderRadius:
        BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize:
        MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color:
            colorScheme.primary,
          ),
          const SizedBox(
              width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight:
              FontWeight.w700,
              color: colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MATERIAL DETAIL
  // =========================================================

  void _showMaterialDetail(
      BuildContext context,
      Map<String, dynamic> material,
      ) {
    final theme =
    Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    final attachmentUrl =
    _getMaterialUrl(material);

    final videoUrl =
    _getVideoUrl(material);

    final hasAttachment =
        attachmentUrl.isNotEmpty;

    final hasVideo =
        videoUrl.isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
      Colors.transparent,
      builder: (context) {
        return Container(
          decoration:
          BoxDecoration(
            color: theme
                .scaffoldBackgroundColor,
            borderRadius:
            const BorderRadius
                .vertical(
              top: Radius.circular(28),
            ),
          ),
          padding:
          const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            30,
          ),
          child: SafeArea(
            child:
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                children: [
                  // =================================================
                  // HANDLE
                  // =================================================

                  Center(
                    child:
                    Container(
                      width: 42,
                      height: 4,
                      decoration:
                      BoxDecoration(
                        color: colorScheme
                            .onSurface
                            .withOpacity(
                            0.20),
                        borderRadius:
                        BorderRadius
                            .circular(
                            20),
                      ),
                    ),
                  ),

                  const SizedBox(
                      height: 24),

                  // =================================================
                  // TITLE
                  // =================================================

                  Row(
                    crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration:
                        BoxDecoration(
                          color: colorScheme
                              .primary
                              .withOpacity(
                              0.10),
                          borderRadius:
                          BorderRadius
                              .circular(
                              17),
                        ),
                        child: Icon(
                          _getMaterialIcon(
                            material[
                            'type']
                                ?.toString() ??
                                '',
                          ),
                          color: colorScheme
                              .primary,
                          size: 29,
                        ),
                      ),
                      const SizedBox(
                          width: 14),
                      Expanded(
                        child:
                        Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [
                            Text(
                              material[
                              'title']
                                  ?.toString() ??
                                  '-',
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
                                height: 5),
                            Text(
                              material[
                              'subject']
                                  ?.toString() ??
                                  '-',
                              style:
                              TextStyle(
                                color: colorScheme
                                    .primary,
                                fontWeight:
                                FontWeight
                                    .w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                      height: 24),

                  // =================================================
                  // INFO
                  // =================================================

                  _buildDetailRow(
                    context,
                    Icons
                        .person_outline_rounded,
                    'Guru',
                    material[
                    'teacher']
                        ?.toString() ??
                        '-',
                  ),

                  const SizedBox(
                      height: 14),

                  _buildDetailRow(
                    context,
                    Icons
                        .category_outlined,
                    'Tipe',
                    material[
                    'type']
                        ?.toString() ??
                        '-',
                  ),

                  if ((material[
                  'courseName']
                      ?.toString()
                      .isNotEmpty ??
                      false)) ...[
                    const SizedBox(
                        height: 14),
                    _buildDetailRow(
                      context,
                      Icons
                          .menu_book_outlined,
                      'Course',
                      material[
                      'courseName']
                          ?.toString() ??
                          '-',
                    ),
                  ],

                  if (_className.isNotEmpty) ...[
                    const SizedBox(
                        height: 14),
                    _buildDetailRow(
                      context,
                      Icons
                          .groups_outlined,
                      'Kelas',
                      _className,
                    ),
                  ],

                  const SizedBox(
                      height: 22),

                  // =================================================
                  // DESCRIPTION
                  // =================================================

                  Text(
                    'Deskripsi',
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
                    material[
                    'description']
                        ?.toString() ??
                        '-',
                    style: theme
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                      height: 1.6,
                      color: colorScheme
                          .onSurfaceVariant,
                    ),
                  ),

                  // =================================================
                  // CONTENT
                  // =================================================

                  if ((material[
                  'content']
                      ?.toString()
                      .trim()
                      .isNotEmpty ??
                      false)) ...[
                    const SizedBox(
                        height: 24),
                    Text(
                      'Isi Materi',
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
                        height: 8),
                    Text(
                      material[
                      'content']
                          ?.toString() ??
                          '',
                      style: theme
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                        height: 1.6,
                      ),
                    ),
                  ],

                  const SizedBox(
                      height: 24),

                  // =================================================
                  // VIDEO
                  // =================================================

                  if (hasVideo)
                    SizedBox(
                      width:
                      double.infinity,
                      child:
                      FilledButton.icon(
                        onPressed: () {
                          _openUrl(
                              videoUrl);
                        },
                        icon:
                        const Icon(
                          Icons
                              .play_circle_fill,
                        ),
                        label:
                        const Text(
                          'Buka Video',
                        ),
                      ),
                    ),

                  // =================================================
                  // ATTACHMENT
                  // =================================================

                  if (hasAttachment) ...[
                    if (hasVideo)
                      const SizedBox(
                          height: 10),
                    SizedBox(
                      width:
                      double.infinity,
                      child:
                      OutlinedButton.icon(
                        onPressed: () {
                          _openUrl(
                              attachmentUrl);
                        },
                        icon:
                        const Icon(
                          Icons
                              .open_in_new_rounded,
                        ),
                        label:
                        const Text(
                          'Buka Materi',
                        ),
                      ),
                    ),
                  ],

                  // =================================================
                  // NO RESOURCE
                  // =================================================

                  if (!hasVideo &&
                      !hasAttachment)
                    Container(
                      width:
                      double.infinity,
                      padding:
                      const EdgeInsets
                          .all(14),
                      decoration:
                      BoxDecoration(
                        color: colorScheme
                            .surfaceContainerHighest,
                        borderRadius:
                        BorderRadius
                            .circular(
                            12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons
                                .info_outline,
                            color: colorScheme
                                .onSurfaceVariant,
                          ),
                          const SizedBox(
                              width: 10),
                          Expanded(
                            child: Text(
                              'Belum ada file atau URL lampiran untuk materi ini.',
                              style:
                              TextStyle(
                                color: colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================
  // DETAIL ROW
  // =========================================================

  Widget _buildDetailRow(
      BuildContext context,
      IconData icon,
      String label,
      String value,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 20,
          color:
          colorScheme.primary,
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              color: colorScheme
                  .onSurfaceVariant,
              fontSize: 13,
              fontWeight:
              FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight:
              FontWeight.w700,
            ),
          ),
        ),
      ],
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
            20),
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
                .menu_book_outlined,
            size: 52,
            color:
            colorScheme.primary,
          ),
          const SizedBox(
              height: 14),
          Text(
            'Belum Ada Materi',
            style: theme
                .textTheme
                .titleMedium
                ?.copyWith(
              fontWeight:
              FontWeight.w800,
            ),
          ),
          const SizedBox(
              height: 7),
          Text(
            'Belum ada materi pembelajaran yang tersedia untuk kelas kamu.',
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
        const EdgeInsets.all(
            24),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment
              .center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration:
              BoxDecoration(
                color: colorScheme
                    .error
                    .withOpacity(
                    0.10),
                borderRadius:
                BorderRadius
                    .circular(
                    20),
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
              'Gagal Memuat Materi',
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
              _loadMaterials,
              icon: const Icon(
                Icons
                    .refresh_rounded,
              ),
              label: const Text(
                'Coba Lagi',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // MATERIAL ICON
  // =========================================================

  IconData _getMaterialIcon(
      String type,
      ) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons
            .picture_as_pdf_rounded;

      case 'video':
        return Icons
            .play_circle_fill_rounded;

      case 'ppt':
      case 'powerpoint':
        return Icons
            .slideshow_rounded;

      case 'doc':
      case 'docx':
        return Icons
            .description_rounded;

      case 'link':
        return Icons.link_rounded;

      default:
        return Icons
            .menu_book_rounded;
    }
  }
}