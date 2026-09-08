import 'dart:convert';

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
}
