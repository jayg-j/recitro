import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/call_outcome.dart';
import '../models/course.dart';
import '../models/point_ledger_entry.dart';
import '../models/recitation_session.dart';
import '../models/student.dart';
import '../models/student_session_state.dart';
import 'name_list.dart';

class RecitroStore extends ChangeNotifier {
  RecitroStore({this.persist = true});

  /// Tests can turn off disk reads and writes.
  final bool persist;

  static const _uuid = Uuid();
  static const int primaryPickWeight = 10;
  static const int answeredRecallPickWeight = 2;
  static const int maxPointsPerCall = 999;

  /// Name of the course created for data saved before courses existed, and
  /// for callers that don't pick a course.
  static const defaultCourseName = 'My class';

  final List<Course> _courses = [];
  final List<Student> _students = [];
  final List<RecitationSession> _sessions = [];
  final List<PointLedgerEntry> _ledger = [];

  List<Course> get courses => List.unmodifiable(_courses);

  /// All students across courses.
  List<Student> get students => List.unmodifiable(_students);

  /// Sessions in creation order (oldest first).
  List<RecitationSession> get sessions => List.unmodifiable(_sessions);
  List<PointLedgerEntry> get ledger => List.unmodifiable(_ledger);

  Future<void> init() async {
    if (!persist) return;
    await _load();
  }

