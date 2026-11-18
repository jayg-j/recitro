enum CallOutcome {
  notCalled,
  pending,
  answered,
  notAnswered;

  String get label => switch (this) {
        CallOutcome.notCalled => 'Waiting',
        CallOutcome.pending => 'Being called',
        CallOutcome.answered => 'Answered',
        CallOutcome.notAnswered => 'Didn\'t answer',
      };
}
