import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  final String name;
  final String username;
  final String email;
  final String photoUrl;
  final String phone;
  final String gender;
  final String birthDate;
  final String address;
  final String school;
  final String className;
  final String major;
  final String nisn;
  final String bio;
  final File? profileImage;

  const EditProfileScreen({
    super.key,
    required this.name,
    required this.username,
    required this.email,
    required this.photoUrl,
    required this.phone,
    required this.gender,
    required this.birthDate,
    required this.address,
    required this.school,
    required this.className,
    required this.major,
    required this.nisn,
    required this.bio,
    this.profileImage,
  });

  @override
  State<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends State<EditProfileScreen> {
  final _formKey =
  GlobalKey<FormState>();

  late final TextEditingController
  _nameController;

  late final TextEditingController
  _usernameController;

  late final TextEditingController
  _emailController;

  late final TextEditingController
  _phoneController;

  late final TextEditingController
  _birthDateController;

  late final TextEditingController
  _addressController;

  late final TextEditingController
  _schoolController;

  late final TextEditingController
  _classController;

  late final TextEditingController
  _majorController;

  late final TextEditingController
  _nisnController;

  late final TextEditingController
  _bioController;

  String _gender = '';

  File? _profileImage;

  final ImagePicker _imagePicker =
  ImagePicker();

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(
          text: widget.name,
        );

    _usernameController =
        TextEditingController(
          text: widget.username,
        );

    _emailController =
        TextEditingController(
          text: widget.email,
        );

    _phoneController =
        TextEditingController(
          text: widget.phone,
        );

    _birthDateController =
        TextEditingController(
          text: widget.birthDate,
        );

    _addressController =
        TextEditingController(
          text: widget.address,
        );

    _schoolController =
        TextEditingController(
          text: widget.school,
        );

    _classController =
        TextEditingController(
          text: widget.className,
        );

    _majorController =
        TextEditingController(
          text: widget.major,
        );

    _nisnController =
        TextEditingController(
          text: widget.nisn,
        );

    _bioController =
        TextEditingController(
          text: widget.bio,
        );

    _gender = widget.gender;

    _profileImage =
        widget.profileImage;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _addressController.dispose();
    _schoolController.dispose();
    _classController.dispose();
    _majorController.dispose();
    _nisnController.dispose();
    _bioController.dispose();

    super.dispose();
  }

  // ===============================================================
  // PICK IMAGE
  // ===============================================================

  Future<void> _pickImage() async {
    final XFile? image =
    await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1000,
    );

    if (image == null) return;

    setState(() {
      _profileImage =
          File(image.path);
    });
  }

  // ===============================================================
  // DATE PICKER
  // ===============================================================

  Future<void> _pickBirthDate() async {
    DateTime initialDate =
    DateTime(2008);

    if (_birthDateController
        .text
        .isNotEmpty) {
      try {
        final parts =
        _birthDateController.text
            .split('-');

        if (parts.length == 3) {
          initialDate = DateTime(
            int.parse(parts[2]),
            int.parse(parts[1]),
            int.parse(parts[0]),
          );
        }
      } catch (_) {}
    }

    final picked =
    await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate:
      DateTime(1950),
      lastDate:
      DateTime.now(),
      helpText:
      'Pilih tanggal lahir',
    );

    if (picked == null) return;

    setState(() {
      _birthDateController.text =
      '${picked.day.toString().padLeft(2, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.year}';
    });
  }

  // ===============================================================
  // SAVE
  // ===============================================================

  void _saveProfile() {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    Navigator.pop(
      context,
      {
        'name':
        _nameController.text.trim(),

        'username':
        _usernameController.text
            .trim(),

        'phone':
        _phoneController.text
            .trim(),

        'gender':
        _gender,

        'birthDate':
        _birthDateController.text
            .trim(),

        'address':
        _addressController.text
            .trim(),

        'school':
        _schoolController.text
            .trim(),

        'className':
        _classController.text
            .trim(),

        'major':
        _majorController.text
            .trim(),

        'nisn':
        _nisnController.text
            .trim(),

        'bio':
        _bioController.text.trim(),

        'profileImage':
        _profileImage,
      },
    );
  }

  // ===============================================================
  // INPUT DECORATION
  // ===============================================================

  InputDecoration _decoration(
      BuildContext context,
      String label, {
        IconData? icon,
        String? hint,
        Widget? suffixIcon,
      }) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      hintText: hint,

      prefixIcon: icon == null
          ? null
          : Icon(icon),

      suffixIcon:
      suffixIcon,

      filled: true,

      fillColor:
      colorScheme.surface,

      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),

      border:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: BorderSide(
          color:
          colorScheme.outline,
        ),
      ),

      enabledBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: BorderSide(
          color:
          colorScheme.outline,
        ),
      ),

      focusedBorder:
      OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: BorderSide(
          color:
          colorScheme.primary,
          width: 1.5,
        ),
      ),
    );
  }

  // ===============================================================
  // SECTION TITLE
  // ===============================================================

  Widget _sectionTitle(
      BuildContext context,
      String title,
      String subtitle,
      ) {
    final theme =
    Theme.of(context);

    return Padding(
      padding:
      const EdgeInsets.only(
        top: 28,
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
            theme.textTheme
                .titleMedium
                ?.copyWith(
              fontWeight:
              FontWeight.w800,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            subtitle,
            style:
            theme.textTheme
                .bodySmall
                ?.copyWith(
              color: theme
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // ===============================================================
  // DEFAULT AVATAR
  // ===============================================================

  Widget _buildDefaultAvatar(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);

    final colorScheme =
        theme.colorScheme;

    final letter =
    _nameController.text
        .trim()
        .isNotEmpty
        ? _nameController.text
        .trim()[0]
        .toUpperCase()
        : 'U';

    return Container(
      width: 112,
      height: 112,
      decoration:
      BoxDecoration(
        shape:
        BoxShape.circle,
        gradient:
        LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
          begin:
          Alignment.topLeft,
          end:
          Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style:
          const TextStyle(
            color:
            Colors.white,
            fontSize: 42,
            fontWeight:
            FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ===============================================================
  // AVATAR
  // ===============================================================

  Widget _buildAvatar(
      BuildContext context,
      ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    // =============================================================
    // FOTO BARU DARI GALERI
    // =============================================================

    if (_profileImage != null) {
      return Container(
        width: 112,
        height: 112,
        decoration:
        BoxDecoration(
          shape:
          BoxShape.circle,
          border:
          Border.all(
            color:
            colorScheme.primary,
            width: 3,
          ),
        ),
        child: ClipOval(
          child: Image.file(
            _profileImage!,
            width: 112,
            height: 112,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // =============================================================
    // FOTO YANG SUDAH TERSIMPAN DI CLOUDINARY
    // =============================================================

    if (widget.photoUrl.isNotEmpty) {
      return Container(
        width: 112,
        height: 112,
        decoration:
        BoxDecoration(
          shape:
          BoxShape.circle,
          border:
          Border.all(
            color:
            colorScheme.primary,
            width: 3,
          ),
        ),
        child: ClipOval(
          child: Image.network(
            widget.photoUrl,
            width: 112,
            height: 112,
            fit: BoxFit.cover,
            errorBuilder:
                (
                context,
                error,
                stackTrace,
                ) {
              return _buildDefaultAvatar(
                context,
              );
            },
          ),
        ),
      );
    }

    // =============================================================
    // BELUM ADA FOTO
    // =============================================================

    return _buildDefaultAvatar(
      context,
    );
  }

  // ===============================================================
  // BUILD
  // ===============================================================

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
          'Edit Profile',
        ),
      ),

      body: Form(
        key: _formKey,

        child:
        SingleChildScrollView(
          physics:
          const BouncingScrollPhysics(),

          padding:
          const EdgeInsets.fromLTRB(
            20,
            20,
            20,
            40,
          ),

          child: Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [

              // =====================================================
              // PROFILE PHOTO
              // =====================================================

              Center(
                child: Column(
                  children: [
                    Stack(
                      clipBehavior:
                      Clip.none,
                      children: [
                        _buildAvatar(
                          context,
                        ),

                        Positioned(
                          right: 0,
                          bottom: 0,
                          child:
                          Material(
                            color:
                            colorScheme
                                .primary,
                            shape:
                            const CircleBorder(),
                            child:
                            InkWell(
                              onTap:
                              _pickImage,
                              customBorder:
                              const CircleBorder(),
                              child:
                              const Padding(
                                padding:
                                EdgeInsets.all(
                                  10,
                                ),
                                child:
                                Icon(
                                  Icons
                                      .camera_alt_rounded,
                                  color:
                                  Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    TextButton.icon(
                      onPressed:
                      _pickImage,
                      icon:
                      const Icon(
                        Icons
                            .photo_library_outlined,
                      ),
                      label:
                      const Text(
                        'Change Profile Photo',
                      ),
                    ),
                  ],
                ),
              ),

              // =====================================================
              // PERSONAL INFORMATION
              // =====================================================

              _sectionTitle(
                context,
                'Personal Information',
                'Manage your personal account information',
              ),

              TextFormField(
                controller:
                _nameController,
                textInputAction:
                TextInputAction.next,
                decoration:
                _decoration(
                  context,
                  'Full Name',
                  icon:
                  Icons
                      .person_outline_rounded,
                ),
                validator:
                    (value) {
                  if (value ==
                      null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Nama lengkap wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 14,
              ),

              TextFormField(
                controller:
                _usernameController,
                textInputAction:
                TextInputAction.next,
                decoration:
                _decoration(
                  context,
                  'Username',
                  icon:
                  Icons
                      .alternate_email_rounded,
                ),
                validator:
                    (value) {
                  if (value ==
                      null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Username wajib diisi';
                  }

                  return null;
                },
              ),

              const SizedBox(
                height: 14,
              ),

              // =====================================================
              // EMAIL LOCKED
              // =====================================================

              TextFormField(
                controller:
                _emailController,
                enabled: false,
                decoration:
                _decoration(
                  context,
                  'Email',
                  icon:
                  Icons
                      .email_outlined,
                  suffixIcon:
                  const Icon(
                    Icons
                        .lock_outline_rounded,
                  ),
                ),
              ),

              const SizedBox(
                height: 7,
              ),

              Row(
                children: [
                  Icon(
                    Icons
                        .info_outline_rounded,
                    size: 15,
                    color:
                    colorScheme.primary,
                  ),

                  const SizedBox(
                    width: 6,
                  ),

                  Text(
                    'Email tidak dapat diubah',
                    style:
                    theme
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                      color:
                      colorScheme.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 14,
              ),

              TextFormField(
                controller:
                _phoneController,
                keyboardType:
                TextInputType.phone,
                textInputAction:
                TextInputAction.next,
                decoration:
                _decoration(
                  context,
                  'Phone Number',
                  icon:
                  Icons
                      .phone_outlined,
                  hint:
                  '08xxxxxxxxxx',
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              DropdownButtonFormField<
                  String>(
                value: _gender.isEmpty
                    ? null
                    : _gender,
                decoration:
                _decoration(
                  context,
                  'Gender',
                  icon:
                  Icons.wc_outlined,
                ),
                items: const [
                  DropdownMenuItem(
                    value:
                    'Laki-laki',
                    child:
                    Text(
                      'Laki-laki',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                    'Perempuan',
                    child:
                    Text(
                      'Perempuan',
                    ),
                  ),
                ],
                onChanged:
                    (value) {
                  setState(() {
                    _gender =
                        value ?? '';
                  });
                },
              ),

              const SizedBox(
                height: 14,
              ),

              TextFormField(
                controller:
                _birthDateController,
                readOnly: true,
                onTap:
                _pickBirthDate,
                decoration:
                _decoration(
                  context,
                  'Date of Birth',
                  icon:
                  Icons
                      .calendar_today_outlined,
                  suffixIcon:
                  const Icon(
                    Icons
                        .keyboard_arrow_down_rounded,
                  ),
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              TextFormField(
                controller:
                _addressController,
                maxLines: 3,
                decoration:
                _decoration(
                  context,
                  'Address',
                  icon:
                  Icons
                      .location_on_outlined,
                  hint:
                  'Masukkan alamat lengkap',
                ),
              ),

              // =====================================================
              // EDUCATION
              // =====================================================

              _sectionTitle(
                context,
                'Education',
                'Information about your education',
              ),

              TextFormField(
                controller:
                _schoolController,
                textInputAction:
                TextInputAction.next,
                decoration:
                _decoration(
                  context,
                  'School',
                  icon:
                  Icons
                      .school_outlined,
                  hint:
                  'Nama sekolah',
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              TextFormField(
                controller:
                _classController,
                textInputAction:
                TextInputAction.next,
                decoration:
                _decoration(
                  context,
                  'Class',
                  icon:
                  Icons.class_outlined,
                  hint:
                  'Contoh: XII RPL 1',
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              TextFormField(
                controller:
                _majorController,
                textInputAction:
                TextInputAction.next,
                decoration:
                _decoration(
                  context,
                  'Major',
                  icon:
                  Icons
                      .menu_book_outlined,
                  hint:
                  'Contoh: Rekayasa Perangkat Lunak',
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              TextFormField(
                controller:
                _nisnController,
                keyboardType:
                TextInputType.number,
                decoration:
                _decoration(
                  context,
                  'NIS / NISN',
                  icon:
                  Icons
                      .badge_outlined,
                ),
              ),

              // =====================================================
              // ABOUT ME
              // =====================================================

              _sectionTitle(
                context,
                'About Me',
                'Tell something about yourself',
              ),

              TextFormField(
                controller:
                _bioController,
                maxLines: 5,
                maxLength: 250,
                decoration:
                _decoration(
                  context,
                  'Bio',
                  icon:
                  Icons
                      .description_outlined,
                  hint:
                  'Ceritakan sedikit tentang diri kamu...',
                ).copyWith(
                  alignLabelWithHint:
                  true,
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              // =====================================================
              // SAVE
              // =====================================================

              SizedBox(
                width:
                double.infinity,
                height: 54,
                child:
                ElevatedButton.icon(
                  onPressed:
                  _saveProfile,
                  icon:
                  const Icon(
                    Icons
                        .check_rounded,
                  ),
                  label:
                  const Text(
                    'Save Changes',
                    style:
                    TextStyle(
                      fontWeight:
                      FontWeight.w700,
                    ),
                  ),
                  style:
                  ElevatedButton.styleFrom(
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
      ),
    );
  }
}