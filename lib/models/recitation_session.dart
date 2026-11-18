import 'student_session_state.dart';

class RecitationSession {
  RecitationSession({
    required this.id,
    required this.name,
    required this.pointsPerAnswer,
    required this.pointsRequiredForReward,
    required this.rewardLabel,
    required this.allowRecallUnanswered,
    required this.allowRecallAnswered,
    required this.studentStates,
    required this.createdAt,
    this.previousSessionName,
    this.pendingStudentId,
  });

  final String id;
  String name;
  int pointsPerAnswer;
  int pointsRequiredForReward;
  String rewardLabel;
  bool allowRecallUnanswered;
  bool allowRecallAnswered;
  Map<String, StudentSessionState> studentStates;
  DateTime createdAt;

  /// Name of the session that priority students were carried over from.
  String? previousSessionName;
  String? pendingStudentId;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'pointsPerAnswer': pointsPerAnswer,
        'pointsRequiredForReward': pointsRequiredForReward,
        'rewardLabel': rewardLabel,
        'allowRecallUnanswered': allowRecallUnanswered,
        'allowRecallAnswered': allowRecallAnswered,
        'createdAt': createdAt.toIso8601String(),
        'previousSessionName': previousSessionName,
        'pendingStudentId': pendingStudentId,
        'studentStates': studentStates.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      };

  factory RecitationSession.fromJson(Map<String, dynamic> json) =>
      RecitationSession(
        id: json['id'] as String,
        name: json['name'] as String,
        pointsPerAnswer: json['pointsPerAnswer'] as int,
        pointsRequiredForReward: json['pointsRequiredForReward'] as int? ??
            (json['pointsPerAnswer'] as int),
        rewardLabel: (json['rewardLabel'] as String?) ?? 'Reward',
        allowRecallUnanswered: json['allowRecallUnanswered'] as bool,
        allowRecallAnswered: json['allowRecallAnswered'] as bool? ?? false,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        previousSessionName: json['previousSessionName'] as String?,
        pendingStudentId: json['pendingStudentId'] as String?,
        studentStates: (json['studentStates'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(
            key,
            StudentSessionState.fromJson(value as Map<String, dynamic>),
          ),
        ),
      );
}
