// Leaderboard models for cross and algorithm competitions

import 'package:cubelab/data/models/algorithm.dart';

class LeaderboardEntry {
  final int rank;
  final String userId;
  final String username;
  final int value;
  final double? secondaryValue;
  final bool isCurrentUser;

  const LeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.username,
    required this.value,
    this.secondaryValue,
    this.isCurrentUser = false,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      rank: json['rank'] as int,
      userId: json['userId'] as String,
      username: json['username'] as String? ?? 'Anonymous',
      value: json['value'] as int,
      secondaryValue: (json['secondaryValue'] as num?)?.toDouble(),
      isCurrentUser: json['isCurrentUser'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rank': rank,
      'userId': userId,
      'username': username,
      'value': value,
      'secondaryValue': secondaryValue,
      'isCurrentUser': isCurrentUser,
    };
  }

  factory LeaderboardEntry.fromSupabase(
    Map<String, dynamic> map,
    int rank, {
    String valueKey = 'avg_time_ms',
    bool isCurrentUser = false,
  }) {
    return LeaderboardEntry(
      rank: rank,
      userId: map['user_id'] as String,
      username: map['username'] as String? ?? 'Anonymous',
      value: map[valueKey] as int,
      secondaryValue: map['success_rate'] != null
          ? (map['success_rate'] as num).toDouble()
          : null,
      isCurrentUser: isCurrentUser,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'user_id': userId,
      'username': username,
      'avg_time_ms': value,
      'success_rate': secondaryValue,
    };
  }

  LeaderboardEntry copyWith({
    int? rank,
    String? userId,
    String? username,
    int? value,
    double? secondaryValue,
    bool? isCurrentUser,
  }) {
    return LeaderboardEntry(
      rank: rank ?? this.rank,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      value: value ?? this.value,
      secondaryValue: secondaryValue ?? this.secondaryValue,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaderboardEntry &&
          runtimeType == other.runtimeType &&
          rank == other.rank &&
          userId == other.userId;

  @override
  int get hashCode => Object.hash(rank, userId);
}

class CrossLeaderboard {
  final int level;
  final DateTime lastUpdated;
  final List<LeaderboardEntry> entries;

  const CrossLeaderboard({
    required this.level,
    required this.lastUpdated,
    required this.entries,
  });

  factory CrossLeaderboard.fromJson(Map<String, dynamic> json) {
    return CrossLeaderboard(
      level: json['level'] as int,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) =>
                  LeaderboardEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'level': level,
      'lastUpdated': lastUpdated.toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
    };
  }

  factory CrossLeaderboard.fromSupabase(Map<String, dynamic> map) {
    return CrossLeaderboard(
      level: map['level'] as int,
      lastUpdated: DateTime.parse(map['last_updated'] as String),
      entries: (map['entries'] as List<dynamic>?)
              ?.map((e) => LeaderboardEntry.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'level': level,
      'last_updated': lastUpdated.toIso8601String(),
      'entries': entries.map((e) => e.toSupabase()).toList(),
    };
  }

  CrossLeaderboard copyWith({
    int? level,
    DateTime? lastUpdated,
    List<LeaderboardEntry>? entries,
  }) {
    return CrossLeaderboard(
      level: level ?? this.level,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      entries: entries ?? this.entries,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CrossLeaderboard &&
          runtimeType == other.runtimeType &&
          level == other.level;

  @override
  int get hashCode => level.hashCode;
}

class AlgorithmLeaderboard {
  final AlgorithmSet? set;
  final String type;
  final DateTime lastUpdated;
  final List<LeaderboardEntry> entries;

  const AlgorithmLeaderboard({
    this.set,
    required this.type,
    required this.lastUpdated,
    required this.entries,
  });

  factory AlgorithmLeaderboard.fromJson(Map<String, dynamic> json) {
    return AlgorithmLeaderboard(
      set: json['set'] != null
          ? AlgorithmSetExtension.fromString(json['set'] as String)
          : null,
      type: json['type'] as String,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      entries: (json['entries'] as List<dynamic>?)
              ?.map((e) =>
                  LeaderboardEntry.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'set': set?.name,
      'type': type,
      'lastUpdated': lastUpdated.toIso8601String(),
      'entries': entries.map((e) => e.toJson()).toList(),
    };
  }

  factory AlgorithmLeaderboard.fromSupabase(Map<String, dynamic> map) {
    return AlgorithmLeaderboard(
      set: map['set_type'] != null
          ? AlgorithmSetExtension.fromString(map['set_type'] as String)
          : null,
      type: map['board_type'] as String,
      lastUpdated: DateTime.parse(map['last_updated'] as String),
      entries: (map['entries'] as List<dynamic>?)
              ?.map((e) => LeaderboardEntry.fromJson(
                  e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'set_type': set?.name,
      'board_type': type,
      'last_updated': lastUpdated.toIso8601String(),
      'entries': entries.map((e) => e.toSupabase()).toList(),
    };
  }

  AlgorithmLeaderboard copyWith({
    AlgorithmSet? set,
    String? type,
    DateTime? lastUpdated,
    List<LeaderboardEntry>? entries,
  }) {
    return AlgorithmLeaderboard(
      set: set ?? this.set,
      type: type ?? this.type,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      entries: entries ?? this.entries,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlgorithmLeaderboard &&
          runtimeType == other.runtimeType &&
          set == other.set &&
          type == other.type;

  @override
  int get hashCode => Object.hash(set, type);
}
