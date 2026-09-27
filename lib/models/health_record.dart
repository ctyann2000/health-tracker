
class WorkoutSet {
  final int setNumber;
  final double weight;
  final int reps;
  final bool isCompleted;
  final String type; // 'normal', 'warmup', 'drop', 'failure'

  WorkoutSet({
    required this.setNumber,
    required this.weight,
    required this.reps,
    this.isCompleted = false,
    this.type = 'normal',
  });

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      setNumber: json['setNumber'] ?? 1,
      weight: (json['weight'] ?? 0).toDouble(),
      reps: json['reps'] ?? 0,
      isCompleted: json['isCompleted'] ?? false,
      type: json['type'] ?? 'normal',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'setNumber': setNumber,
      'weight': weight,
      'reps': reps,
      'isCompleted': isCompleted,
      'type': type,
    };
  }

  WorkoutSet copyWith({
    int? setNumber,
    double? weight,
    int? reps,
    bool? isCompleted,
    String? type,
  }) {
    return WorkoutSet(
      setNumber: setNumber ?? this.setNumber,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      isCompleted: isCompleted ?? this.isCompleted,
      type: type ?? this.type,
    );
  }
}

class Workout {
  final String name;
  final double weight;
  final int reps;
  final int sets;
  final List<WorkoutSet> setDetails;
  final String? memo;
  final int? restSeconds;

  Workout({
    required this.name,
    required this.weight,
    required this.reps,
    required this.sets,
    this.setDetails = const [],
    this.memo,
    this.restSeconds,
  });

  /// 総ボリューム（負荷量 kg）の計算
  double get totalVolume {
    if (setDetails.isNotEmpty) {
      final completed = setDetails.where((s) => s.isCompleted).toList();
      final target = completed.isNotEmpty ? completed : setDetails;
      return target.fold(0.0, (sum, s) => sum + (s.weight * s.reps));
    }
    return weight * reps * sets;
  }

  /// 推定1RM (Epley formula: W * (1 + R / 30))
  double get estimatedOneRepMax {
    if (setDetails.isNotEmpty) {
      double max1RM = 0.0;
      for (var s in setDetails) {
        if (s.reps > 0) {
          final rm = s.weight * (1 + s.reps / 30.0);
          if (rm > max1RM) max1RM = rm;
        }
      }
      if (max1RM > 0) return max1RM;
    }
    return reps > 0 ? (weight * (1 + reps / 30.0)) : weight;
  }

  factory Workout.fromJson(Map<String, dynamic> json) {
    List<WorkoutSet> parsedSets = [];
    if (json['setDetails'] != null && json['setDetails'] is List) {
      parsedSets = (json['setDetails'] as List)
          .map((e) => WorkoutSet.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final double rawWeight = (json['weight'] ?? 0).toDouble();
    final int rawReps = json['reps'] ?? 0;
    final int rawSets = json['sets'] ?? (parsedSets.isNotEmpty ? parsedSets.length : 0);

    return Workout(
      name: json['name'] ?? '',
      weight: rawWeight,
      reps: rawReps,
      sets: rawSets,
      setDetails: parsedSets,
      memo: json['memo'],
      restSeconds: json['restSeconds'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'weight': weight,
      'reps': reps,
      'sets': sets,
      'setDetails': setDetails.map((s) => s.toJson()).toList(),
      if (memo != null) 'memo': memo,
      if (restSeconds != null) 'restSeconds': restSeconds,
    };
  }

  Workout copyWith({
    String? name,
    double? weight,
    int? reps,
    int? sets,
    List<WorkoutSet>? setDetails,
    String? memo,
    int? restSeconds,
  }) {
    return Workout(
      name: name ?? this.name,
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      sets: sets ?? this.sets,
      setDetails: setDetails ?? this.setDetails,
      memo: memo ?? this.memo,
      restSeconds: restSeconds ?? this.restSeconds,
    );
  }
}

class Medication {
  final String name;
  final String? time;

  Medication({required this.name, this.time});

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      name: json['name'] ?? '',
      time: json['time'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'time': time,
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
          parsedMeds.add(Medication(name: item));
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
