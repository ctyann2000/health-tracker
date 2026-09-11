
/// 処方された各薬品の詳細情報
class PrescriptionMedication {
  final String name; // 薬品名
  final String dosage; // 用法・用量（例: ◆外用 塗布◆ 総量:20mL）
  final String? category; // 区分（外用 / 内服 / 頓服 等）
  final String? efficacy; // 効能・効果
  final String? sideEffects; // 主な副作用
  final String? precautions; // 注意事項
  final String? imageUrl; // 薬品の外観写真URLまたはローカルパス

  PrescriptionMedication({
    required this.name,
    required this.dosage,
    this.category,
    this.efficacy,
    this.sideEffects,
    this.precautions,
    this.imageUrl,
  });

  factory PrescriptionMedication.fromJson(Map<String, dynamic> json) {
    return PrescriptionMedication(
      name: json['name'] ?? '',
      dosage: json['dosage'] ?? '',
      category: json['category'],
      efficacy: json['efficacy'],
      sideEffects: json['sideEffects'] ?? json['side_effects'],
      precautions: json['precautions'],
      imageUrl: json['imageUrl'] ?? json['image_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dosage': dosage,
      'category': category,
      'efficacy': efficacy,
      'sideEffects': sideEffects,
      'precautions': precautions,
      'imageUrl': imageUrl,
    };
  }

  PrescriptionMedication copyWith({
    String? name,
    String? dosage,
    String? category,
    String? efficacy,
    String? sideEffects,
    String? precautions,
    String? imageUrl,
  }) {
    return PrescriptionMedication(
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      category: category ?? this.category,
      efficacy: efficacy ?? this.efficacy,
      sideEffects: sideEffects ?? this.sideEffects,
      precautions: precautions ?? this.precautions,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

/// 1回の調剤・処方単位の記録（病院・薬局・処方薬一覧）
class PrescriptionRecord {
  final String id;
  final DateTime date; // 調剤日 / 処方日
  final String hospitalName; // 医療機関名（例: 栗田皮フ科）
  final String? department; // 診療科（例: 【皮膚科】）
  final String? doctorName; // 医師名（例: 栗田 依幸）
  final String? pharmacyName; // 調剤薬局名（例: オリーブ薬局幕張本郷店）
  final String? pharmacistName; // 薬剤師名
  final int? cost; // 医療費の合計・自己負担額（例: 1180円）
  final List<PrescriptionMedication> medications; // 処方薬リスト
  final String? notes; // 備考・メモ

  PrescriptionRecord({
    required this.id,
    required this.date,
    required this.hospitalName,
    this.department,
    this.doctorName,
    this.pharmacyName,
    this.pharmacistName,
    this.cost,
    required this.medications,
    this.notes,
  });

  factory PrescriptionRecord.fromJson(Map<String, dynamic> json) {
    var medsList = <PrescriptionMedication>[];
    if (json['medications'] != null) {
      for (var m in json['medications']) {
        if (m is Map) {
          medsList.add(PrescriptionMedication.fromJson(Map<String, dynamic>.from(m)));
        }
      }
    }

    DateTime parsedDate;
    try {
      if (json['date'] != null) {
        final dStr = json['date'].toString().replaceAll('/', '-');
        parsedDate = DateTime.parse(dStr);
      } else {
        parsedDate = DateTime.now();
      }
    } catch (_) {
      parsedDate = DateTime.now();
    }

    int? parsedCost;
    if (json['cost'] != null) {
      if (json['cost'] is num) {
        parsedCost = (json['cost'] as num).toInt();
      } else {
        parsedCost = int.tryParse(json['cost'].toString().replaceAll(RegExp(r'[^0-9]'), ''));
      }
    }

    return PrescriptionRecord(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      date: parsedDate,
      hospitalName: json['hospitalName'] ?? json['hospital_name'] ?? '医療機関',
      department: json['department']?.toString(),
      doctorName: json['doctorName'] ?? json['doctor_name'],
      pharmacyName: json['pharmacyName'] ?? json['pharmacy_name'],
      pharmacistName: json['pharmacistName'] ?? json['pharmacist_name'],
      cost: parsedCost,
      medications: medsList,
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'hospitalName': hospitalName,
      'department': department,
      'doctorName': doctorName,
      'pharmacyName': pharmacyName,
      'pharmacistName': pharmacistName,
      'cost': cost,
      'medications': medications.map((m) => m.toJson()).toList(),
      'notes': notes,
    };
  }

  PrescriptionRecord copyWith({
    String? id,
    DateTime? date,
    String? hospitalName,
    String? department,
    String? doctorName,
    String? pharmacyName,
    String? pharmacistName,
    int? cost,
    List<PrescriptionMedication>? medications,
    String? notes,
  }) {
    return PrescriptionRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      hospitalName: hospitalName ?? this.hospitalName,
      department: department ?? this.department,
      doctorName: doctorName ?? this.doctorName,
      pharmacyName: pharmacyName ?? this.pharmacyName,
      pharmacistName: pharmacistName ?? this.pharmacistName,
      cost: cost ?? this.cost,
      medications: medications ?? this.medications,
      notes: notes ?? this.notes,
    );
  }
}