  Course? courseById(String id) {
    for (final c in _courses) {
      if (c.id == id) return c;
    }
    return null;
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

  /// Students in [courseId], in the order they were added.
  List<Student> studentsInCourse(String courseId) =>
      _students.where((s) => s.courseId == courseId).toList(growable: false);

  /// Students taking part in [session] (its course's students).
  List<Student> studentsFor(RecitationSession session) =>
      studentsInCourse(session.courseId);

  List<RecitationSession> sessionsInCourse(String courseId) =>
      _sessions.where((s) => s.courseId == courseId).toList(growable: false);

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

  // ----------------------------------------------------------------- courses

  Future<Course> addCourse(String name, {List<String> subjects = const []}) {
    final course = _newCourse(name, subjects: subjects);
    return _save().then((_) {
      notifyListeners();
      return course;
    });
  }

  Course _newCourse(String name, {List<String> subjects = const []}) {
    final course = Course(
      id: _uuid.v4(),
      name: name.trim(),
      subjects: _cleanSubjects(subjects),
    );
    _courses.add(course);
    return course;
  }

  /// Finds a course by name (case-insensitive) or creates it.
  Future<Course> courseNamed(String name) async {
    final key = nameKey(name);
    for (final c in _courses) {
      if (nameKey(c.name) == key) return c;
    }
    return addCourse(name);
  }

  Future<void> renameCourse(String courseId, String name) async {
    final course = courseById(courseId);
    if (course == null || name.trim().isEmpty) return;
    course.name = name.trim();
    await _save();
    notifyListeners();
  }

  /// Deletes a course with its students and sessions. Rewards already given
  /// stay in the ledger.
  Future<void> deleteCourse(String courseId) async {
    _courses.removeWhere((c) => c.id == courseId);
    _students.removeWhere((s) => s.courseId == courseId);
    _sessions.removeWhere((s) => s.courseId == courseId);
    await _save();
    notifyListeners();
  }

  Future<void> addSubject(String courseId, String subject) async {
    final course = courseById(courseId);
    final name = subject.trim();
    if (course == null || name.isEmpty) return;
    if (course.subjects.any((s) => nameKey(s) == nameKey(name))) return;
    course.subjects.add(name);
    await _save();
    notifyListeners();
  }

  /// Renames a subject in its course and in that course's sessions.
  Future<void> renameSubject(String courseId, String from, String to) async {
    final course = courseById(courseId);
    final name = to.trim();
    if (course == null || name.isEmpty) return;
    final i = course.subjects.indexOf(from);
    if (i < 0) return;
    course.subjects[i] = name;
    for (final s in _sessions) {
      if (s.courseId == courseId && s.subject == from) s.subject = name;
    }
    await _save();
    notifyListeners();
  }

  /// Removes a subject from the course's list. Past sessions keep it.
  Future<void> removeSubject(String courseId, String subject) async {
    final course = courseById(courseId);
    if (course == null) return;
    course.subjects.remove(subject);
    await _save();
    notifyListeners();
  }

  static List<String> _cleanSubjects(Iterable<String> subjects) {
    final seen = <String>{};
    final out = <String>[];
    for (final s in subjects) {
      final name = s.trim();
      if (name.isEmpty || !seen.add(nameKey(name))) continue;
      out.add(name);
    }
    return out;
  }

  /// The course used when a caller doesn't name one: the only course, or a
  /// "My class" course created on demand.
  Course _defaultCourse() {
    if (_courses.isNotEmpty) return _courses.first;
    return _newCourse(defaultCourseName);
  }

  // ---------------------------------------------------------------- students

  Future<void> addStudent(String name, {String? courseId}) =>
      addStudents([name], courseId: courseId);

  /// Adds several students to a course at once (one save), e.g. from a
  /// pasted list.
  Future<void> addStudents(Iterable<String> names, {String? courseId}) async {
    final course =
        (courseId == null ? null : courseById(courseId)) ?? _defaultCourse();
    var added = false;
    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      final student = Student(
        id: _uuid.v4(),
        name: name,
        courseId: course.id,
      );
      _students.add(student);
      for (final session in _sessions) {
        if (session.courseId != course.id) continue;
        session.studentStates[student.id] =
            StudentSessionState(studentId: student.id);
      }
      added = true;
    }
    if (!added) return;
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

  /// The most recent session for the same course and subject.
  RecitationSession? latestSession(String courseId, String subject) {
    for (final s in _sessions.reversed) {
      if (s.courseId == courseId && nameKey(s.subject) == nameKey(subject)) {
        return s;
      }
    }
    return null;
  }

  /// Students not called in the latest session of this course and subject.
  /// They get priority when the next one is created.
  List<Student> studentsMissedInLatestSession(
    String courseId, [
    String subject = '',
  ]) {
    final latest = latestSession(courseId, subject);
    if (latest == null) return const [];
    return studentsInCourse(courseId).where((s) {
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
    String? courseId,
    String subject = '',
  }) async {
    final course =
        (courseId == null ? null : courseById(courseId)) ?? _defaultCourse();
    final subjectName = subject.trim();
    if (subjectName.isNotEmpty &&
        !course.subjects.any((s) => nameKey(s) == nameKey(subjectName))) {
      course.subjects.add(subjectName);
    }
    final previous = latestSession(course.id, subjectName);
    final missed = studentsMissedInLatestSession(course.id, subjectName)
        .map((s) => s.id)
        .toSet();

    final states = <String, StudentSessionState>{};
    for (final student in studentsInCourse(course.id)) {
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
      courseId: course.id,
      subject: subjectName,
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
    String? subject,
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
    if (subject != null) {
      session.subject = subject.trim();
      final course = courseById(session.courseId);
      if (course != null &&
          session.subject.isNotEmpty &&
          !course.subjects
              .any((s) => nameKey(s) == nameKey(session.subject))) {
        course.subjects.add(session.subject);
      }
    }
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
    for (final student in studentsFor(session)) {
      if (pickWeightForStudent(session, student) > 0) return true;
    }
    return false;
  }

  List<Student> eligibleStudents(RecitationSession session) {
    return studentsFor(session)
        .where((s) => pickWeightForStudent(session, s) > 0)
        .toList(growable: false);
  }

  int calledCount(RecitationSession session) {
    var n = 0;
    for (final student in studentsFor(session)) {
      final outcome = session.studentStates[student.id]?.outcome;
      if (outcome == CallOutcome.answered ||
          outcome == CallOutcome.notAnswered) {
        n++;
      }
    }
    return n;
  }

  int priorityWaitingCount(RecitationSession session) =>
      studentsFor(session).where((s) => isPriority(session, s.id)).length;

  /// Students the next random pick chooses from, with their weights.
  /// Students who missed the previous session always come first.
  Map<Student, int> pickPool(RecitationSession session) {
    if (session.pendingStudentId != null) return const {};
    final weights = <Student, int>{};
    for (final student in studentsFor(session)) {
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
    _courses
      ..clear()
      ..addAll(
        (data['courses'] as List<dynamic>? ?? [])
            .map((e) => Course.fromJson(e as Map<String, dynamic>)),
      );
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
    if (_migrateToCourses()) await _save();
  }

  /// Data saved before courses existed has students and sessions without a
  /// course. Put them all in one "My class" course so nothing is lost.
  /// Returns true if anything changed.
  bool _migrateToCourses() {
    final orphanStudents = _students.where(
      (s) => s.courseId.isEmpty || courseById(s.courseId) == null,
    );
    final orphanSessions = _sessions.where(
      (s) => s.courseId.isEmpty || courseById(s.courseId) == null,
    );
    if (orphanStudents.isEmpty && orphanSessions.isEmpty) return false;
    final course = _defaultCourse();
    for (final s in orphanStudents.toList()) {
      s.courseId = course.id;
    }
    for (final s in orphanSessions.toList()) {
      s.courseId = course.id;
    }
    return true;
  }

  Future<void> _save() async {
    if (!persist) return;
    final file = await _dataFile();
    final payload = jsonEncode({
      'courses': _courses.map((c) => c.toJson()).toList(),
      'students': _students.map((s) => s.toJson()).toList(),
      'sessions': _sessions.map((s) => s.toJson()).toList(),
      'ledger': _ledger.map((e) => e.toJson()).toList(),
    });
    await file.writeAsString(payload);
  }
}
