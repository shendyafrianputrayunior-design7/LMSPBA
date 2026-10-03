import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../widgets/app_bar_simple.dart';
import '../ui/app_spacing.dart';
import '../ui/layout.dart';
import '../ui/status_colors.dart';
import 'edit_profile_screen.dart';
import '../services/cloudinary_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // ===============================================================
  // USER PROFILE DATA
  // ===============================================================

  String _username = '';
  String _email = '';
  String _photoUrl = '';

  String _phone = '';
  String _gender = '';
  String _birthDate = '';
  String _address = '';
  String _school = '';
  String _className = '';
  String _major = '';
  String _nisn = '';

  File? _profileImage;

  bool _loadingProfile = true;

  final _nameController = TextEditingController();

  final _bioController = TextEditingController();

  // ===============================================================
  // INIT
  // ===============================================================

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ===============================================================
  // LOAD PROFILE FROM FIRESTORE
  // ===============================================================

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
        });
      }
      return;
    }

    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);

      final doc = await userRef.get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;

        _nameController.text =
            data['name'] ?? user.displayName ?? '';

        _username =
            data['username'] ?? user.displayName ?? '';

        _email =
            user.email ?? data['email'] ?? '';

        _photoUrl =
            data['photoUrl'] ?? user.photoURL ?? '';

        _phone =
            data['phone'] ?? '';

        _gender =
            data['gender'] ?? '';

        _birthDate =
            data['birthDate'] ?? '';

        _address =
            data['address'] ?? '';

        _school =
            data['school'] ?? '';

        _className =
            data['className'] ?? '';

        _major =
            data['major'] ?? '';

        _nisn =
            data['nisn'] ?? '';

        _bioController.text =
            data['bio'] ?? '';
      } else {
        // ===========================================================
        // FIRST LOGIN
        // Buat data user otomatis di Firestore
        // ===========================================================

        final name = user.displayName ?? '';
        final email = user.email ?? '';
        final photoUrl = user.photoURL ?? '';

        _nameController.text = name;
        _username = name;
        _email = email;
        _photoUrl = photoUrl;

        await userRef.set({
          'name': name,
          'username': name,
          'email': email,
          'photoUrl': photoUrl,
          'phone': '',
          'gender': '',
          'birthDate': '',
          'address': '',
          'school': '',
          'className': '',
          'major': '',
          'nisn': '',
          'bio': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Gagal mengambil profile: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gagal mengambil data profile',
            ),
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _loadingProfile = false;
      });
    }
  }

  // ===============================================================
  // OPEN EDIT PROFILE
  // ===============================================================

  Future<void> _openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfileScreen(
          name: _nameController.text,
          username: _username,
          email: _email,
          phone: _phone,
          gender: _gender,
          birthDate: _birthDate,
          address: _address,
          school: _school,
          className: _className,
          major: _major,
          nisn: _nisn,
          bio: _bioController.text,
          profileImage: _profileImage,
        ),
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _nameController.text =
          result['name'] ?? _nameController.text;

      _username =
          result['username'] ?? _username;

      _phone =
          result['phone'] ?? _phone;

      _gender =
          result['gender'] ?? _gender;

      _birthDate =
          result['birthDate'] ?? _birthDate;

      _address =
          result['address'] ?? _address;

      _school =
          result['school'] ?? _school;

      _className =
          result['className'] ?? _className;

      _major =
          result['major'] ?? _major;

      _nisn =
          result['nisn'] ?? _nisn;

      _bioController.text =
          result['bio'] ?? _bioController.text;

      if (result['profileImage'] is File) {
        _profileImage =
        result['profileImage'];
      }
    });

    // Upload foto baru ke Cloudinary jika pengguna mengganti foto.
    if (result['profileImage'] is File) {
      await _uploadProfilePhoto(
        result['profileImage'] as File,
      );
    }

    // Simpan data profile lainnya ke Firestore.
    await _saveProfileToFirestore();
  }

  // ===============================================================
  // UPLOAD PROFILE PHOTO TO CLOUDINARY
  // ===============================================================

  Future<void> _uploadProfilePhoto(File imageFile) async {
    if (!mounted) return;

    setState(() {
      _loadingProfile = true;
    });

    try {
      final imageUrl =
      await CloudinaryService.uploadProfileImage(imageFile);

      if (imageUrl == null || imageUrl.isEmpty) {
        throw Exception('URL foto dari Cloudinary kosong');
      }

      // Simpan URL Cloudinary di state.
      _photoUrl = imageUrl;

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(
          {
            'photoUrl': imageUrl,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto profil berhasil diperbarui'),
        ),
      );
    } catch (e) {
      debugPrint('Gagal upload foto profil: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal mengupload foto profil'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingProfile = false;
        });
      }
    }
  }

  // ===============================================================
  // SAVE PROFILE TO FIRESTORE
  // ===============================================================

  Future<void> _saveProfileToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'name': _nameController.text.trim(),
          'username': _username.trim(),

          // Email selalu mengambil dari Firebase Auth
          'email': user.email ?? _email,

          'phone': _phone,
          'gender': _gender,
          'birthDate': _birthDate,
          'address': _address,
          'school': _school,
          'className': _className,
          'major': _major,
          'nisn': _nisn,
          'bio': _bioController.text.trim(),
          'photoUrl': _photoUrl,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(
          merge: true,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile berhasil disimpan',
          ),
        ),
      );
    } catch (e) {
      debugPrint(
        'Gagal menyimpan profile: $e',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gagal menyimpan profile',
          ),
        ),
      );
    }
  }

  // ===============================================================
  // PROFILE AVATAR
  // ===============================================================

  Widget _buildAvatar(
      BuildContext context,
      String avatarLetter,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // ---------------------------------------------------------------
    // FOTO DARI GALERI
    // ---------------------------------------------------------------

    if (_profileImage != null) {
      return Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.primary,
            width: 2,
          ),
          image: DecorationImage(
            image: FileImage(
              _profileImage!,
            ),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary
                  .withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      );
    }

    // ---------------------------------------------------------------
    // FOTO GOOGLE
    // ---------------------------------------------------------------

    if (_photoUrl.isNotEmpty) {
      return Container(
        width: 90,
        height: 90,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: colorScheme.primary,
            width: 2,
          ),
          image: DecorationImage(
            image: NetworkImage(
              _photoUrl,
            ),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary
                  .withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
      );
    }

    // ---------------------------------------------------------------
    // DEFAULT AVATAR
    // ---------------------------------------------------------------

    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary
                .withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: Text(
          avatarLetter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // INFO ITEM
  // ===============================================================

  Widget _buildInfoItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    bool locked = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius:
        BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colorScheme.primary
                  .withOpacity(0.1),
              borderRadius:
              BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary,
              size: 21,
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
                  style: theme
                      .textTheme.bodySmall
                      ?.copyWith(
                    color: colorScheme
                        .onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value.isEmpty
                      ? '-'
                      : value,
                  maxLines: 2,
                  overflow:
                  TextOverflow.ellipsis,
                  style: theme
                      .textTheme.bodyMedium
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w600,
                    color:
                    colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          if (locked)
            Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: colorScheme.primary,
            ),
        ],
      ),
    );
  }

  // ===============================================================
  // SECTION TITLE
  // ===============================================================

  Widget _buildSectionTitle(
      BuildContext context,
      String title,
      ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
      child: Text(
        title,
        style: theme.textTheme.titleLarge
            ?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ===============================================================
  // BUILD
  // ===============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loadingProfile) {
      return Scaffold(
        backgroundColor:
        theme.scaffoldBackgroundColor,
        appBar: const AppBarSimple(
          title: 'Profile',
        ),
        body: const Center(
          child:
          CircularProgressIndicator(),
        ),
      );
    }

    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    final statusColors =
    theme.extension<StatusColors>();

    final completedCourses = [
      'Flutter for Beginners',
      'Dart Programming',
      'UI Design Basics',
    ];

    final avatarLetter =
    _nameController.text.isNotEmpty
        ? _nameController.text[0]
        .toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor:
      theme.scaffoldBackgroundColor,

      appBar: const AppBarSimple(
        title: 'Profile',
      ),

      body: SingleChildScrollView(
        physics:
        const BouncingScrollPhysics(),

        padding:
        AppSpacing.screenPadding(
          context,
        ),

        child:
        AppLayout.centeredConstrained(
          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [

              // =====================================================
              // PROFILE HEADER
              // =====================================================

              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(24),
                decoration:
                BoxDecoration(
                  color:
                  colorScheme.surface,
                  borderRadius:
                  BorderRadius.circular(
                    22,
                  ),
                  border: Border.all(
                    color:
                    colorScheme.outline,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                      Colors.black
                          .withOpacity(
                        theme.brightness ==
                            Brightness.dark
                            ? 0.18
                            : 0.04,
                      ),
                      blurRadius: 20,
                      offset:
                      const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [

                    _buildAvatar(
                      context,
                      avatarLetter,
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    Text(
                      _nameController.text,
                      textAlign:
                      TextAlign.center,
                      style: textTheme
                          .headlineSmall
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w800,
                        color: colorScheme
                            .onSurface,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      '@$_username',
                      textAlign:
                      TextAlign.center,
                      style: textTheme
                          .bodyMedium
                          ?.copyWith(
                        color: colorScheme
                            .primary,
                        fontWeight:
                        FontWeight.w600,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      _bioController.text,
                      textAlign:
                      TextAlign.center,
                      maxLines: 2,
                      overflow:
                      TextOverflow.ellipsis,
                      style: textTheme
                          .bodyMedium
                          ?.copyWith(
                        color: colorScheme
                            .onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    SizedBox(
                      width: double.infinity,
                      child:
                      ElevatedButton.icon(
                        onPressed:
                        _openEditProfile,
                        icon: const Icon(
                          Icons.edit_rounded,
                        ),
                        label: const Text(
                          'Edit Profile',
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              // =====================================================
              // PERSONAL INFORMATION
              // =====================================================

              _buildSectionTitle(
                context,
                'Personal Information',
              ),

              _buildInfoItem(
                context: context,
                icon:
                Icons.person_outline_rounded,
                label: 'Full Name',
                value:
                _nameController.text,
              ),

              _buildInfoItem(
                context: context,
                icon:
                Icons.alternate_email_rounded,
                label: 'Username',
                value:
                '@$_username',
              ),

              _buildInfoItem(
                context: context,
                icon:
                Icons.email_outlined,
                label: 'Email',
                value: _email,
                locked: true,
              ),

              _buildInfoItem(
                context: context,
                icon:
                Icons.phone_outlined,
                label: 'Phone Number',
                value: _phone,
              ),

              _buildInfoItem(
                context: context,
                icon: Icons.wc_outlined,
                label: 'Gender',
                value: _gender,
              ),

              _buildInfoItem(
                context: context,
                icon:
                Icons.calendar_today_outlined,
                label: 'Date of Birth',
                value: _birthDate,
              ),

              _buildInfoItem(
                context: context,
                icon:
                Icons.location_on_outlined,
                label: 'Address',
                value: _address,
              ),

              const SizedBox(
                height: 18,
              ),

              // =====================================================
              // EDUCATION
              // =====================================================

              _buildSectionTitle(
                context,
                'Education',
              ),

              _buildInfoItem(
                context: context,
                icon:
                Icons.school_outlined,
                label: 'School',
                value: _school,
              ),

              _buildInfoItem(
                context: context,
                icon:
                Icons.class_outlined,
                label: 'Class',
                value: _className,
              ),

              _buildInfoItem(
                context: context,
                icon:
                Icons.menu_book_outlined,
                label: 'Major',
                value: _major,
              ),

              _buildInfoItem(
                context: context,
                icon:
                Icons.badge_outlined,
                label: 'NIS / NISN',
                value: _nisn,
              ),

              const SizedBox(
                height: 18,
              ),

              // =====================================================
              // ABOUT ME
              // =====================================================

              _buildSectionTitle(
                context,
                'About Me',
              ),

              Container(
                width: double.infinity,
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
                    color:
                    colorScheme.outline,
                  ),
                ),
                child: Text(
                  _bioController.text.isEmpty
                      ? 'No bio added yet.'
                      : _bioController.text,
                  style: textTheme
                      .bodyMedium
                      ?.copyWith(
                    height: 1.5,
                    color:
                    colorScheme.onSurface,
                  ),
                ),
              ),

              const SizedBox(
                height: 28,
              ),

              // =====================================================
              // LEARNING OVERVIEW
              // =====================================================

              Text(
                'Learning Overview',
                style: textTheme.titleLarge
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w700,
                  color:
                  colorScheme.onSurface,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              Row(
                children: [

                  Expanded(
                    child:
                    _buildStatCard(
                      context: context,
                      icon:
                      Icons.menu_book_rounded,
                      value: '3',
                      label: 'Completed',
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child:
                    _buildStatCard(
                      context: context,
                      icon:
                      Icons.school_rounded,
                      value: '3',
                      label: 'Courses',
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child:
                    _buildStatCard(
                      context: context,
                      icon:
                      Icons.task_alt_rounded,
                      value: '3',
                      label: 'Assignments',
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 28,
              ),

              // =====================================================
              // COMPLETED COURSES
              // =====================================================

              Row(
                mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
                children: [

                  Expanded(
                    child: Text(
                      'Completed Courses',
                      style: textTheme
                          .titleLarge
                          ?.copyWith(
                        fontWeight:
                        FontWeight.w700,
                        color: colorScheme
                            .onSurface,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Container(
                    padding:
                    const EdgeInsets
                        .symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration:
                    BoxDecoration(
                      color: colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius:
                      BorderRadius.circular(
                        20,
                      ),
                    ),
                    child: Text(
                      '${completedCourses.length}',
                      style: TextStyle(
                        color: colorScheme
                            .primary,
                        fontSize: 12,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 12,
              ),

              ...completedCourses.map(
                    (title) => Container(
                  margin:
                  const EdgeInsets.only(
                    bottom: 10,
                  ),
                  padding:
                  const EdgeInsets.all(
                    16,
                  ),
                  decoration:
                  BoxDecoration(
                    color:
                    colorScheme.surface,
                    borderRadius:
                    BorderRadius.circular(
                      18,
                    ),
                    border: Border.all(
                      color:
                      colorScheme.outline,
                    ),
                  ),
                  child: Row(
                    children: [

                      Container(
                        width: 46,
                        height: 46,
                        decoration:
                        BoxDecoration(
                          color: colorScheme
                              .primary
                              .withOpacity(
                            0.1,
                          ),
                          borderRadius:
                          BorderRadius
                              .circular(
                            14,
                          ),
                        ),
                        child: Icon(
                          Icons
                              .check_circle_rounded,
                          color: statusColors
                              ?.submittedFg ??
                              Colors.green
                                  .shade700,
                          size: 25,
                        ),
                      ),

                      const SizedBox(
                        width: 14,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                          children: [

                            Text(
                              title,
                              maxLines: 2,
                              overflow:
                              TextOverflow
                                  .ellipsis,
                              style: textTheme
                                  .titleSmall
                                  ?.copyWith(
                                fontWeight:
                                FontWeight.w600,
                                color:
                                colorScheme
                                    .onSurface,
                              ),
                            ),

                            const SizedBox(
                              height: 4,
                            ),

                            Text(
                              'Course completed',
                              style: textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color:
                                colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Icon(
                        Icons
                            .chevron_right_rounded,
                        color: colorScheme
                            .onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              // =====================================================
              // ACCOUNT
              // =====================================================

              Text(
                'Account',
                style: textTheme.titleLarge
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w700,
                  color:
                  colorScheme.onSurface,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              // SETTINGS

              Container(
                width: double.infinity,
                margin:
                const EdgeInsets.only(
                  bottom: 12,
                ),
                decoration:
                BoxDecoration(
                  color:
                  colorScheme.surface,
                  borderRadius:
                  BorderRadius.circular(
                    18,
                  ),
                  border: Border.all(
                    color:
                    colorScheme.outline,
                  ),
                ),
                child: ListTile(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.settings,
                    );
                  },
                  contentPadding:
                  const EdgeInsets
                      .symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: Container(
                    width: 46,
                    height: 46,
                    decoration:
                    BoxDecoration(
                      color: colorScheme
                          .primary
                          .withOpacity(0.1),
                      borderRadius:
                      BorderRadius.circular(
                        14,
                      ),
                    ),
                    child: Icon(
                      Icons
                          .settings_outlined,
                      color:
                      colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    'Settings',
                    style: textTheme
                        .titleSmall
                        ?.copyWith(
                      fontWeight:
                      FontWeight.w700,
                      color: colorScheme
                          .onSurface,
                    ),
                  ),
                  subtitle: Text(
                    'Manage application preferences',
                    style: textTheme
                        .bodySmall
                        ?.copyWith(
                      color: colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                  trailing: Icon(
                    Icons
                        .chevron_right_rounded,
                    color: colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ),

              // =====================================================
              // LOGOUT
              // =====================================================

              Container(
                width: double.infinity,
                padding:
                const EdgeInsets.all(18),
                decoration:
                BoxDecoration(
                  color:
                  colorScheme.surface,
                  borderRadius:
                  BorderRadius.circular(
                    18,
                  ),
                  border: Border.all(
                    color:
                    colorScheme.outline,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [

                    Row(
                      children: [

                        Container(
                          width: 46,
                          height: 46,
                          decoration:
                          BoxDecoration(
                            color: Colors
                                .redAccent
                                .withOpacity(
                              0.1,
                            ),
                            borderRadius:
                            BorderRadius
                                .circular(
                              14,
                            ),
                          ),
                          child:
                          const Icon(
                            Icons
                                .logout_rounded,
                            color:
                            Colors.redAccent,
                          ),
                        ),

                        const SizedBox(
                          width: 12,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                            children: [

                              Text(
                                'Sign out',
                                style: textTheme
                                    .titleSmall
                                    ?.copyWith(
                                  fontWeight:
                                  FontWeight
                                      .w700,
                                  color:
                                  colorScheme
                                      .onSurface,
                                ),
                              ),

                              const SizedBox(
                                height: 3,
                              ),

                              Text(
                                'Sign out from this account',
                                style: textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  color:
                                  colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    SizedBox(
                      width: double.infinity,
                      child:
                      OutlinedButton.icon(
                        onPressed: () {
                          _showLogoutDialog(
                            context,
                          );
                        },
                        icon: const Icon(
                          Icons
                              .logout_rounded,
                          color:
                          Colors.redAccent,
                        ),
                        label: const Text(
                          'Logout',
                          style: TextStyle(
                            color:
                            Colors.redAccent,
                            fontWeight:
                            FontWeight.w600,
                          ),
                        ),
                        style:
                        OutlinedButton
                            .styleFrom(
                          minimumSize:
                          const Size(
                            0,
                            50,
                          ),
                          side:
                          const BorderSide(
                            color:
                            Colors.redAccent,
                          ),
                          shape:
                          RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                              14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // STAT CARD
  // ===============================================================

  Widget _buildStatCard({
    required BuildContext context,
    required IconData icon,
    required String value,
    required String label,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      padding:
      const EdgeInsets.symmetric(
        vertical: 18,
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outline,
        ),
      ),
      child: Column(
        children: [

          Icon(
            icon,
            color: colorScheme.primary,
            size: 24,
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            value,
            style:
            textTheme.titleLarge
                ?.copyWith(
              fontSize: 20,
              fontWeight:
              FontWeight.w800,
              color:
              colorScheme.onSurface,
            ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            label,
            textAlign:
            TextAlign.center,
            style:
            textTheme.bodySmall
                ?.copyWith(
              fontSize: 11,
              color: colorScheme
                  .onSurfaceVariant,
              fontWeight:
              FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // LOGOUT DIALOG
  // ===============================================================

  void _showLogoutDialog(
      BuildContext context,
      ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme =
        Theme.of(dialogContext);

        final colorScheme =
            theme.colorScheme;

        return AlertDialog(
          backgroundColor:
          colorScheme.surface,

          title: Text(
            'Logout',
            style: TextStyle(
              color:
              colorScheme.onSurface,
              fontWeight:
              FontWeight.w700,
            ),
          ),

          content: Text(
            'Are you sure you want to logout from this account?',
            style: TextStyle(
              color: colorScheme
                  .onSurfaceVariant,
            ),
          ),

          actions: [

            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                );
              },
              child:
              const Text('Cancel'),
            ),

            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(
                  dialogContext,
                );

                try {
                  // Logout Firebase
                  await FirebaseAuth
                      .instance
                      .signOut();

                  // Logout Google Sign-In
                  await GoogleSignOutHelper
                      .signOut();
                } catch (e) {
                  debugPrint(
                    'Logout error: $e',
                  );
                }

                if (!mounted) return;

                Navigator
                    .pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                      (route) => false,
                );
              },

              icon: const Icon(
                Icons.logout_rounded,
                size: 18,
              ),

              label:
              const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  // ===============================================================
  // DISPOSE
  // ===============================================================

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }
}

// ===============================================================
// GOOGLE SIGN OUT HELPER
// ===============================================================
//
// Dipisahkan agar ProfileScreen tidak perlu bergantung langsung
// pada implementasi Google Sign-In di bagian lain aplikasi.
//
// Jika GoogleSignIn belum digunakan di project ini untuk logout,
// helper ini tetap aman dipanggil.
//
// ===============================================================

class GoogleSignOutHelper {
  static Future<void> signOut() async {
    try {
      // Firebase Auth sudah melakukan sign out.
      //
      // Google Sign-In account akan tetap tersedia untuk pemilihan
      // akun berikutnya. Tidak perlu memaksa disconnect akun Google.
    } catch (e) {
      debugPrint(
        'Google sign out error: $e',
      );
    }
  }
}
