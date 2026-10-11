import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Membuat akun Guru dan Siswa tanpa mengganti sesi login Admin.
///
/// Catatan:
/// - Firebase Authentication sekunder digunakan untuk membuat akun.
/// - FirebaseFirestore.instance tetap menggunakan sesi utama Admin.
/// - Password tidak disimpan di Firestore.
/// - Profil utama disimpan di users/{uid}.
/// - Profil siswa tidak menggunakan koleksi students.
class AccountCreationService {
  AccountCreationService._();

  static final AccountCreationService instance =
  AccountCreationService._();

  static const String _secondaryAppName = 'lms-account-creation';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  FirebaseAuth? _secondaryAuth;

  /// Mendapatkan Firebase Authentication sekunder.
  Future<FirebaseAuth> _getSecondaryAuth() async {
    if (_secondaryAuth != null) {
      return _secondaryAuth!;
    }

    FirebaseApp secondaryApp;

    try {
      secondaryApp = Firebase.app(_secondaryAppName);
    } catch (_) {
      secondaryApp = await Firebase.initializeApp(
        name: _secondaryAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    _secondaryAuth = FirebaseAuth.instanceFor(
      app: secondaryApp,
    );

    return _secondaryAuth!;
  }

  /// Memastikan pengguna utama sudah login sebagai Admin.
  Future<void> _verifyAdmin() async {
    final admin = FirebaseAuth.instance.currentUser;

    if (admin == null) {
      throw Exception(
        'Sesi Admin tidak ditemukan. Silakan login kembali.',
      );
    }

    final adminDoc = await _db
        .collection('users')
        .doc(admin.uid)
        .get();

    if (!adminDoc.exists) {
      throw Exception(
        'Profil Admin tidak ditemukan di users/${admin.uid}.',
      );
    }

    final data = adminDoc.data() ?? {};

    final role = (data['role'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (role != 'admin') {
      throw Exception(
        'Akun yang sedang login tidak memiliki role Admin.',
      );
    }

    // Dokumen lama yang belum memiliki active tetap dianggap aktif.
    if (data['active'] == false) {
      throw Exception(
        'Akun Admin sedang dinonaktifkan.',
      );
    }
  }

  /// Membuat akun Guru.
  ///
  /// Profil guru disimpan pada:
  /// - users/{uid}
  /// - teachers/{teacherDocId}
  Future<String> createTeacherAccount({
    required String name,
    required String subject,
    required String email,
    required String nip,
    required String password,
  }) async {
    await _verifyAdmin();

    _validateCommonFields(
      name: name,
      email: email,
      password: password,
    );

    if (subject.trim().isEmpty) {
      throw Exception('Mata pelajaran wajib diisi.');
    }

    if (nip.trim().isEmpty) {
      throw Exception('NIP wajib diisi.');
    }

    final auth = await _getSecondaryAuth();
    UserCredential? credential;

    try {
      credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final newUser = credential.user;

      if (newUser == null) {
        throw Exception('Firebase gagal membuat akun Guru.');
      }

      final uid = newUser.uid;

      final teacherRef = _db.collection('teachers').doc();
      final userRef = _db.collection('users').doc(uid);

      final batch = _db.batch();

      batch.set(userRef, {
        'uid': uid,
        'name': name.trim(),
        'username': name.trim(),
        'email': email.trim(),
        'role': 'teacher',
        'teacherDocId': teacherRef.id,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.set(teacherRef, {
        'uid': uid,
        'name': name.trim(),
        'subject': subject.trim(),
        'email': email.trim(),
        'nip': nip.trim(),
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      return uid;
    } catch (e) {
      // Berusaha membersihkan akun Auth jika pembuatan profil gagal.
      if (credential?.user != null) {
        try {
          await credential!.user!.delete();
        } catch (cleanupError) {
          debugPrint(
            'Pembersihan akun Guru gagal: $cleanupError',
          );
        }
      }

      rethrow;
    } finally {
      try {
        await auth.signOut();
      } catch (e) {
        debugPrint(
          'Gagal sign out Auth sekunder: $e',
        );
      }
    }
  }

  /// Membuat akun Siswa.
  ///
  /// Profil siswa hanya disimpan pada users/{uid}.
  /// Tidak membuat koleksi students.
  Future<String> createStudentAccount({
    required String name,
    required String email,
    required String password,
    required String classId,
    required String className,
  }) async {
    await _verifyAdmin();

    _validateCommonFields(
      name: name,
      email: email,
      password: password,
    );

    if (classId.trim().isEmpty) {
      throw Exception('Kelas siswa wajib dipilih.');
    }

    if (className.trim().isEmpty) {
      throw Exception('Nama kelas siswa wajib diisi.');
    }

    final auth = await _getSecondaryAuth();
    UserCredential? credential;

    try {
      credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final newUser = credential.user;

      if (newUser == null) {
        throw Exception('Firebase gagal membuat akun Siswa.');
      }

      final uid = newUser.uid;
      final userRef = _db.collection('users').doc(uid);

      await userRef.set({
        'uid': uid,
        'name': name.trim(),
        'username': name.trim(),
        'email': email.trim(),
        'role': 'student',
        'classId': classId.trim(),
        'className': className.trim(),
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return uid;
    } catch (e) {
      // Berusaha membersihkan akun Auth jika pembuatan profil gagal.
      if (credential?.user != null) {
        try {
          await credential!.user!.delete();
        } catch (cleanupError) {
          debugPrint(
            'Pembersihan akun Siswa gagal: $cleanupError',
          );
        }
      }

      rethrow;
    } finally {
      try {
        await auth.signOut();
      } catch (e) {
        debugPrint(
          'Gagal sign out Auth sekunder: $e',
        );
      }
    }
  }

  /// Validasi data umum akun.
  void _validateCommonFields({
    required String name,
    required String email,
    required String password,
  }) {
    if (name.trim().isEmpty) {
      throw Exception('Nama wajib diisi.');
    }

    if (email.trim().isEmpty) {
      throw Exception('Email wajib diisi.');
    }

    if (password.length < 6) {
      throw Exception(
        'Password harus terdiri dari minimal 6 karakter.',
      );
    }

    if (!email.trim().contains('@')) {
      throw Exception('Format email tidak valid.');
    }
  }
}