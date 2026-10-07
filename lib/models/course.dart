class Course {
  final String id;
  final String title;
  final String instructor;
  final String image;
  final String description;
  final int lessons;

  Course({
    required this.id,
    required this.title,
    required this.instructor,
    required this.image,
    required this.description,
    required this.lessons,
  });

  // =============================================================
  // FIRESTORE → COURSE
  // =============================================================

  factory Course.fromFirestore(
      String id,
      Map<String, dynamic> data,
      ) {
    return Course(
      id: id,
      title: (data['title'] ?? '').toString(),
      instructor: (data['instructor'] ?? '').toString(),
      image: (data['image'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      lessons: data['lessons'] is int
          ? data['lessons'] as int
          : int.tryParse(
        (data['lessons'] ?? '0').toString(),
      ) ??
          0,
    );
  }

  // =============================================================
  // COURSE → FIRESTORE
  // =============================================================

  Map<String, dynamic> toFirestore({
    required String classId,
  }) {
    return {
      'classId': classId,
      'title': title,
      'instructor': instructor,
      'image': image,
      'description': description,
      'lessons': lessons,
    };
  }
}