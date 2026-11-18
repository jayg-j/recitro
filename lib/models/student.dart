class Student {
  Student({required this.id, required this.name, this.courseId = ''});

  final String id;
  String name;

  /// The course this student belongs to. Empty only for data saved before
  /// courses existed; it is filled in when the data is loaded.
  String courseId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'courseId': courseId,
      };

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String,
        name: json['name'] as String,
        courseId: json['courseId'] as String? ?? '',
      );
}
