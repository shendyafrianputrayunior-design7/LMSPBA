
import 'package:cloud_firestore/cloud_firestore.dart';

class QuizQuestion {
final String id;
final String quizId;
final String question;
final Map<String, String> options;
final String correctAnswer;
final int points;
final int order;
final DateTime? createdAt;
final DateTime? updatedAt;

QuizQuestion({
required this.id,
required this.quizId,
required this.question,
required this.options,
required this.correctAnswer,
required this.points,
required this.order,
this.createdAt,
this.updatedAt,
});

factory QuizQuestion.fromFirestore(
String id,
Map<String, dynamic> data,
) {
final rawOptions = data['options'];

final Map<String, String> parsedOptions = {};

if (rawOptions is Map) {
rawOptions.forEach((key, value) {
parsedOptions[key.toString()] =
value.toString();
});
}

return QuizQuestion(
id: id,
quizId: (data['quizId'] ?? '').toString(),
question: (data['question'] ?? '').toString(),
options: parsedOptions,
correctAnswer:
(data['correctAnswer'] ?? '').toString(),
points: data['points'] is int
? data['points'] as int
    : int.tryParse(
(data['points'] ?? '10').toString(),
) ??
10,
order: data['order'] is int
? data['order'] as int
    : int.tryParse(
(data['order'] ?? '0').toString(),
) ??
0,
createdAt: _parseTimestamp(data['createdAt']),
updatedAt: _parseTimestamp(data['updatedAt']),
);
}

Map<String, dynamic> toFirestore() {
return {
'quizId': quizId,
'question': question,
'options': options,
'correctAnswer': correctAnswer,
'points': points,
'order': order,
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