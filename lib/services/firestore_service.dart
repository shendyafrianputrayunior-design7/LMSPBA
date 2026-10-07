import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  FirestoreService._();

  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============================================================
  // HELPER
  // ============================================================

  String _classIdFromName(String name) {
    return name
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  int _toInt(dynamic value, {int defaultValue = 0}) {
    if (value is int) {
      return value;
    }

    if (value is double) {
      return value.toInt();
    }

    return int.tryParse(
      (value ?? '').toString().trim(),
    ) ??
        defaultValue;
  }

  // ============================================================
  // CLASSES
  // ============================================================

  CollectionReference<Map<String, dynamic>> get classes =>
      _db.collection('classes');

  Stream<QuerySnapshot<Map<String, dynamic>>> getClasses() {
    return classes.orderBy('name').snapshots();
  }

  Future<String> addClass({
    required String name,
    required String major,
    required String grade,
    required String school,
    required String description,
  }) async {
    final classId = _classIdFromName(name);

    await classes.doc(classId).set({
      'name': name.trim(),
      'major': major.trim(),
      'grade': grade.trim(),
      'school': school.trim(),
      'description': description.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return classId;
  }

  Future<void> updateClass({
    required String id,
    required String name,
    required String major,
    required String grade,
    required String school,
    required String description,
  }) async {
    await classes.doc(id).update({
      'name': name.trim(),
      'major': major.trim(),
      'grade': grade.trim(),
      'school': school.trim(),
      'description': description.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteClass(String id) async {
    await classes.doc(id).delete();
  }

  // ============================================================
  // TEACHERS
  // ============================================================

  CollectionReference<Map<String, dynamic>> get teachers =>
      _db.collection('teachers');

  Stream<QuerySnapshot<Map<String, dynamic>>> getTeachers() {
    return teachers.orderBy('name').snapshots();
  }

  Future<String> addTeacher({
    required String name,
    required String subject,
    required String email,
    required String nip,
  }) async {
    final doc = await teachers.add({
      'name': name.trim(),
      'subject': subject.trim(),
      'email': email.trim(),
      'nip': nip.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> updateTeacher({
    required String id,
    required String name,
    required String subject,
    required String email,
    required String nip,
  }) async {
    await teachers.doc(id).update({
      'name': name.trim(),
      'subject': subject.trim(),
      'email': email.trim(),
      'nip': nip.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTeacher(String id) async {
    await teachers.doc(id).delete();
  }

  // ============================================================
  // SCHEDULES
  // ============================================================

  CollectionReference<Map<String, dynamic>> get schedules =>
      _db.collection('schedules');

  Stream<QuerySnapshot<Map<String, dynamic>>> getSchedules() {
    return schedules.orderBy('day').snapshots();
  }

  Future<String> addSchedule({
    required String classId,
    required String subject,
    required String teacherId,
    required String day,
    required String startTime,
    required String endTime,
    required String room,
  }) async {
    final doc = await schedules.add({
      'classId': classId.trim(),
      'subject': subject.trim(),
      'teacherId': teacherId.trim(),
      'day': day.trim(),
      'startTime': startTime.trim(),
      'endTime': endTime.trim(),
      'room': room.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> updateSchedule({
    required String id,
    required String classId,
    required String subject,
    required String teacherId,
    required String day,
    required String startTime,
    required String endTime,
    required String room,
  }) async {
    await schedules.doc(id).update({
      'classId': classId.trim(),
      'subject': subject.trim(),
      'teacherId': teacherId.trim(),
      'day': day.trim(),
      'startTime': startTime.trim(),
      'endTime': endTime.trim(),
      'room': room.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteSchedule(String id) async {
    await schedules.doc(id).delete();
  }

  // ============================================================
  // MATERIALS
  // ============================================================

  CollectionReference<Map<String, dynamic>> get materials =>
      _db.collection('materials');

  Stream<QuerySnapshot<Map<String, dynamic>>> getMaterials() {
    return materials.orderBy('title').snapshots();
  }

  Future<String> addMaterial({
    required String classId,
    required String teacherId,
    required String subject,
    required String title,
    required String description,
    required String type,
    required String fileUrl,
  }) async {
    final doc = await materials.add({
      'classId': classId.trim(),
      'teacherId': teacherId.trim(),
      'subject': subject.trim(),
      'title': title.trim(),
      'description': description.trim(),
      'type': type.trim(),
      'fileUrl': fileUrl.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> updateMaterial({
    required String id,
    required String classId,
    required String teacherId,
    required String subject,
    required String title,
    required String description,
    required String type,
    required String fileUrl,
  }) async {
    await materials.doc(id).update({
      'classId': classId.trim(),
      'teacherId': teacherId.trim(),
      'subject': subject.trim(),
      'title': title.trim(),
      'description': description.trim(),
      'type': type.trim(),
      'fileUrl': fileUrl.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMaterial(String id) async {
    await materials.doc(id).delete();
  }

  // ============================================================
  // QUIZZES
  // ============================================================

  CollectionReference<Map<String, dynamic>> get quizzes =>
      _db.collection('quizzes');

  Stream<QuerySnapshot<Map<String, dynamic>>> getQuizzes() {
    return quizzes.orderBy('title').snapshots();
  }

  Future<String> addQuiz({
    required String classId,
    required String teacherId,
    required String subject,
    required String title,
    required int duration,
    required String description,
  }) async {
    final doc = await quizzes.add({
      'classId': classId.trim(),
      'teacherId': teacherId.trim(),
      'subject': subject.trim(),
      'title': title.trim(),
      'duration': duration,
      'description': description.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> updateQuiz({
    required String id,
    required String classId,
    required String teacherId,
    required String subject,
    required String title,
    required int duration,
    required String description,
  }) async {
    await quizzes.doc(id).update({
      'classId': classId.trim(),
      'teacherId': teacherId.trim(),
      'subject': subject.trim(),
      'title': title.trim(),
      'duration': duration,
      'description': description.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteQuiz(String id) async {
    await quizzes.doc(id).delete();
  }

  // ============================================================
  // QUIZ QUESTIONS
  // ============================================================

  CollectionReference<Map<String, dynamic>> quizQuestions(
      String quizId,
      ) {
    return quizzes.doc(quizId).collection('questions');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> getQuizQuestions(
      String quizId,
      ) {
    return quizQuestions(quizId).snapshots();
  }

  Future<String> addQuizQuestion({
    required String quizId,
    required String question,
    required List<String> options,
    required String answer,
  }) async {
    final doc = await quizQuestions(quizId).add({
      'question': question.trim(),
      'options': options,
      'answer': answer.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> updateQuizQuestion({
    required String quizId,
    required String questionId,
    required String question,
    required List<String> options,
    required String answer,
  }) async {
    await quizQuestions(quizId).doc(questionId).update({
      'question': question.trim(),
      'options': options,
      'answer': answer.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteQuizQuestion({
    required String quizId,
    required String questionId,
  }) async {
    await quizQuestions(quizId).doc(questionId).delete();
  }

  // ============================================================
  // EXAMS
  // ============================================================

  CollectionReference<Map<String, dynamic>> get exams =>
      _db.collection('exams');

  Stream<QuerySnapshot<Map<String, dynamic>>> getExams() {
    return exams.orderBy('title').snapshots();
  }

  Future<String> addExam({
    required String classId,
    required String teacherId,
    required String subject,
    required String title,
    required int duration,
    required String date,
    required String description,
    String teacherName = '',
    String courseId = '',
    String courseName = '',
    String className = '',
    String startTime = '',
    String endTime = '',
    String room = '',
  }) async {
    final data = <String, dynamic>{
      'classId': classId.trim(),
      'teacherId': teacherId.trim(),
      'teacherName': teacherName.trim(),
      'subject': subject.trim(),
      'title': title.trim(),
      'duration': duration,
      'date': date.trim(),
      'description': description.trim(),
      'courseId': courseId.trim(),
      'courseName': courseName.trim(),
      'className': className.trim(),
      'startTime': startTime.trim(),
      'endTime': endTime.trim(),
      'room': room.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final doc = await exams.add(data);

    return doc.id;
  }

  Future<void> updateExam({
    required String id,
    required String classId,
    required String teacherId,
    required String subject,
    required String title,
    required int duration,
    required String date,
    required String description,
    String teacherName = '',
    String courseId = '',
    String courseName = '',
    String className = '',
    String startTime = '',
    String endTime = '',
    String room = '',
  }) async {
    await exams.doc(id).update({
      'classId': classId.trim(),
      'teacherId': teacherId.trim(),
      'teacherName': teacherName.trim(),
      'subject': subject.trim(),
      'title': title.trim(),
      'duration': duration,
      'date': date.trim(),
      'description': description.trim(),
      'courseId': courseId.trim(),
      'courseName': courseName.trim(),
      'className': className.trim(),
      'startTime': startTime.trim(),
      'endTime': endTime.trim(),
      'room': room.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteExam(String id) async {
    await exams.doc(id).delete();
  }

  // ============================================================
  // EXAM QUESTIONS
  //
  // SCHEMA BARU:
  //
  // exam_questions/{questionId}
  //
  // examId
  // question
  // options: {
  //   A: "...",
  //   B: "...",
  //   C: "...",
  //   D: "..."
  // }
  // correctAnswer
  // points
  // order
  // createdAt
  // updatedAt
  //
  // ============================================================

  CollectionReference<Map<String, dynamic>> get examQuestions =>
      _db.collection('exam_questions');

  Stream<QuerySnapshot<Map<String, dynamic>>> getExamQuestions(
      String examId,
      ) {
    return examQuestions
        .where('examId', isEqualTo: examId)
        .snapshots();
  }

  Future<String> addExamQuestion({
    required String examId,
    required String question,
    required List<String> options,
    required String answer,
    int points = 1,
    int order = 0,
  }) async {
    final optionMap = <String, String>{
      'A': options.isNotEmpty ? options[0].trim() : '',
      'B': options.length > 1 ? options[1].trim() : '',
      'C': options.length > 2 ? options[2].trim() : '',
      'D': options.length > 3 ? options[3].trim() : '',
    };

    final doc = await examQuestions.add({
      'examId': examId.trim(),
      'question': question.trim(),
      'options': optionMap,
      'correctAnswer': answer.trim().toUpperCase(),
      'points': points,
      'order': order,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> updateExamQuestion({
    required String examId,
    required String questionId,
    required String question,
    required List<String> options,
    required String answer,
    int points = 1,
    int order = 0,
  }) async {
    final optionMap = <String, String>{
      'A': options.isNotEmpty ? options[0].trim() : '',
      'B': options.length > 1 ? options[1].trim() : '',
      'C': options.length > 2 ? options[2].trim() : '',
      'D': options.length > 3 ? options[3].trim() : '',
    };

    await examQuestions.doc(questionId).update({
      'examId': examId.trim(),
      'question': question.trim(),
      'options': optionMap,
      'correctAnswer': answer.trim().toUpperCase(),
      'points': points,
      'order': order,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteExamQuestion({
    required String examId,
    required String questionId,
  }) async {
    await examQuestions.doc(questionId).delete();
  }

  // ============================================================
  // ANNOUNCEMENTS
  // ============================================================

  CollectionReference<Map<String, dynamic>> get announcements =>
      _db.collection('announcements');

  Stream<QuerySnapshot<Map<String, dynamic>>> getAnnouncements() {
    return announcements
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<String> addAnnouncement({
    required String title,
    required String content,
    required String category,
    String? targetClassId,
    String? targetClassName,
    String? targetClass,
    required String date,
    required bool important,
    String? teacherId,
  }) async {
    final resolvedTargetClassId =
    targetClassId?.trim().isNotEmpty == true
        ? targetClassId!.trim()
        : _classIdFromName(
      targetClassName?.trim().isNotEmpty == true
          ? targetClassName!
          : targetClass ?? 'ALL',
    );

    final resolvedTargetClassName =
    targetClassName?.trim().isNotEmpty == true
        ? targetClassName!.trim()
        : targetClass?.trim().isNotEmpty == true
        ? targetClass!.trim()
        : 'Semua Kelas';

    final data = <String, dynamic>{
      'title': title.trim(),
      'content': content.trim(),
      'category': category.trim(),
      'targetClassId': resolvedTargetClassId,
      'targetClassName': resolvedTargetClassName,
      'targetClass': targetClass?.trim().isNotEmpty == true
          ? targetClass!.trim()
          : resolvedTargetClassName,
      'date': date.trim(),
      'important': important,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (teacherId != null && teacherId.trim().isNotEmpty) {
      data['teacherId'] = teacherId.trim();
    }

    final doc = await announcements.add(data);

    return doc.id;
  }

  Future<void> updateAnnouncement({
    required String id,
    required String title,
    required String content,
    required String category,
    String? targetClassId,
    String? targetClassName,
    String? targetClass,
    required String date,
    required bool important,
    String? teacherId,
  }) async {
    final resolvedTargetClassId =
    targetClassId?.trim().isNotEmpty == true
        ? targetClassId!.trim()
        : _classIdFromName(
      targetClassName?.trim().isNotEmpty == true
          ? targetClassName!
          : targetClass ?? 'ALL',
    );

    final resolvedTargetClassName =
    targetClassName?.trim().isNotEmpty == true
        ? targetClassName!.trim()
        : targetClass?.trim().isNotEmpty == true
        ? targetClass!.trim()
        : 'Semua Kelas';

    final data = <String, dynamic>{
      'title': title.trim(),
      'content': content.trim(),
      'category': category.trim(),
      'targetClassId': resolvedTargetClassId,
      'targetClassName': resolvedTargetClassName,
      'targetClass': targetClass?.trim().isNotEmpty == true
          ? targetClass!.trim()
          : resolvedTargetClassName,
      'date': date.trim(),
      'important': important,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (teacherId != null && teacherId.trim().isNotEmpty) {
      data['teacherId'] = teacherId.trim();
    }

    await announcements.doc(id).update(data);
  }

  Future<void> deleteAnnouncement(String id) async {
    await announcements.doc(id).delete();
  }

  // ============================================================
  // ACHIEVEMENTS
  // ============================================================

  CollectionReference<Map<String, dynamic>> get achievements =>
      _db.collection('achievements');

  Stream<QuerySnapshot<Map<String, dynamic>>> getAchievements() {
    return achievements.orderBy('title').snapshots();
  }

  Future<String> addAchievement({
    required String title,
    required String description,
    required String category,
    required String targetClassId,
    required String targetClassName,
    required int points,
    required bool active,
  }) async {
    final doc = await achievements.add({
      'title': title.trim(),
      'description': description.trim(),
      'category': category.trim(),
      'targetClassId': targetClassId.trim(),
      'targetClassName': targetClassName.trim(),
      'targetClass': targetClassName.trim(),
      'points': points,
      'active': active,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> updateAchievement({
    required String id,
    required String title,
    required String description,
    required String category,
    required String targetClassId,
    required String targetClassName,
    required int points,
    required bool active,
  }) async {
    await achievements.doc(id).update({
      'title': title.trim(),
      'description': description.trim(),
      'category': category.trim(),
      'targetClassId': targetClassId.trim(),
      'targetClassName': targetClassName.trim(),
      'targetClass': targetClassName.trim(),
      'points': points,
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAchievement(String id) async {
    await achievements.doc(id).delete();
  }

  // ============================================================
  // ATTENDANCE
  // ============================================================

  CollectionReference<Map<String, dynamic>> get attendance =>
      _db.collection('attendance');

  Stream<QuerySnapshot<Map<String, dynamic>>> getAttendanceForUser(
      String userId,
      ) {
    return attendance
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots();
  }

  Future<String> addAttendance({
    required String userId,
    required String classId,
    required String scheduleId,
    required String subject,
    required String date,
    required String status,
    required String note,
  }) async {
    final doc = await attendance.add({
      'userId': userId.trim(),
      'classId': classId.trim(),
      'scheduleId': scheduleId.trim(),
      'subject': subject.trim(),
      'date': date.trim(),
      'status': status.trim(),
      'note': note.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }

  Future<void> updateAttendance({
    required String id,
    required String status,
    required String note,
  }) async {
    await attendance.doc(id).update({
      'status': status.trim(),
      'note': note.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAttendance(String id) async {
    await attendance.doc(id).delete();
  }
}