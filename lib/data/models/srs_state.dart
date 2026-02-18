// SRS (Spaced Repetition System) state and related enums

enum SRSCardState {
  newCard,
  learning,
  review,
  relearning,
}

extension SRSCardStateExtension on SRSCardState {
  String get jsonValue {
    switch (this) {
      case SRSCardState.newCard:
        return 'new';
      case SRSCardState.learning:
        return 'learning';
      case SRSCardState.review:
        return 'review';
      case SRSCardState.relearning:
        return 'relearning';
    }
  }

  static SRSCardState fromString(String value) {
    switch (value) {
      case 'new':
        return SRSCardState.newCard;
      case 'learning':
        return SRSCardState.learning;
      case 'review':
        return SRSCardState.review;
      case 'relearning':
        return SRSCardState.relearning;
      default:
        return SRSCardState.newCard;
    }
  }
}

enum SRSRating {
  again,
  hard,
  good,
  easy,
}

extension ReviewRatingExtension on SRSRating {
  static SRSRating fromString(String value) {
    switch (value) {
      case 'again':
        return SRSRating.again;
      case 'hard':
        return SRSRating.hard;
      case 'good':
        return SRSRating.good;
      case 'easy':
        return SRSRating.easy;
      default:
        return SRSRating.good;
    }
  }
}

class SRSState {
  final double easeFactor;
  final int interval;
  final int repetitions;
  final DateTime? nextReviewDate;
  final double stability;
  final double difficulty;
  final double desiredRetention;
  final SRSCardState cardState;
  final int? remainingSteps;
  final DateTime? learningDueAt;
  final int lapses;
  final DateTime? lastReviewedAt;

  const SRSState({
    this.easeFactor = 2.5,
    this.interval = 0,
    this.repetitions = 0,
    this.nextReviewDate,
    this.stability = 0,
    this.difficulty = 5.0,
    this.desiredRetention = 0.9,
    this.cardState = SRSCardState.newCard,
    this.remainingSteps,
    this.learningDueAt,
    this.lapses = 0,
    this.lastReviewedAt,
  });

  factory SRSState.initial() {
    return const SRSState();
  }

  factory SRSState.fromJson(Map<String, dynamic> json) {
    return SRSState(
      easeFactor: (json['easeFactor'] as num?)?.toDouble() ?? 2.5,
      interval: json['interval'] as int? ?? 0,
      repetitions: json['repetitions'] as int? ?? 0,
      nextReviewDate: json['nextReviewDate'] != null
          ? DateTime.parse(json['nextReviewDate'] as String)
          : null,
      stability: (json['stability'] as num?)?.toDouble() ?? 0,
      difficulty: (json['difficulty'] as num?)?.toDouble() ?? 5.0,
      desiredRetention: (json['desiredRetention'] as num?)?.toDouble() ?? 0.9,
      cardState: json['cardState'] != null
          ? SRSCardStateExtension.fromString(json['cardState'] as String)
          : SRSCardState.newCard,
      remainingSteps: json['remainingSteps'] as int?,
      learningDueAt: json['learningDueAt'] != null
          ? DateTime.parse(json['learningDueAt'] as String)
          : null,
      lapses: json['lapses'] as int? ?? 0,
      lastReviewedAt: json['lastReviewedAt'] != null
          ? DateTime.parse(json['lastReviewedAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'easeFactor': easeFactor,
      'interval': interval,
      'repetitions': repetitions,
      'nextReviewDate': nextReviewDate?.toIso8601String(),
      'stability': stability,
      'difficulty': difficulty,
      'desiredRetention': desiredRetention,
      'cardState': cardState.jsonValue,
      'remainingSteps': remainingSteps,
      'learningDueAt': learningDueAt?.toIso8601String(),
      'lapses': lapses,
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
    };
  }

  factory SRSState.fromSupabase(Map<String, dynamic> json) {
    return SRSState(
      easeFactor: (json['ease_factor'] as num?)?.toDouble() ?? 2.5,
      interval: json['interval_days'] as int? ?? 0,
      repetitions: json['repetitions'] as int? ?? 0,
      nextReviewDate: json['next_review_date'] != null
          ? DateTime.parse(json['next_review_date'] as String)
          : null,
      stability: (json['stability'] as num?)?.toDouble() ?? 0,
      difficulty: (json['srs_difficulty'] as num?)?.toDouble() ?? 5.0,
      desiredRetention: (json['desired_retention'] as num?)?.toDouble() ?? 0.9,
      cardState: json['card_state'] != null
          ? SRSCardStateExtension.fromString(json['card_state'] as String)
          : SRSCardState.newCard,
      remainingSteps: json['remaining_steps'] as int?,
      learningDueAt: json['learning_due_at'] != null
          ? DateTime.parse(json['learning_due_at'] as String)
          : null,
      lapses: json['lapses'] as int? ?? 0,
      lastReviewedAt: json['last_reviewed_at'] != null
          ? DateTime.parse(json['last_reviewed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'ease_factor': easeFactor,
      'interval_days': interval,
      'repetitions': repetitions,
      'next_review_date': nextReviewDate?.toIso8601String(),
      'stability': stability,
      'srs_difficulty': difficulty,
      'desired_retention': desiredRetention,
      'card_state': cardState.jsonValue,
      'remaining_steps': remainingSteps,
      'learning_due_at': learningDueAt?.toIso8601String(),
      'lapses': lapses,
      'last_reviewed_at': lastReviewedAt?.toIso8601String(),
    };
  }

  SRSState copyWith({
    double? easeFactor,
    int? interval,
    int? repetitions,
    DateTime? nextReviewDate,
    double? stability,
    double? difficulty,
    double? desiredRetention,
    SRSCardState? cardState,
    int? remainingSteps,
    DateTime? learningDueAt,
    int? lapses,
    DateTime? lastReviewedAt,
  }) {
    return SRSState(
      easeFactor: easeFactor ?? this.easeFactor,
      interval: interval ?? this.interval,
      repetitions: repetitions ?? this.repetitions,
      nextReviewDate: nextReviewDate ?? this.nextReviewDate,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      desiredRetention: desiredRetention ?? this.desiredRetention,
      cardState: cardState ?? this.cardState,
      remainingSteps: remainingSteps ?? this.remainingSteps,
      learningDueAt: learningDueAt ?? this.learningDueAt,
      lapses: lapses ?? this.lapses,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SRSState &&
          runtimeType == other.runtimeType &&
          easeFactor == other.easeFactor &&
          interval == other.interval &&
          repetitions == other.repetitions &&
          nextReviewDate == other.nextReviewDate &&
          cardState == other.cardState &&
          lapses == other.lapses;

  @override
  int get hashCode => Object.hash(
        easeFactor,
        interval,
        repetitions,
        nextReviewDate,
        cardState,
        lapses,
      );
}
