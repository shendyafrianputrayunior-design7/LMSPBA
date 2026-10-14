import { setGlobalOptions } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import {
  getFirestore,
  FieldValue,
} from "firebase-admin/firestore";

setGlobalOptions({
  maxInstances: 10,
  region: "asia-southeast1",
});

initializeApp();

const db = getFirestore();
const auth = getAuth();

export const createTeacher = onCall(
  {
    enforceAppCheck: false,
  },
  async (request) => {
    // 1. Pastikan pemanggil sudah login.
    if (!request.auth) {
      throw new HttpsError(
        "unauthenticated",
        "Silakan login terlebih dahulu.",
      );
    }

    const adminUid = request.auth.uid;

    // 2. Pastikan akun yang memanggil adalah admin.
    const adminDoc = await db.collection("users").doc(adminUid).get();

    if (!adminDoc.exists || adminDoc.get("role") !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Hanya admin yang dapat membuat akun guru.",
      );
    }

    // 3. Ambil dan validasi data.
    const name = String(request.data?.name ?? "").trim();
    const subject = String(request.data?.subject ?? "").trim();
    const email = String(request.data?.email ?? "").trim().toLowerCase();
    const nip = String(request.data?.nip ?? "").trim();
    const password = String(request.data?.password ?? "");

    if (!name || !subject || !email || !nip || !password) {
      throw new HttpsError(
        "invalid-argument",
        "Nama, mata pelajaran, email, NIP, dan password wajib diisi.",
      );
    }

    if (password.length < 6) {
      throw new HttpsError(
        "invalid-argument",
        "Password minimal 6 karakter.",
      );
    }

    const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    if (!emailPattern.test(email)) {
      throw new HttpsError(
        "invalid-argument",
        "Format email tidak valid.",
      );
    }

    // 4. Pastikan NIP belum digunakan.
    const nipQuery = await db
      .collection("teachers")
      .where("nip", "==", nip)
      .limit(1)
      .get();

    if (!nipQuery.empty) {
      throw new HttpsError(
        "already-exists",
        "NIP tersebut sudah terdaftar.",
      );
    }

    let teacherUid: string | null = null;

    try {
      // 5. Buat akun Firebase Authentication di server.
      const userRecord = await auth.createUser({
        email,
        password,
        displayName: name,
        disabled: false,
      });

      teacherUid = userRecord.uid;

      // 6. Simpan profil guru dan data guru ke Firestore.
      const teacherRef = db.collection("teachers").doc(teacherUid);
      const userRef = db.collection("users").doc(teacherUid);

      const batch = db.batch();

      batch.set(userRef, {
        uid: teacherUid,
        name,
        email,
        role: "teacher",
        subject,
        nip,
        active: true,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      batch.set(teacherRef, {
        uid: teacherUid,
        name,
        subject,
        email,
        nip,
        active: true,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      await batch.commit();

      return {
        success: true,
        uid: teacherUid,
        message: "Akun guru berhasil dibuat.",
      };
    } catch (error) {
      // 7. Jika penyimpanan gagal, hapus akun Auth yang baru dibuat.
      if (teacherUid) {
        try {
          await auth.deleteUser(teacherUid);
        } catch (cleanupError) {
          console.error(
            "Gagal membersihkan akun guru:",
            cleanupError,
          );
        }

        try {
          await db.collection("users").doc(teacherUid).delete();
          await db.collection("teachers").doc(teacherUid).delete();
        } catch (cleanupError) {
          console.error(
            "Gagal membersihkan dokumen guru:",
            cleanupError,
          );
        }
      }

      if (error instanceof HttpsError) {
        throw error;
      }

      console.error("createTeacher gagal:", error);

      throw new HttpsError(
        "internal",
        "Akun guru gagal dibuat. Periksa log Cloud Functions.",
      );
    }
  },
);