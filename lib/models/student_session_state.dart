import 'call_outcome.dart';

class StudentSessionState {
  StudentSessionState({
    required this.studentId,
    this.outcome = CallOutcome.notCalled,
    this.pointsEarned = 0,
    this.rewardClaimed = false,
    this.priority = false,
    this.outcomeBeforeCall,
  });

  final String studentId;
  CallOutcome outcome;
  int pointsEarned;
  bool rewardClaimed;

  /// True when the student was not called in the previous session, so they
  /// are called before everyone else in this one.
  bool priority;

  /// Outcome before the current call started, restored if the teacher skips.
  CallOutcome? outcomeBeforeCall;

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'outcome': outcome.name,
        'pointsEarned': pointsEarned,
        'rewardClaimed': rewardClaimed,
        'priority': priority,
        'outcomeBeforeCall': outcomeBeforeCall?.name,
      };

  factory StudentSessionState.fromJson(Map<String, dynamic> json) {
    final before = json['outcomeBeforeCall'] as String?;
    return StudentSessionState(
      studentId: json['studentId'] as String,
      outcome: CallOutcome.values.byName(json['outcome'] as String),
      pointsEarned: json['pointsEarned'] as int? ?? 0,
      rewardClaimed: json['rewardClaimed'] as bool? ?? false,
      priority: json['priority'] as bool? ?? false,
      outcomeBeforeCall: before == null ? null : CallOutcome.values.byName(before),
    );
  }
}
