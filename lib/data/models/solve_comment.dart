// Solve comment model for community discussion on daily solves

class SolveComment {
  final String id;
  final String solveId;
  final String userId;
  final String username;
  final String content;
  final DateTime createdAt;

  const SolveComment({
    required this.id,
    required this.solveId,
    required this.userId,
    required this.username,
    required this.content,
    required this.createdAt,
  });

  factory SolveComment.fromJson(Map<String, dynamic> json) {
    return SolveComment(
      id: json['id'] as String,
      solveId: json['solveId'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'solveId': solveId,
      'userId': userId,
      'username': username,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SolveComment.fromSupabase(Map<String, dynamic> map) {
    return SolveComment(
      id: map['id'] as String,
      solveId: map['solve_id'] as String,
      userId: map['user_id'] as String,
      username: map['username'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'solve_id': solveId,
      'user_id': userId,
      'username': username,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }

  SolveComment copyWith({
    String? id,
    String? solveId,
    String? userId,
    String? username,
    String? content,
    DateTime? createdAt,
  }) {
    return SolveComment(
      id: id ?? this.id,
      solveId: solveId ?? this.solveId,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SolveComment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
