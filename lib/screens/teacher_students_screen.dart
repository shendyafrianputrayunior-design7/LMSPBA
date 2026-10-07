import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class TeacherStudentsScreen extends StatefulWidget {
  const TeacherStudentsScreen({super.key});

  @override
  State<TeacherStudentsScreen> createState() =>
      _TeacherStudentsScreenState();
}

class _TeacherStudentsScreenState extends State<TeacherStudentsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _searchController =
  TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // GET STUDENTS
  // ============================================================

  Stream<QuerySnapshot<Map<String, dynamic>>> _studentsStream() {
    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .snapshots();
  }

  // ============================================================
  // FILTER STUDENTS
  // ============================================================

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterStudents(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> students,
      ) {
    if (_searchQuery.isEmpty) {
      return students;
    }

    return students.where((doc) {
      final data = doc.data();

      final name = (data['name'] ??
          data['username'] ??
          '')
          .toString()
          .toLowerCase();

      final username = (data['username'] ?? '')
          .toString()
          .toLowerCase();

      final email = (data['email'] ?? '')
          .toString()
          .toLowerCase();

      final classId = (data['classId'] ?? '')
          .toString()
          .toLowerCase();

      return name.contains(_searchQuery) ||
          username.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          classId.contains(_searchQuery);
    }).toList();
  }

  // ============================================================
  // OPEN STUDENT DETAIL
  // ============================================================

  void _openStudentDetail(
      String studentId,
      Map<String, dynamic> data,
      ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherStudentDetailScreen(
          studentId: studentId,
          studentData: data,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Students',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _studentsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _buildErrorState(
              theme,
              colorScheme,
              snapshot.error.toString(),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final students = snapshot.data?.docs ?? [];

          final filteredStudents = _filterStudents(students);

          return Column(
            children: [
              _buildHeader(
                theme,
                colorScheme,
                students.length,
              ),
              _buildSearchField(
                theme,
                colorScheme,
              ),
              Expanded(
                child: filteredStudents.isEmpty
                    ? _buildEmptyState(
                  theme,
                  colorScheme,
                )
                    : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    24,
                  ),
                  itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    final doc = filteredStudents[index];

                    return Padding(
                      padding: const EdgeInsets.only(
                        bottom: 10,
                      ),
                      child: _buildStudentCard(
                        theme,
                        colorScheme,
                        doc.id,
                        doc.data(),
                      ),
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

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(
      ThemeData theme,
      ColorScheme colorScheme,
      int totalStudents,
      ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        8,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(
            alpha: 0.08,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: colorScheme.primary.withValues(
              alpha: 0.12,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(
                  alpha: 0.12,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.groups_rounded,
                color: colorScheme.primary,
                size: 27,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daftar Siswa',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalStudents siswa terdaftar',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearchField(
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8,
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Cari nama, email, atau kelas...',
          prefixIcon: const Icon(
            Icons.search_rounded,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            onPressed: () {
              _searchController.clear();
            },
            icon: const Icon(
              Icons.clear_rounded,
            ),
          )
              : null,
          filled: true,
          fillColor: colorScheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // STUDENT CARD
  // ============================================================

  Widget _buildStudentCard(
      ThemeData theme,
      ColorScheme colorScheme,
      String studentId,
      Map<String, dynamic> data,
      ) {
    final name = (data['name'] ??
        data['username'] ??
        'Siswa')
        .toString();

    final username = (data['username'] ?? '')
        .toString();

    final email = (data['email'] ?? '')
        .toString();

    final classId = (data['classId'] ?? '')
        .toString();

    final className = (data['className'] ??
        classId)
        .toString();

    final photoUrl = (data['photoUrl'] ??
        data['photo'] ??
        '')
        .toString();

    final displayName = name.isNotEmpty
        ? name
        : username.isNotEmpty
        ? username
        : 'Siswa';

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          _openStudentDetail(
            studentId,
            data,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _buildAvatar(
                colorScheme,
                displayName,
                photoUrl,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (className.isNotEmpty)
                          _buildTag(
                            colorScheme,
                            Icons.class_outlined,
                            className,
                          ),
                        if (username.isNotEmpty)
                          _buildTag(
                            colorScheme,
                            Icons.alternate_email_rounded,
                            username,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _buildAvatar(
      ColorScheme colorScheme,
      String name,
      String photoUrl,
      ) {
    final initial = name.trim().isNotEmpty
        ? name.trim()[0].toUpperCase()
        : 'S';

    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 27,
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return CircleAvatar(
      radius: 27,
      backgroundColor: colorScheme.primary.withValues(
        alpha: 0.12,
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: colorScheme.primary,
          fontSize: 19,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // TAG
  // ============================================================

  Widget _buildTag(
      ColorScheme colorScheme,
      IconData icon,
      String text,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState(
      ThemeData theme,
      ColorScheme colorScheme,
      ) {
    final hasSearch = _searchQuery.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : Icons.groups_outlined,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(
                alpha: 0.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Siswa Tidak Ditemukan'
                  : 'Belum Ada Siswa',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              hasSearch
                  ? 'Tidak ada siswa yang sesuai dengan pencarian.'
                  : 'Belum ada data siswa yang terdaftar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState(
      ThemeData theme,
      ColorScheme colorScheme,
      String message,
      ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal Memuat Siswa',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// STUDENT DETAIL
// ================================================================

class TeacherStudentDetailScreen extends StatelessWidget {
  final String studentId;
  final Map<String, dynamic> studentData;

  const TeacherStudentDetailScreen({
    super.key,
    required this.studentId,
    required this.studentData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final name = (studentData['name'] ??
        studentData['username'] ??
        'Siswa')
        .toString();

    final username = (studentData['username'] ?? '')
        .toString();

    final email = (studentData['email'] ?? '')
        .toString();

    final classId = (studentData['classId'] ?? '')
        .toString();

    final className = (studentData['className'] ??
        classId)
        .toString();

    final phone = (studentData['phone'] ??
        studentData['phoneNumber'] ??
        '')
        .toString();

    final gender = (studentData['gender'] ?? '')
        .toString();

    final photoUrl = (studentData['photoUrl'] ??
        studentData['photo'] ??
        '')
        .toString();

    final displayName = name.isNotEmpty
        ? name
        : username.isNotEmpty
        ? username
        : 'Siswa';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Detail Siswa',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileHeader(
            theme,
            colorScheme,
            displayName,
            username,
            email,
            photoUrl,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            theme,
            colorScheme,
            className,
            email,
            username,
            phone,
            gender,
            studentId,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  Widget _buildProfileHeader(
      ThemeData theme,
      ColorScheme colorScheme,
      String name,
      String username,
      String email,
      String photoUrl,
      ) {
    final initial = name.trim().isNotEmpty
        ? name.trim()[0].toUpperCase()
        : 'S';

    Widget avatar;

    if (photoUrl.isNotEmpty) {
      avatar = CircleAvatar(
        radius: 42,
        backgroundImage: NetworkImage(photoUrl),
      );
    } else {
      avatar = CircleAvatar(
        radius: 42,
        backgroundColor: colorScheme.primary.withValues(
          alpha: 0.12,
        ),
        child: Text(
          initial,
          style: TextStyle(
            color: colorScheme.primary,
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(
          alpha: 0.08,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          avatar,
          const SizedBox(height: 14),
          Text(
            name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (username.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '@$username',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              email,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // INFO
  // ============================================================

  Widget _buildInfoCard(
      ThemeData theme,
      ColorScheme colorScheme,
      String className,
      String email,
      String username,
      String phone,
      String gender,
      String studentId,
      ) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Informasi Siswa',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _buildInfoRow(
              colorScheme,
              Icons.class_outlined,
              'Kelas',
              className.isEmpty ? '-' : className,
            ),
            _buildInfoRow(
              colorScheme,
              Icons.email_outlined,
              'Email',
              email.isEmpty ? '-' : email,
            ),
            _buildInfoRow(
              colorScheme,
              Icons.alternate_email_rounded,
              'Username',
              username.isEmpty ? '-' : username,
            ),
            _buildInfoRow(
              colorScheme,
              Icons.phone_outlined,
              'No. Telepon',
              phone.isEmpty ? '-' : phone,
            ),
            _buildInfoRow(
              colorScheme,
              Icons.person_outline_rounded,
              'Jenis Kelamin',
              gender.isEmpty ? '-' : gender,
            ),
            _buildInfoRow(
              colorScheme,
              Icons.fingerprint_rounded,
              'Student ID',
              studentId,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
      ColorScheme colorScheme,
      IconData icon,
      String label,
      String value,
      ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 95,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}