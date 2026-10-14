
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
/// - ID guru dibuat berurutan: teacher_001, teacher_002, dst.
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

    // Dokumen lama tanpa active tetap dianggap aktif.
    if (data['active'] == false) {
      throw Exception('Akun Admin sedang dinonaktifkan.');
    }
  }

  /// Membuat ID guru berurutan menggunakan transaksi Firestore.
  ///
  /// Dokumen penghitung:
  /// counters/teachers
  ///
  /// Contoh:
  /// teacher_001
  /// teacher_002
  /// teacher_003
  Future<String> _generateTeacherId(
      Transaction transaction,
      ) async {
    final counterRef = _db
        .collection('counters')
        .doc('teachers');

    final counterSnapshot = await transaction.get(counterRef);

    int lastNumber = 0;

    if (counterSnapshot.exists) {
      final data = counterSnapshot.data();

      lastNumber =
          (data?['lastNumber'] as num?)?.toInt() ?? 0;
    }

    final nextNumber = lastNumber + 1;

    return 'teacher_${nextNumber.toString().padLeft(3, '0')}';
  }

  /// Membuat akun Guru.
  ///
  /// Profil disimpan di:
  /// - users/{uid}
  /// - teachers/teacher_XXX
  ///
  /// Mengembalikan ID guru, misalnya teacher_001.
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

    String? createdTeacherId;
    bool profileCreationStarted = false;

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

      final userRef = _db.collection('users').doc(uid);

      // Transaksi membuat ID berikutnya dan profil guru.
      // Transaksi membuat ID berikutnya dan profil guru.
      final teacherId = await _db.runTransaction<String>(
            (transaction) async {
          final counterRef = _db
              .collection('counters')
              .doc('teachers');

          // Baca counter terlebih dahulu.
          final counterSnapshot = await transaction.get(counterRef);

          int lastNumber = 0;

          if (counterSnapshot.exists) {
            final counterData = counterSnapshot.data();

            lastNumber =
                (counterData?['lastNumber'] as num?)?.toInt() ?? 0;
          }

          final nextNumber = lastNumber + 1;
          final generatedId =
              'teacher_${nextNumber.toString().padLeft(3, '0')}';

          final teacherRef = _db
              .collection('teachers')
              .doc(generatedId);

          // Semua operasi baca dilakukan sebelum operasi tulis.
          final existingTeacher = await transaction.get(teacherRef);

          if (existingTeacher.exists) {
            throw Exception(
              'ID $generatedId sudah digunakan. '
                  'Periksa counters/teachers.lastNumber.',
            );
          }

          // Mulai operasi tulis setelah seluruh pembacaan selesai.
          transaction.set(counterRef, {
            'lastNumber': nextNumber,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          transaction.set(teacherRef, {
            'uid': uid,
            'teacherId': generatedId,
            'name': name.trim(),
            'subject': subject.trim(),
            'email': email.trim(),
            'nip': nip.trim(),
            'active': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });

          return generatedId;
        },
      );

      createdTeacherId = teacherId;

// Simpan profil utama akun guru.
      profileCreationStarted = true;

      await userRef.set({
        'uid': uid,
        'name': name.trim(),
        'username': name.trim(),
        'email': email.trim(),
        'role': 'teacher',
        'teacherId': teacherId,
        'teacherDocId': teacherId,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return teacherId;
    } catch (e) {
      // Berusaha membersihkan profil jika pembuatan akun gagal.
      // Penghapusan profil guru tidak dilakukan secara otomatis
      // jika penulisan users gagal, agar tidak menghapus data
      // secara keliru ketika terjadi kegagalan jaringan.
      if (credential?.user != null) {
        try {
          await credential!.user!.delete();
        } catch (cleanupError) {
          debugPrint(
            'Pembersihan akun Guru gagal: $cleanupError',
          );
        }
      }

      debugPrint(
        'Pembuatan akun Guru gagal. '
            'teacherId=$createdTeacherId, '
            'profileCreationStarted=$profileCreationStarted, '
            'error=$e',
      );

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
  /// Profil siswa hanya disimpan di users/{uid}.
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
