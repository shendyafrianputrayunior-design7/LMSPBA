import 'package:cloud_firestore/cloud_firestore.dart';

class Quiz {
  final String id;
  final String courseId;
  final String teacherId;
  final String title;
  final String description;
  final int duration;
  final int passingScore;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Quiz({
    required this.id,
    required this.courseId,
    required this.teacherId,
    required this.title,
    required this.description,
    required this.duration,
    required this.passingScore,
    this.createdAt,
    this.updatedAt,
  });

  factory Quiz.fromFirestore(
      String id,
      Map<String, dynamic> data,
      ) {
    return Quiz(
      id: id,
      courseId: (data['courseId'] ?? '').toString(),
      teacherId: (data['teacherId'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),

      duration: data['duration'] is int
          ? data['duration'] as int
          : int.tryParse(
        (data['duration'] ?? '0').toString(),
      ) ??
          0,

      passingScore: data['passingScore'] is int
          ? data['passingScore'] as int
          : int.tryParse(
        (data['passingScore'] ?? '70').toString(),
      ) ??
          70,

      createdAt: _parseTimestamp(
        data['createdAt'],
      ),

      updatedAt: _parseTimestamp(
        data['updatedAt'],
      ),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'courseId': courseId,
      'teacherId': teacherId,
      'title': title,
      'description': description,
      'duration': duration,
      'passingScore': passingScore,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}