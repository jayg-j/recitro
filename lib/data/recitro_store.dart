import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/call_outcome.dart';
import '../models/point_ledger_entry.dart';
import '../models/recitation_session.dart';
import '../models/student.dart';
import '../models/student_session_state.dart';

class RecitroStore extends ChangeNotifier {
  RecitroStore({this.persist = true});

  /// Tests can turn off disk reads and writes.
  final bool persist;

  static const _uuid = Uuid();
  static const int primaryPickWeight = 10;
  static const int answeredRecallPickWeight = 2;
  static const int maxPointsPerCall = 999;

  final List<Student> _students = [];
  final List<RecitationSession> _sessions = [];
  final List<PointLedgerEntry> _ledger = [];

  List<Student> get students => List.unmodifiable(_students);

  /// Sessions in creation order (oldest first).
  List<RecitationSession> get sessions => List.unmodifiable(_sessions);
  List<PointLedgerEntry> get ledger => List.unmodifiable(_ledger);

  Future<void> init() async {
    if (!persist) return;
    await _load();
  }

  Student? studentById(String id) {
    for (final s in _students) {
      if (s.id == id) return s;
    }
    return null;
  }

  RecitationSession? sessionById(String id) {
    for (final s in _sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  int totalPointsForStudent(String studentId) {
    var sum = 0;
    for (final e in _ledger) {
      if (e.studentId == studentId) sum += e.points;
    }
    return sum;
  }

  List<PointLedgerEntry> ledgerForStudent(String studentId) {
    final list =
        _ledger.where((e) => e.studentId == studentId).toList(growable: false);
    list.sort((a, b) => b.earnedAt.compareTo(a.earnedAt));
    return list;
  }

  // ---------------------------------------------------------------- students

  Future<void> addStudent(String name) async {
    final student = Student(id: _uuid.v4(), name: name.trim());
    _students.add(student);
    for (final session in _sessions) {
      session.studentStates[student.id] = StudentSessionState(
        studentId: student.id,
      );
    }
    await _save();
    notifyListeners();
  }

  Future<void> updateStudent(String id, String name) async {
    final student = studentById(id);
    if (student == null) return;
    student.name = name.trim();
    await _save();
    notifyListeners();
  }

  Future<void> deleteStudent(String id) async {
    _students.removeWhere((s) => s.id == id);
    for (final session in _sessions) {
      session.studentStates.remove(id);
      if (session.pendingStudentId == id) {
        session.pendingStudentId = null;
      }
    }
    await _save();
    notifyListeners();
  }

  // ---------------------------------------------------------------- sessions

  /// Students who were not called in the most recent session. They get
  /// priority when the next session is created.
  List<Student> studentsMissedInLatestSession() {
    if (_sessions.isEmpty) return const [];
    final latest = _sessions.last;
    return _students.where((s) {
      final state = latest.studentStates[s.id];
      return state != null &&
          (state.outcome == CallOutcome.notCalled ||
              state.outcome == CallOutcome.pending);
    }).toList(growable: false);
  }

  Future<RecitationSession> addSession({
    required String name,
    required int pointsPerAnswer,
    required int pointsRequiredForReward,
    required String rewardLabel,
    required bool allowRecallUnanswered,
    required bool allowRecallAnswered,
  }) async {
    final previous = _sessions.isEmpty ? null : _sessions.last;
    final missed = studentsMissedInLatestSession().map((s) => s.id).toSet();

    final states = <String, StudentSessionState>{};
    for (final student in _students) {
      states[student.id] = StudentSessionState(
        studentId: student.id,
        priority: missed.contains(student.id),
      );
    }
    final session = RecitationSession(
      id: _uuid.v4(),
      name: name.trim(),
      pointsPerAnswer: pointsPerAnswer,
      pointsRequiredForReward: pointsRequiredForReward,
      rewardLabel: rewardLabel.trim(),
      allowRecallUnanswered: allowRecallUnanswered,
      allowRecallAnswered: allowRecallAnswered,
      studentStates: states,
      createdAt: DateTime.now(),
      previousSessionName: missed.isEmpty ? null : previous?.name,
    );
    _sessions.add(session);
    await _save();
    notifyListeners();
    return session;
  }

  Future<void> updateSession(
    String sessionId, {
    required String name,
    required int pointsPerAnswer,
    required int pointsRequiredForReward,
    required String rewardLabel,
    required bool allowRecallUnanswered,
    required bool allowRecallAnswered,
  }) async {
    final session = sessionById(sessionId);
    if (session == null) return;
    session
      ..name = name.trim()
      ..pointsPerAnswer = pointsPerAnswer
      ..pointsRequiredForReward = pointsRequiredForReward
      ..rewardLabel = rewardLabel.trim()
      ..allowRecallUnanswered = allowRecallUnanswered
      ..allowRecallAnswered = allowRecallAnswered;
    await _save();
    notifyListeners();
  }

  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    await _save();
    notifyListeners();
  }

  // ----------------------------------------------------------------- calling

  /// Priority = missed last session and still waiting in this one.
  bool isPriority(RecitationSession session, String studentId) {
    final state = session.studentStates[studentId];
    return state != null &&
        state.priority &&
        state.outcome == CallOutcome.notCalled;
  }

  int pickWeightForStudent(RecitationSession session, Student student) {
    if (session.pendingStudentId != null) return 0;
    final state = session.studentStates[student.id];
    if (state == null || state.outcome == CallOutcome.pending) return 0;
    return switch (state.outcome) {
      CallOutcome.notCalled => primaryPickWeight,
      CallOutcome.notAnswered =>
        session.allowRecallUnanswered ? primaryPickWeight : 0,
      CallOutcome.answered =>
        session.allowRecallAnswered ? answeredRecallPickWeight : 0,
      CallOutcome.pending => 0,
    };
  }

  bool hasCallableStudents(RecitationSession session) {
    if (session.pendingStudentId != null) return false;
    for (final student in _students) {
      if (pickWeightForStudent(session, student) > 0) return true;
    }
    return false;
  }

  List<Student> eligibleStudents(RecitationSession session) {
    return _students
        .where((s) => pickWeightForStudent(session, s) > 0)
        .toList(growable: false);
  }

  int calledCount(RecitationSession session) {
    var n = 0;
    for (final student in _students) {
      final outcome = session.studentStates[student.id]?.outcome;
      if (outcome == CallOutcome.answered ||
          outcome == CallOutcome.notAnswered) {
        n++;
      }
    }
    return n;
  }

  int priorityWaitingCount(RecitationSession session) =>
      _students.where((s) => isPriority(session, s.id)).length;

  /// Students the next random pick chooses from, with their weights.
  /// Students who missed the previous session always come first.
  Map<Student, int> pickPool(RecitationSession session) {
    if (session.pendingStudentId != null) return const {};
    final weights = <Student, int>{};
    for (final student in _students) {
      final w = pickWeightForStudent(session, student);
      if (w > 0) weights[student] = w;
    }
    final priority =
        weights.keys.where((s) => isPriority(session, s.id)).toList();
    return priority.isNotEmpty ? {for (final s in priority) s: 1} : weights;
  }

  /// Picks the next student at random from [pickPool].
  Future<String?> pickRandomStudent(RecitationSession session) async {
    final pool = pickPool(session);
    if (pool.isEmpty) return null;

    final total = pool.values.fold<int>(0, (a, b) => a + b);
    var roll = Random().nextInt(total);
    Student? picked;
    for (final entry in pool.entries) {
      roll -= entry.value;
      if (roll < 0) {
        picked = entry.key;
        break;
      }
    }
    picked ??= pool.keys.first;

    return await _beginCall(session, picked.id) ? picked.id : null;
  }

  /// The teacher calls a specific student, regardless of recall rules.
  Future<bool> callStudent(RecitationSession session, String studentId) =>
      _beginCall(session, studentId);

  Future<bool> _beginCall(RecitationSession session, String studentId) async {
    if (session.pendingStudentId != null) return false;
    final state = session.studentStates[studentId];
    if (state == null) return false;
    state.outcomeBeforeCall = state.outcome;
    state.outcome = CallOutcome.pending;
    session.pendingStudentId = studentId;
    await _save();
    notifyListeners();
    return true;
  }

  /// Undo for skip / didn't answer: puts [studentId] back into "being
  /// called", remembering [before] as the outcome to return to if skipped
  /// again. Returns false if another call is already in progress.
  Future<bool> reopenCall(
    RecitationSession session,
    String studentId, {
    required CallOutcome before,
  }) async {
    if (session.pendingStudentId != null) return false;
    final state = session.studentStates[studentId];
    if (state == null) return false;
    state.outcome = CallOutcome.pending;
    state.outcomeBeforeCall = before;
    session.pendingStudentId = studentId;
    await _save();
    notifyListeners();
    return true;
  }

  /// The teacher decides this student does not answer now. They go back to
  /// where they were, so a waiting student stays in the queue (and keeps
  /// priority for the next session if never called).
  Future<void> skipCall(RecitationSession session) async {
    final id = session.pendingStudentId;
    if (id == null) return;
    final state = session.studentStates[id];
    if (state != null) {
      state.outcome = state.outcomeBeforeCall ?? CallOutcome.notCalled;
      state.outcomeBeforeCall = null;
    }
    session.pendingStudentId = null;
    await _save();
    notifyListeners();
  }

  /// Records an answer. [points] is the score the teacher gives; it defaults
  /// to the session's points per answer.
  Future<void> markAnswered(RecitationSession session, {int? points}) async {
    final id = session.pendingStudentId;
    if (id == null) return;
    final state = session.studentStates[id];
    if (state == null) return;
    final awarded =
        (points ?? session.pointsPerAnswer).clamp(0, maxPointsPerCall);
    if (state.rewardClaimed) {
      // Starting toward a new reward after a previous claim.
      state.rewardClaimed = false;
      state.pointsEarned = 0;
    }
    state.outcome = CallOutcome.answered;
    state.outcomeBeforeCall = null;
    state.pointsEarned += awarded;
    session.pendingStudentId = null;
    await _save();
    notifyListeners();
  }

  Future<void> markNotAnswered(RecitationSession session) async {
    final id = session.pendingStudentId;
    if (id == null) return;
    final state = session.studentStates[id];
    if (state == null) return;
    state.outcome = CallOutcome.notAnswered;
    state.outcomeBeforeCall = null;
    session.pendingStudentId = null;
    await _save();
    notifyListeners();
  }

  // ----------------------------------------------------------------- rewards

  bool canClaimReward(RecitationSession session, String studentId) {
    final state = session.studentStates[studentId];
    if (state == null || state.rewardClaimed) return false;
    if (state.outcome != CallOutcome.answered) return false;
    return state.pointsEarned >= session.pointsRequiredForReward;
  }

  int pointsUntilClaim(RecitationSession session, String studentId) {
    final state = session.studentStates[studentId];
    if (state == null) return session.pointsRequiredForReward;
    return (session.pointsRequiredForReward - state.pointsEarned)
        .clamp(0, session.pointsRequiredForReward);
  }

  /// Number of sessions where [studentId] has a reward ready to hand out.
  int claimableRewardCount(String studentId) =>
      _sessions.where((s) => canClaimReward(s, studentId)).length;

  /// Gives the reward. The teacher may change what the reward is with
  /// [rewardLabel]; otherwise the session's reward is used.
  Future<bool> claimReward(
    RecitationSession session,
    String studentId, {
    String? rewardLabel,
  }) async {
    final state = session.studentStates[studentId];
    if (state == null || !canClaimReward(session, studentId)) return false;

    final label = rewardLabel?.trim();
    final payout = state.pointsEarned;
    state.rewardClaimed = true;
    state.pointsEarned = 0;
    _ledger.add(
      PointLedgerEntry(
        id: _uuid.v4(),
        studentId: studentId,
        sessionId: session.id,
        sessionName: session.name,
        points: payout,
        rewardLabel:
            (label == null || label.isEmpty) ? session.rewardLabel : label,
        earnedAt: DateTime.now(),
      ),
    );
    await _save();
    notifyListeners();
    return true;
  }

  // --------------------------------------------------------------- storage

  Future<File> _dataFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/recitro_data.json');
  }

  Future<void> _load() async {
    final file = await _dataFile();
    if (!await file.exists()) return;
    final raw = await file.readAsString();
    if (raw.isEmpty) return;
    final data = jsonDecode(raw) as Map<String, dynamic>;
    _students
      ..clear()
      ..addAll(
        (data['students'] as List<dynamic>? ?? [])
            .map((e) => Student.fromJson(e as Map<String, dynamic>)),
      );
    _sessions
      ..clear()
      ..addAll(
        (data['sessions'] as List<dynamic>? ?? [])
            .map((e) => RecitationSession.fromJson(e as Map<String, dynamic>)),
      );
    _ledger
      ..clear()
      ..addAll(
        (data['ledger'] as List<dynamic>? ?? [])
            .map((e) => PointLedgerEntry.fromJson(e as Map<String, dynamic>)),
      );
  }

  Future<void> _save() async {
    if (!persist) return;
    final file = await _dataFile();
    final payload = jsonEncode({
      'students': _students.map((s) => s.toJson()).toList(),
      'sessions': _sessions.map((s) => s.toJson()).toList(),
      'ledger': _ledger.map((e) => e.toJson()).toList(),
    });
    await file.writeAsString(payload);
  }
}
