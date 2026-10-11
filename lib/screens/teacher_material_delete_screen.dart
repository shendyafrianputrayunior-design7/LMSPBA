import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeacherMaterialDeleteScreen extends StatefulWidget {
  final String materialId;
  final String title;

  const TeacherMaterialDeleteScreen({
    super.key,
    required this.materialId,
    required this.title,
  });

  @override
  State<TeacherMaterialDeleteScreen> createState() =>
      _TeacherMaterialDeleteScreenState();
}

class _TeacherMaterialDeleteScreenState
    extends State<TeacherMaterialDeleteScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  bool _loading = false;

  // ============================================================
  // DELETE MATERIAL
  // ============================================================

  Future<void> _deleteMaterial() async {
    if (_loading) return;

    setState(() {
      _loading = true;
    });

    try {
      // ========================================================
      // MATERIAL REFERENCE
      // ========================================================

      final materialReference = _firestore
          .collection('materials')
          .doc(widget.materialId);

      // ========================================================
      // AMBIL DATA MATERIAL TERLEBIH DAHULU
      //
      // Tujuannya untuk mendapatkan courseLessonId.
      // ========================================================

      final materialSnapshot =
      await materialReference.get();

      if (!materialSnapshot.exists) {
        throw Exception(
          'Data materi tidak ditemukan.',
        );
      }

      final materialData =
          materialSnapshot.data() ?? {};

      final courseLessonId =
      (materialData['courseLessonId'] ?? '')
          .toString()
          .trim();

      // ========================================================
      // BATCH DELETE
      // ========================================================

      final batch =
      _firestore.batch();

      // Hapus material
      batch.delete(
        materialReference,
      );

      // ========================================================
      // HAPUS COURSE LESSON YANG TERHUBUNG
      //
      // Hanya dilakukan jika material memiliki
      // courseLessonId.
      // ========================================================

      if (courseLessonId.isNotEmpty) {
        final courseLessonReference =
        _firestore
            .collection('course_lessons')
            .doc(courseLessonId);

        batch.delete(
          courseLessonReference,
        );
      }

      // ========================================================
      // COMMIT
      // ========================================================

      await batch.commit();

      if (!mounted) return;

      Navigator.pop(
        context,
        true,
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menghapus materi:\n$e',
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
    final theme =
    Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hapus Materi',
          style: TextStyle(
            fontWeight:
            FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding:
        const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
          MainAxisAlignment.center,
          children: [
            // ==================================================
            // ICON
            // ==================================================

            Container(
              width: 90,
              height: 90,
              decoration:
              BoxDecoration(
                color: theme
                    .colorScheme
                    .errorContainer,
                shape:
                BoxShape.circle,
              ),
              child: Icon(
                Icons
                    .delete_outline,
                size: 44,
                color: theme
                    .colorScheme
                    .error,
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            // ==================================================
            // TITLE
            // ==================================================

            const Text(
              'Hapus Materi?',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            // ==================================================
            // DESCRIPTION
            // ==================================================

            Text(
              'Apakah Anda yakin ingin menghapus materi berikut?',
              textAlign:
              TextAlign.center,
              style: TextStyle(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // ==================================================
            // MATERIAL NAME
            // ==================================================

            Container(
              width:
              double.infinity,
              padding:
              const EdgeInsets.all(
                16,
              ),
              decoration:
              BoxDecoration(
                color: theme
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius:
                BorderRadius.circular(
                  14,
                ),
                border:
                Border.all(
                  color: theme
                      .colorScheme
                      .outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons
                        .menu_book_outlined,
                    color: theme
                        .colorScheme
                        .primary,
                  ),
                  const SizedBox(
                    width: 12,
                  ),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 3,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style:
                      const TextStyle(
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 16,
            ),

            // ==================================================
            // WARNING
            // ==================================================

            Container(
              width:
              double.infinity,
              padding:
              const EdgeInsets.all(
                14,
              ),
              decoration:
              BoxDecoration(
                color: theme
                    .colorScheme
                    .errorContainer,
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
                        .warning_amber_rounded,
                    color: theme
                        .colorScheme
                        .error,
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  Expanded(
                    child: Text(
                      'Materi yang dihapus tidak dapat dikembalikan. '
                          'Jika materi memiliki video Lesson yang terhubung, '
                          'Lesson tersebut juga akan dihapus.',
                      style: TextStyle(
                        color: theme
                            .colorScheme
                            .onErrorContainer,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: 28,
            ),

            // ==================================================
            // BUTTON
            // ==================================================

            Row(
              children: [
                Expanded(
                  child:
                  OutlinedButton(
                    onPressed:
                    _loading
                        ? null
                        : () {
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
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child:
                  FilledButton.icon(
                    style:
                    FilledButton.styleFrom(
                      backgroundColor:
                      theme
                          .colorScheme
                          .error,
                      foregroundColor:
                      theme
                          .colorScheme
                          .onError,
                    ),
                    onPressed:
                    _loading
                        ? null
                        : _deleteMaterial,
                    icon: _loading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                      CircularProgressIndicator(
                        strokeWidth:
                        2,
                      ),
                    )
                        : const Icon(
                      Icons
                          .delete_outline,
                    ),
                    label: Text(
                      _loading
                          ? 'Menghapus...'
                          : 'Hapus',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}