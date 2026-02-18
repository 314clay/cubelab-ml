// User-related models: AppUser, UserSettings, TimerStats, StatsSnapshot

import 'package:cubelab/data/models/algorithm.dart';

class AppUser {
  final String id;
  final String? email;
  final String username;
  final bool isAnonymous;
  final int defaultPairsPlanning;
  final AlgorithmSet? favoritedAlgSet;
  final UserSettings settings;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    this.email,
    required this.username,
    this.isAnonymous = false,
    this.defaultPairsPlanning = 2,
    this.favoritedAlgSet,
    this.settings = const UserSettings(),
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String?,
      username: json['username'] as String? ?? 'Cuber',
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      defaultPairsPlanning: json['defaultPairsPlanning'] as int? ?? 2,
      favoritedAlgSet: json['favoritedAlgSet'] != null
          ? AlgorithmSetExtension.fromString(json['favoritedAlgSet'] as String)
          : null,
      settings: json['settings'] != null
          ? UserSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : const UserSettings(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'isAnonymous': isAnonymous,
      'defaultPairsPlanning': defaultPairsPlanning,
      'favoritedAlgSet': favoritedAlgSet?.name,
      'settings': settings.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromSupabase(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String?,
      username: json['username'] as String? ?? 'Cuber',
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      defaultPairsPlanning: json['default_pairs_planning'] as int? ?? 2,
      favoritedAlgSet: json['favorited_alg_set'] != null
          ? AlgorithmSetExtension.fromString(json['favorited_alg_set'] as String)
          : null,
      settings: json['settings'] != null
          ? UserSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : const UserSettings(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'is_anonymous': isAnonymous,
      'default_pairs_planning': defaultPairsPlanning,
      'favorited_alg_set': favoritedAlgSet?.name,
      'settings': settings.toJson(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppUser copyWith({
    String? id,
    String? email,
    String? username,
    bool? isAnonymous,
    int? defaultPairsPlanning,
    AlgorithmSet? favoritedAlgSet,
    UserSettings? settings,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      username: username ?? this.username,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      defaultPairsPlanning: defaultPairsPlanning ?? this.defaultPairsPlanning,
      favoritedAlgSet: favoritedAlgSet ?? this.favoritedAlgSet,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class UserSettings {
  final bool hapticFeedback;
  final bool showScramblePreview;
  final int inspectionTimeSeconds;
  final bool holdToStart;

  const UserSettings({
    this.hapticFeedback = true,
    this.showScramblePreview = true,
    this.inspectionTimeSeconds = 15,
    this.holdToStart = true,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      hapticFeedback: json['hapticFeedback'] as bool? ?? true,
      showScramblePreview: json['showScramblePreview'] as bool? ?? true,
      inspectionTimeSeconds: json['inspectionTimeSeconds'] as int? ?? 15,
      holdToStart: json['holdToStart'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hapticFeedback': hapticFeedback,
      'showScramblePreview': showScramblePreview,
      'inspectionTimeSeconds': inspectionTimeSeconds,
      'holdToStart': holdToStart,
    };
  }

  factory UserSettings.fromSupabase(Map<String, dynamic> json) {
    return UserSettings(
      hapticFeedback: json['haptic_feedback'] as bool? ?? true,
      showScramblePreview: json['show_scramble_preview'] as bool? ?? true,
      inspectionTimeSeconds: json['inspection_time_seconds'] as int? ?? 15,
      holdToStart: json['hold_to_start'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'haptic_feedback': hapticFeedback,
      'show_scramble_preview': showScramblePreview,
      'inspection_time_seconds': inspectionTimeSeconds,
      'hold_to_start': holdToStart,
    };
  }

  UserSettings copyWith({
    bool? hapticFeedback,
    bool? showScramblePreview,
    int? inspectionTimeSeconds,
    bool? holdToStart,
  }) {
    return UserSettings(
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
      showScramblePreview: showScramblePreview ?? this.showScramblePreview,
      inspectionTimeSeconds: inspectionTimeSeconds ?? this.inspectionTimeSeconds,
      holdToStart: holdToStart ?? this.holdToStart,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettings &&
          runtimeType == other.runtimeType &&
          hapticFeedback == other.hapticFeedback &&
          showScramblePreview == other.showScramblePreview &&
          inspectionTimeSeconds == other.inspectionTimeSeconds &&
          holdToStart == other.holdToStart;

  @override
  int get hashCode => Object.hash(
        hapticFeedback,
        showScramblePreview,
        inspectionTimeSeconds,
        holdToStart,
      );
}

class TimerStats {
  final int? pbSingleMs;
  final int? pbAo5Ms;
  final int? pbAo12Ms;
  final int totalSolves;

  const TimerStats({
    this.pbSingleMs,
    this.pbAo5Ms,
    this.pbAo12Ms,
    this.totalSolves = 0,
  });

  factory TimerStats.fromJson(Map<String, dynamic> json) {
    return TimerStats(
      pbSingleMs: json['pbSingleMs'] as int?,
      pbAo5Ms: json['pbAo5Ms'] as int?,
      pbAo12Ms: json['pbAo12Ms'] as int?,
      totalSolves: json['totalSolves'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pbSingleMs': pbSingleMs,
      'pbAo5Ms': pbAo5Ms,
      'pbAo12Ms': pbAo12Ms,
      'totalSolves': totalSolves,
    };
  }

  factory TimerStats.fromSupabase(Map<String, dynamic> json) {
    return TimerStats(
      pbSingleMs: json['pb_single_ms'] as int?,
      pbAo5Ms: json['pb_ao5_ms'] as int?,
      pbAo12Ms: json['pb_ao12_ms'] as int?,
      totalSolves: json['total_solves'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'pb_single_ms': pbSingleMs,
      'pb_ao5_ms': pbAo5Ms,
      'pb_ao12_ms': pbAo12Ms,
      'total_solves': totalSolves,
    };
  }

  TimerStats copyWith({
    int? pbSingleMs,
    int? pbAo5Ms,
    int? pbAo12Ms,
    int? totalSolves,
  }) {
    return TimerStats(
      pbSingleMs: pbSingleMs ?? this.pbSingleMs,
      pbAo5Ms: pbAo5Ms ?? this.pbAo5Ms,
      pbAo12Ms: pbAo12Ms ?? this.pbAo12Ms,
      totalSolves: totalSolves ?? this.totalSolves,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TimerStats &&
          runtimeType == other.runtimeType &&
          pbSingleMs == other.pbSingleMs &&
          pbAo5Ms == other.pbAo5Ms &&
          pbAo12Ms == other.pbAo12Ms &&
          totalSolves == other.totalSolves;

  @override
  int get hashCode => Object.hash(pbSingleMs, pbAo5Ms, pbAo12Ms, totalSolves);
}

class StatsSnapshot {
  final String id;
  final String userId;
  final DateTime recordedAt;
  final TimerStats timerStats;

  const StatsSnapshot({
    required this.id,
    required this.userId,
    required this.recordedAt,
    required this.timerStats,
  });

  factory StatsSnapshot.fromJson(Map<String, dynamic> json) {
    return StatsSnapshot(
      id: json['id'] as String,
      userId: json['userId'] as String,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      timerStats: json['timerStats'] != null
          ? TimerStats.fromJson(json['timerStats'] as Map<String, dynamic>)
          : const TimerStats(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'recordedAt': recordedAt.toIso8601String(),
      'timerStats': timerStats.toJson(),
    };
  }

  factory StatsSnapshot.fromSupabase(Map<String, dynamic> json) {
    return StatsSnapshot(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      timerStats: TimerStats.fromSupabase(json),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'user_id': userId,
      'recorded_at': recordedAt.toIso8601String(),
      ...timerStats.toSupabase(),
    };
  }

  StatsSnapshot copyWith({
    String? id,
    String? userId,
    DateTime? recordedAt,
    TimerStats? timerStats,
  }) {
    return StatsSnapshot(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      recordedAt: recordedAt ?? this.recordedAt,
      timerStats: timerStats ?? this.timerStats,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StatsSnapshot &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
