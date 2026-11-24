
class Workout {
  final String name;
  final double weight;
  final int reps;
  final int sets;

  Workout({
    required this.name,
    required this.weight,
    required this.reps,
    required this.sets,
  });

  factory Workout.fromJson(Map<String, dynamic> json) {
    return Workout(
      name: json['name'] ?? '',
      weight: (json['weight'] ?? 0).toDouble(),
      reps: json['reps'] ?? 0,
      sets: json['sets'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'weight': weight,
      'reps': reps,
      'sets': sets,
    };
  }
}

class Medication {
  final String name;
  final String? time;
  final int quantity;

  Medication({
    required this.name,
    this.time,
    int? quantity,
  }) : quantity = (quantity != null && quantity > 0) ? quantity : 1;

  /// 表示用の文字列（例: "エペリゾン 2錠"）
  String get displayWithQuantity => '$name $quantity錠';

  Medication copyWith({
    String? name,
    String? time,
    int? quantity,
  }) {
    return Medication(
      name: name ?? this.name,
      time: time ?? this.time,
      quantity: quantity ?? this.quantity,
    );
  }

  /// "ロキソニン 2錠", "漢方×3", "エペリゾン" などの入力文字列から薬品名と錠数を解析
  static Medication parseFromInput(String raw, {String? time}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return Medication(name: '', time: time, quantity: 1);
    }

    String toHalfWidthDigits(String s) {
      const full = '０１２３４５６７８９×＊';
      const half = '0123456789×*';
      final sb = StringBuffer();
      for (int i = 0; i < s.length; i++) {
        final idx = full.indexOf(s[i]);
        sb.write(idx != -1 ? half[idx] : s[i]);
      }
      return sb.toString();
    }

    final normalized = toHalfWidthDigits(trimmed);

    // 1. 単位付き (例: "ロキソニン 2錠", "ロキソニン2粒", "漢方 3包", "薬 2個", "薬 2カプセル", "薬 2回")
    final unitMatch = RegExp(
      r'^(.*?)\s*(?:×|x|X|\*)?\s*([0-9]+)\s*(?:錠|粒|包|個|カプセル|回|本|枚)$',
    ).firstMatch(normalized);
    if (unitMatch != null) {
      final parsedName = (unitMatch.group(1) ?? '').trim();
      final parsedQty = int.tryParse(unitMatch.group(2) ?? '') ?? 1;
      return Medication(
        name: parsedName.isNotEmpty ? parsedName : trimmed,
        time: time,
        quantity: parsedQty > 0 ? parsedQty : 1,
      );
    }

    // 2. 掛け算記号付き (例: "漢方×3", "ロキソニン x2")
    final multMatch = RegExp(
      r'^(.*?)\s*(?:×|x|X|\*)\s*([0-9]+)$',
    ).firstMatch(normalized);
    if (multMatch != null) {
      final parsedName = (multMatch.group(1) ?? '').trim();
      final parsedQty = int.tryParse(multMatch.group(2) ?? '') ?? 1;
      return Medication(
        name: parsedName.isNotEmpty ? parsedName : trimmed,
        time: time,
        quantity: parsedQty > 0 ? parsedQty : 1,
      );
    }

    // 3. スペース区切りの末尾数値 (例: "エペリゾン 2") ※規格数値(60mg等)は上記にもここにも該当しない
    final spaceNumMatch = RegExp(
      r'^(.+?)\s+([0-9]+)$',
    ).firstMatch(normalized);
    if (spaceNumMatch != null) {
      final parsedName = (spaceNumMatch.group(1) ?? '').trim();
      final parsedQty = int.tryParse(spaceNumMatch.group(2) ?? '') ?? 1;
      return Medication(
        name: parsedName.isNotEmpty ? parsedName : trimmed,
        time: time,
        quantity: parsedQty > 0 ? parsedQty : 1,
      );
    }

    // 数量の指定がない場合は 1錠
    return Medication(name: trimmed, time: time, quantity: 1);
  }

