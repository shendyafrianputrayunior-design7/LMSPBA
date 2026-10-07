import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/course.dart';

class LessonScreen extends StatefulWidget {
  const LessonScreen({super.key});

  @override
  State<LessonScreen> createState() => _LessonScreenState();
}

class _LessonScreenState extends State<LessonScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ===============================================================
  // PROGRESS
  // ===============================================================

  bool _completed = false;
  bool _loadingProgress = true;
  bool _savingProgress = false;

  // ===============================================================
  // VIDEO
  // ===============================================================

  VideoPlayerController? _videoController;

  bool _loadingVideo = false;
  String? _videoError;
  String? _currentVideoUrl;

  // ===============================================================
  // INIT
  // ===============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadLessonData();
    });
  }

  // ===============================================================
  // LOAD LESSON DATA
  // ===============================================================

  Future<void> _loadLessonData() async {
    if (!mounted) return;

    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is! Map) {
      if (!mounted) return;

      setState(() {
        _loadingProgress = false;
        _loadingVideo = false;
      });

      return;
    }

    final course = arguments['course'];
    final lesson = arguments['lesson'];

    if (course is! Course || lesson is! Map) {
      if (!mounted) return;

      setState(() {
        _loadingProgress = false;
        _loadingVideo = false;
      });

      return;
    }

    final lessonData = Map<String, dynamic>.from(lesson);

    await Future.wait([
      _loadProgress(
        course: course,
        lesson: lessonData,
      ),
      _loadVideo(
        lesson: lessonData,
      ),
    ]);
  }

  // ===============================================================
  // LOAD PROGRESS
  // ===============================================================

  Future<void> _loadProgress({
    required Course course,
    required Map<String, dynamic> lesson,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _loadingProgress = false;
      });

      return;
    }

    final lessonId = (lesson['id'] ?? '').toString();

    if (lessonId.isEmpty) {
      if (!mounted) return;

      setState(() {
        _loadingProgress = false;
      });

      return;
    }

    try {
      final progressSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('course_progress')
          .doc(course.id)
          .get();

      bool completed = false;

      if (progressSnapshot.exists) {
        final data = progressSnapshot.data();

        final completedLessons = data?['completedLessons'];

        if (completedLessons is List) {
          completed = completedLessons
              .map((item) => item.toString())
              .contains(lessonId);
        }
      }

      if (!mounted) return;

      setState(() {
        _completed = completed;
        _loadingProgress = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loadingProgress = false;
      });
    }
  }

  // ===============================================================
  // LOAD VIDEO
  // ===============================================================

  Future<void> _loadVideo({
    required Map<String, dynamic> lesson,
  }) async {
    final videoUrl = (lesson['videoUrl'] ?? '').toString().trim();

    // Tidak ada video
    if (videoUrl.isEmpty) {
      if (!mounted) return;

      setState(() {
        _loadingVideo = false;
        _videoError = null;
        _currentVideoUrl = null;
      });

      return;
    }

    if (!mounted) return;

    setState(() {
      _loadingVideo = true;
      _videoError = null;
      _currentVideoUrl = videoUrl;
    });

    try {
      // Hapus controller lama
      final oldController = _videoController;
      _videoController = null;

      if (oldController != null) {
        await oldController.dispose();
      }

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(videoUrl),
      );

      await controller.initialize();

      await controller.setLooping(false);

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _videoController = controller;
        _loadingVideo = false;
        _videoError = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingVideo = false;
        _videoError = 'Video tidak dapat diputar.';
      });
    }
  }

  // ===============================================================
  // RETRY VIDEO
  // ===============================================================

  Future<void> _retryVideo() async {
    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is! Map) return;

    final lesson = arguments['lesson'];

    if (lesson is! Map) return;

    await _loadVideo(
      lesson: Map<String, dynamic>.from(lesson),
    );
  }

  // ===============================================================
  // UPDATE PROGRESS
  // ===============================================================

  Future<void> _updateProgress({
    required Course course,
    required Map<String, dynamic> lesson,
    required bool completed,
  }) async {
    if (_savingProgress) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _showMessage('User belum login.');
      return;
    }

    final lessonId = (lesson['id'] ?? '').toString();

    if (lessonId.isEmpty) {
      _showMessage('ID lesson tidak ditemukan.');
      return;
    }

    if (!mounted) return;

    setState(() {
      _savingProgress = true;
    });

    try {
      final progressRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('course_progress')
          .doc(course.id);

      await progressRef.set(
        {
          'completedLessons': completed
              ? FieldValue.arrayUnion([lessonId])
              : FieldValue.arrayRemove([lessonId]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      if (!mounted) return;

      setState(() {
        _completed = completed;
        _savingProgress = false;
      });

      _showMessage(
        completed
            ? 'Lesson berhasil ditandai selesai.'
            : 'Lesson ditandai belum selesai.',
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _savingProgress = false;
      });

      _showMessage('Gagal menyimpan progress.');
    }
  }

  // ===============================================================
  // MESSAGE
  // ===============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ===============================================================
  // PLAY / PAUSE
  // ===============================================================

  Future<void> _toggleVideo() async {
    final controller = _videoController;

    if (controller == null) return;

    if (!controller.value.isInitialized) return;

    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }

      if (!mounted) return;

      setState(() {});
    } catch (_) {
      // Abaikan error play/pause
    }
  }

  // ===============================================================
  // FULLSCREEN
  // ===============================================================

  void _openFullscreenVideo() {
    final controller = _videoController;

    if (controller == null) return;

    if (!controller.value.isInitialized) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenVideoScreen(
          controller: controller,
          title: _getLessonTitle(),
        ),
      ),
    );
  }

  // ===============================================================
  // GET LESSON TITLE
  // ===============================================================

  String _getLessonTitle() {
    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is! Map) {
      return 'Video';
    }

    final lesson = arguments['lesson'];

    if (lesson is! Map) {
      return 'Video';
    }

    return (lesson['title'] ?? 'Video Lesson').toString();
  }

  // ===============================================================
  // FORMAT DURATION
  // ===============================================================

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  // ===============================================================
  // VIDEO SECTION
  // ===============================================================

  Widget _buildVideoSection({
    required ColorScheme colorScheme,
    required double height,
  }) {
    final controller = _videoController;

    // -------------------------------------------------------------
    // LOADING
    // -------------------------------------------------------------

    if (_loadingVideo) {
      return Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // -------------------------------------------------------------
    // ERROR
    // -------------------------------------------------------------

    if (_videoError != null) {
      return Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.video_library,
                  size: 48,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text(
                  'Video tidak dapat diputar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _videoError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _retryVideo,
                  icon: const Icon(
                    Icons.refresh_rounded,
                  ),
                  label: const Text(
                    'Coba Lagi',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // -------------------------------------------------------------
    // BELUM ADA VIDEO
    // -------------------------------------------------------------

    if (controller == null ||
        !controller.value.isInitialized) {
      return Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              colorScheme.primary.withOpacity(0.65),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.video_library,
                size: 52,
                color: Colors.white,
              ),
              SizedBox(height: 12),
              Text(
                'Video materi belum tersedia',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // -------------------------------------------------------------
    // VIDEO PLAYER
    // -------------------------------------------------------------

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        color: Colors.black,
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: height,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio:
                      controller.value.aspectRatio > 0
                          ? controller.value.aspectRatio
                          : 16 / 9,
                      child: VideoPlayer(
                        controller,
                      ),
                    ),
                  ),

                  // CENTER PLAY BUTTON
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: controller,
                    builder: (
                        context,
                        value,
                        child,
                        ) {
                      return IgnorePointer(
                        ignoring: value.isPlaying,
                        child: AnimatedOpacity(
                          duration: const Duration(
                            milliseconds: 200,
                          ),
                          opacity: value.isPlaying ? 0 : 1,
                          child: GestureDetector(
                            onTap: _toggleVideo,
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(
                                  0.55,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 44,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // FULLSCREEN BUTTON
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Material(
                      color: Colors.black.withOpacity(0.55),
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: _openFullscreenVideo,
                        icon: const Icon(
                          Icons.fullscreen_rounded,
                          color: Colors.white,
                        ),
                        tooltip: 'Fullscreen',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // -------------------------------------------------------
            // VIDEO CONTROLS
            // -------------------------------------------------------

            Container(
              color: Colors.black,
              padding: const EdgeInsets.fromLTRB(
                8,
                4,
                8,
                8,
              ),
              child: ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (
                    context,
                    value,
                    child,
                    ) {
                  return Column(
                    children: [
                      VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                        ),
                        colors: const VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _toggleVideo,
                            icon: Icon(
                              value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            _formatDuration(
                              value.position,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const Text(
                            ' / ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _formatDuration(
                              value.duration,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // DISPOSE
  // ===============================================================

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  // ===============================================================
  // BUILD
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;

    if (arguments is! Map) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Lesson'),
        ),
        body: const Center(
          child: Text(
            'Data lesson tidak ditemukan.',
          ),
        ),
      );
    }

    final course = arguments['course'];
    final lesson = arguments['lesson'];

    final lessonIndex = arguments['lessonIndex'] is int
        ? arguments['lessonIndex'] as int
        : 0;

    if (course is! Course || lesson is! Map) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Lesson'),
        ),
        body: const Center(
          child: Text(
            'Data lesson tidak valid.',
          ),
        ),
      );
    }

    final lessonData = Map<String, dynamic>.from(lesson);

    final title = (
        lessonData['title'] ??
            'Lesson ${lessonIndex + 1}'
    ).toString();

    final content = (
        lessonData['content'] ??
            'Belum ada content.'
    ).toString();

    final duration = int.tryParse(
      (lessonData['duration'] ?? 0).toString(),
    ) ??
        0;

    final videoUrl = (
        lessonData['videoUrl'] ??
            ''
    ).toString().trim();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final screenWidth = MediaQuery.sizeOf(context).width;

    final mediaHeight = (screenWidth * 0.52).clamp(
      190.0,
      360.0,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // ===========================================================
      // APP BAR
      // ===========================================================

      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              course.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),

      // ===========================================================
      // BODY
      // ===========================================================

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 720,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // VIDEO
                _buildVideoSection(
                  colorScheme: colorScheme,
                  height: mediaHeight,
                ),

                // VIDEO INFO
                if (videoUrl.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_done_outlined,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Video materi tersedia',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 24),

                // LESSON NUMBER + STATUS
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(
                          0.10,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Lesson ${lessonIndex + 1}',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),

                    const Spacer(),

                    if (_completed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(
                            0.12,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 17,
                              color: Colors.green,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Completed',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // TITLE
                Text(
                  title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),

                const SizedBox(height: 20),

                // LESSON INFO
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colorScheme.outline,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.school_rounded,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Course',
                                    style: textTheme.bodySmall?.copyWith(
                                      color:
                                      colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    course.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                    textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      Container(
                        width: 1,
                        height: 40,
                        color: colorScheme.outline,
                      ),

                      const SizedBox(width: 12),

                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            color: colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            duration > 0
                                ? '$duration min'
                                : '-',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // CONTENT TITLE
                Text(
                  'Lesson Content',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 10),

                // CONTENT
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colorScheme.outline,
                    ),
                  ),
                  child: Text(
                    content.isEmpty
                        ? 'Belum ada content.'
                        : content,
                    style: textTheme.bodyMedium?.copyWith(
                      height: 1.7,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // COMPLETE BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed:
                    _loadingProgress || _savingProgress
                        ? null
                        : () {
                      _updateProgress(
                        course: course,
                        lesson: lessonData,
                        completed: !_completed,
                      );
                    },
                    icon: _savingProgress
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Icon(
                      _completed
                          ? Icons.check_circle_rounded
                          : Icons.check_circle_outline_rounded,
                    ),
                    label: Text(
                      _completed
                          ? 'Mark Incomplete'
                          : 'Mark Complete',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                if (_loadingProgress) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Memuat progress...',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===================================================================
// FULLSCREEN VIDEO
// ===================================================================

class _FullscreenVideoScreen extends StatefulWidget {
  final VideoPlayerController controller;
  final String title;

  const _FullscreenVideoScreen({
    required this.controller,
    required this.title,
  });

  @override
  State<_FullscreenVideoScreen> createState() =>
      _FullscreenVideoScreenState();
}

class _FullscreenVideoScreenState
    extends State<_FullscreenVideoScreen> {
  VideoPlayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();

    controller.addListener(_videoListener);
  }

  @override
  void dispose() {
    controller.removeListener(_videoListener);

    super.dispose();
  }

  void _videoListener() {
    if (!mounted) return;

    setState(() {});
  }

  Future<void> _toggleVideo() async {
    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }

    if (!mounted) return;

    setState(() {});
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final value = controller.value;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: controller.value.aspectRatio > 0
                  ? controller.value.aspectRatio
                  : 16 / 9,
              child: VideoPlayer(controller),
            ),

            // PLAY BUTTON
            IgnorePointer(
              ignoring: value.isPlaying,
              child: AnimatedOpacity(
                duration: const Duration(
                  milliseconds: 200,
                ),
                opacity: value.isPlaying ? 0 : 1,
                child: GestureDetector(
                  onTap: _toggleVideo,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 46,
                    ),
                  ),
                ),
              ),
            ),

            // CONTROLS
            Positioned(
              left: 16,
              right: 16,
              bottom: 20,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                      ),
                      colors: const VideoProgressColors(
                        playedColor: Colors.white,
                        bufferedColor: Colors.white38,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: _toggleVideo,
                          icon: Icon(
                            value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _formatDuration(value.position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        const Text(
                          ' / ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _formatDuration(value.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}