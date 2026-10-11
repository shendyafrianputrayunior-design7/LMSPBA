import {onCall, HttpsError} from "firebase-functions/v2/https";
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {FieldValue, getFirestore} from "firebase-admin/firestore";

initializeApp();

const db = getFirestore();

export const createManagedUser = onCall(
  {region: "asia-southeast2"},
  async (request) => {
    // Pastikan pengguna sudah login.
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Silakan login terlebih dahulu."
      );
    }

    // Pastikan pengguna yang membuat akun adalah admin.
    const adminDoc = await db
      .collection("users")
      .doc(request.auth.uid)
      .get();

    if (
      !adminDoc.exists ||
      String(adminDoc.data()?.role ?? "").toLowerCase() !== "admin"
    ) {
      throw new HttpsError(
        "permission-denied",
        "Hanya admin yang dapat membuat akun."
      );
    }

    const {
      name,
      email,
      password,
      role,
      phone = "",
      classId = "",
    } = request.data ?? {};

    const normalizedRole = String(role ?? "").toLowerCase();
    const normalizedEmail = String(email ?? "").trim().toLowerCase();
    const normalizedName = String(name ?? "").trim();

    if (!normalizedName || !normalizedEmail || !password) {
      throw new HttpsError(
        "invalid-argument",
        "Nama, email, dan password wajib diisi."
      );
    }

    if (String(password).length < 8) {
      throw new HttpsError(
        "invalid-argument",
        "Password minimal 8 karakter."
      );
    }

    if (!["admin", "teacher", "student"].includes(normalizedRole)) {
      throw new HttpsError(
        "invalid-argument",
        "Role harus admin, teacher, atau student."
      );
    }

    let className = "";

    // Validasi kelas untuk akun siswa.
    if (normalizedRole === "student") {
      if (!classId) {
        throw new HttpsError(
          "invalid-argument",
          "Kelas wajib dipilih untuk akun siswa."
        );
      }

      const classDoc = await db
        .collection("classes")
        .doc(String(classId))
        .get();

      if (!classDoc.exists) {
        throw new HttpsError(
          "not-found",
          "Kelas yang dipilih tidak ditemukan."
        );
      }

      className = String(
        classDoc.data()?.name ??
        classDoc.data()?.className ??
        classDoc.data()?.classTitle ??
        ""
      );
    }

    let createdUser;

    try {
      createdUser = await getAuth().createUser({
        email: normalizedEmail,
        password: String(password),
        displayName: normalizedName,
      });

      const userData: Record<string, unknown> = {
        uid: createdUser.uid,
        name: normalizedName,
        email: normalizedEmail,
        role: normalizedRole,
        phone: String(phone ?? "").trim(),
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      if (normalizedRole === "student") {
        userData.classId = String(classId);
        userData.className = className;
      }

      await db.collection("users").doc(createdUser.uid).set(userData);

      // Buat dokumen guru jika role-nya teacher.
      if (normalizedRole === "teacher") {
        await db.collection("teachers").doc(createdUser.uid).set({
          uid: createdUser.uid,
          name: normalizedName,
          email: normalizedEmail,
          phone: String(phone ?? "").trim(),
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      return {
        success: true,
        uid: createdUser.uid,
        message: "Akun berhasil dibuat.",
      };
    } catch (error: unknown) {
      // Hapus akun Auth jika proses penyimpanan profil gagal.
      if (createdUser) {
        await getAuth().deleteUser(createdUser.uid).catch(() => {});
        await db.collection("users").doc(createdUser.uid).delete()
          .catch(() => {});
        await db.collection("teachers").doc(createdUser.uid).delete()
          .catch(() => {});
      }

      if (error instanceof HttpsError) {
        throw error;
      }

      if (
        typeof error === "object" &&
        error !== null &&
        "code" in error &&
        error.code === "auth/email-already-exists"
      ) {
        throw new HttpsError(
          "already-exists",
          "Email tersebut sudah terdaftar."
        );
      }

      console.error("createManagedUser error:", error);

      throw new HttpsError(
        "internal",
        "Gagal membuat akun. Periksa konfigurasi Firebase."
      );
    }
  }
);
