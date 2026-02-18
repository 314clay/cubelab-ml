// Algorithm model and AlgorithmSet enum

enum AlgorithmSet {
  oll,
  pll,
  coll,
  zbll,
  ollcp,
  f2l,
  wv,
}

extension AlgorithmSetExtension on AlgorithmSet {
  static AlgorithmSet fromString(String value) {
    switch (value.toLowerCase()) {
      case 'oll':
        return AlgorithmSet.oll;
      case 'pll':
        return AlgorithmSet.pll;
      case 'coll':
        return AlgorithmSet.coll;
      case 'zbll':
        return AlgorithmSet.zbll;
      case 'ollcp':
        return AlgorithmSet.ollcp;
      case 'f2l':
        return AlgorithmSet.f2l;
      case 'wv':
        return AlgorithmSet.wv;
      default:
        return AlgorithmSet.oll;
    }
  }
}

class Algorithm {
  final String id;
  final AlgorithmSet set;
  final String? subset;
  final String? subSubset;
  final String name;
  final List<String> defaultAlgs;
  final String? scrambleSetup;
  final String? imageUrl;

  const Algorithm({
    required this.id,
    required this.set,
    this.subset,
    this.subSubset,
    required this.name,
    required this.defaultAlgs,
    this.scrambleSetup,
    this.imageUrl,
  });

  factory Algorithm.fromJson(Map<String, dynamic> json) {
    return Algorithm(
      id: json['id'] as String,
      set: AlgorithmSetExtension.fromString(json['set'] as String),
      subset: json['subset'] as String?,
      subSubset: json['subSubset'] as String?,
      name: json['name'] as String,
      defaultAlgs: (json['defaultAlgs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      scrambleSetup: json['scrambleSetup'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'set': set.name,
      'subset': subset,
      'subSubset': subSubset,
      'name': name,
      'defaultAlgs': defaultAlgs,
      'scrambleSetup': scrambleSetup,
      'imageUrl': imageUrl,
    };
  }

  factory Algorithm.fromSupabase(Map<String, dynamic> json) {
    return Algorithm(
      id: json['id'] as String,
      set: AlgorithmSetExtension.fromString(json['set'] as String),
      subset: json['subset'] as String?,
      subSubset: json['sub_subset'] as String?,
      name: json['name'] as String,
      defaultAlgs: (json['default_algs'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      scrambleSetup: json['scramble_setup'] as String?,
      imageUrl: json['image_url'] as String?,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'set': set.name,
      'subset': subset,
      'sub_subset': subSubset,
      'name': name,
      'default_algs': defaultAlgs,
      'scramble_setup': scrambleSetup,
      'image_url': imageUrl,
    };
  }

  Algorithm copyWith({
    String? id,
    AlgorithmSet? set,
    String? subset,
    String? subSubset,
    String? name,
    List<String>? defaultAlgs,
    String? scrambleSetup,
    String? imageUrl,
  }) {
    return Algorithm(
      id: id ?? this.id,
      set: set ?? this.set,
      subset: subset ?? this.subset,
      subSubset: subSubset ?? this.subSubset,
      name: name ?? this.name,
      defaultAlgs: defaultAlgs ?? this.defaultAlgs,
      scrambleSetup: scrambleSetup ?? this.scrambleSetup,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Algorithm &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
