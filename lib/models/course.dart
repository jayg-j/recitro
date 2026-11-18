/// A class the teacher handles (e.g. "BSIT 2-A" or "Grade 7 – Rizal"), with
/// its own students and the subjects taught to it.
class Course {
  Course({required this.id, required this.name, List<String>? subjects})
      : subjects = subjects ?? [];

  final String id;
  String name;
  final List<String> subjects;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'subjects': subjects,
      };

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: json['id'] as String,
        name: json['name'] as String,
        subjects: (json['subjects'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
      );
}
