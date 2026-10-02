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
}

final List<Course> dummyCourses = [
  Course(
    id: 'c1',
    title: 'Flutter for Beginners',
    instructor: 'Donald Trump',
    image: 'assets/images/onboarding1.png',
    description: 'Learn the basics of Flutter and build beautiful UIs.',
    lessons: 12,
  ),
  Course(
    id: 'c2',
    title: 'State Management Guide',
    instructor: 'Joe Biden',
    image: 'assets/images/onboarding2.png',
    description: 'Understand setState and simple state management.',
    lessons: 8,
  ),
  Course(
    id: 'c3',
    title: 'Dart Programming Deep-dive',
    instructor: 'Stephen Hawking',
    image: 'assets/images/onboarding3.png',
    description: 'Improve your Dart skills with practical examples.',
    lessons: 10,
  ),
];
