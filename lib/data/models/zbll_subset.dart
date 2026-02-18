// ZBLL subset and structure models for algorithm catalog organization

class ZBLLSubset {
  final String name;
  final int caseCount;
  final String? imageUrl;

  const ZBLLSubset({
    required this.name,
    required this.caseCount,
    this.imageUrl,
  });

  factory ZBLLSubset.fromJson(Map<String, dynamic> json) {
    return ZBLLSubset(
      name: json['name'] as String,
      caseCount: json['caseCount'] as int,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'caseCount': caseCount,
      'imageUrl': imageUrl,
    };
  }

  factory ZBLLSubset.fromSupabase(Map<String, dynamic> map) {
    return ZBLLSubset(
      name: map['name'] as String,
      caseCount: map['case_count'] as int,
      imageUrl: map['image_url'] as String?,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'name': name,
      'case_count': caseCount,
      'image_url': imageUrl,
    };
  }

  ZBLLSubset copyWith({
    String? name,
    int? caseCount,
    String? imageUrl,
  }) {
    return ZBLLSubset(
      name: name ?? this.name,
      caseCount: caseCount ?? this.caseCount,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZBLLSubset &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

class ZBLLStructure {
  final List<ZBLLSubset> subsets;
  final int totalCases;

  const ZBLLStructure({
    required this.subsets,
    required this.totalCases,
  });

  factory ZBLLStructure.fromJson(Map<String, dynamic> json) {
    return ZBLLStructure(
      subsets: (json['subsets'] as List<dynamic>?)
              ?.map(
                  (e) => ZBLLSubset.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalCases: json['totalCases'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'subsets': subsets.map((s) => s.toJson()).toList(),
      'totalCases': totalCases,
    };
  }

  factory ZBLLStructure.fromSupabase(Map<String, dynamic> map) {
    return ZBLLStructure(
      subsets: (map['subsets'] as List<dynamic>?)
              ?.map(
                  (e) => ZBLLSubset.fromSupabase(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalCases: map['total_cases'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'subsets': subsets.map((s) => s.toSupabase()).toList(),
      'total_cases': totalCases,
    };
  }

  ZBLLStructure copyWith({
    List<ZBLLSubset>? subsets,
    int? totalCases,
  }) {
    return ZBLLStructure(
      subsets: subsets ?? this.subsets,
      totalCases: totalCases ?? this.totalCases,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZBLLStructure &&
          runtimeType == other.runtimeType &&
          totalCases == other.totalCases;

  @override
  int get hashCode => totalCases.hashCode;
}