  static int _parseQuantityValue(dynamic rawVal) {
    if (rawVal == null) return 1;
    if (rawVal is int) return rawVal > 0 ? rawVal : 1;
    if (rawVal is num) {
      final v = rawVal.toInt();
      return v > 0 ? v : 1;
    }
    if (rawVal is String) {
      final m = RegExp(r'\d+').firstMatch(rawVal);
      if (m != null) {
        final v = int.tryParse(m.group(0)!);
        if (v != null && v > 0) return v;
      }
    }
    return 1;
  }

  factory Medication.fromJson(Map<String, dynamic> json) {
    final rawName = (json['name'] ?? '').toString();
    final rawQty = json['quantity'] ?? json['count'] ?? json['tablets'];
    final timeVal = json['time']?.toString();

    if (rawQty != null) {
      return Medication(
        name: rawName,
        time: timeVal,
        quantity: _parseQuantityValue(rawQty),
      );
    }
    // もし名前自体に数量がくっついていた場合のフォールバック（"ロキソニン 2錠" 等）
    final parsed = parseFromInput(rawName, time: timeVal);
    return parsed;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'time': time,
      'quantity': quantity,
    };
  }
}

class HealthRecord {
  final DateTime date;
  final int? conditionScore;
  final List<String> symptoms;
  final List<Medication> medications;
  final List<Workout> workouts;
  final double? weight;
  final int? steps;
  final double? bodyFat;
  final double? bmi;
  final int? bmr;
  final int? calories;
  final double? sleepHours;

  HealthRecord({
    required this.date,
    this.conditionScore,
    this.symptoms = const [],
    this.medications = const [],
    this.workouts = const [],
    this.weight,
    this.steps,
    this.bodyFat,
    this.bmi,
    this.bmr,
    this.calories,
    this.sleepHours,
  });

  factory HealthRecord.fromJson(Map<String, dynamic> json) {
    List<Medication> parsedMeds = [];
    if (json['medications'] != null) {
      for (var item in json['medications']) {
        if (item is String) {
          parsedMeds.add(Medication.parseFromInput(item));
        } else if (item is Map) {
          parsedMeds.add(Medication.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return HealthRecord(
      date: DateTime.parse(json['date']),
      conditionScore: json['condition_score'] ?? json['conditionScore'],
      symptoms: List<String>.from(json['symptoms'] ?? []),
      medications: parsedMeds,
      workouts: (json['workouts'] as List?)
              ?.map((e) => Workout.fromJson(e))
              .toList() ??
          [],
      weight: json['weight']?.toDouble(),
      steps: json['steps'],
      bodyFat: json['bodyFat']?.toDouble(),
      bmi: json['bmi']?.toDouble(),
      bmr: json['bmr'],
      calories: json['calories'],
      sleepHours: json['sleepHours']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'conditionScore': conditionScore,
      'symptoms': symptoms,
      'medications': medications.map((e) => e.toJson()).toList(),
      'workouts': workouts.map((e) => e.toJson()).toList(),
      'weight': weight,
      'steps': steps,
      'bodyFat': bodyFat,
      'bmi': bmi,
      'bmr': bmr,
      'calories': calories,
      'sleepHours': sleepHours,
    };
  }

  HealthRecord copyWith({
    DateTime? date,
    int? conditionScore,
    List<String>? symptoms,
    List<Medication>? medications,
    List<Workout>? workouts,
    double? weight,
    int? steps,
    double? bodyFat,
    double? bmi,
    int? bmr,
    int? calories,
    double? sleepHours,
  }) {
    return HealthRecord(
      date: date ?? this.date,
      conditionScore: conditionScore ?? this.conditionScore,
      symptoms: symptoms ?? this.symptoms,
      medications: medications ?? this.medications,
      workouts: workouts ?? this.workouts,
      weight: weight ?? this.weight,
      steps: steps ?? this.steps,
      bodyFat: bodyFat ?? this.bodyFat,
      bmi: bmi ?? this.bmi,
      bmr: bmr ?? this.bmr,
      calories: calories ?? this.calories,
      sleepHours: sleepHours ?? this.sleepHours,
    );
  }
}
