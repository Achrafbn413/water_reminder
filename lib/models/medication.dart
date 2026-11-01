class Medication {
  final String id;
  final String name;
  final String prescribedDose;
  final List<int> timesMinutes;
  final bool isActive;
  final DateTime createdAt;

  const Medication({
    required this.id,
    required this.name,
    required this.prescribedDose,
    required this.timesMinutes,
    this.isActive = true,
    required this.createdAt,
  });

  Medication copyWith({
    String? name,
    String? prescribedDose,
    List<int>? timesMinutes,
    bool? isActive,
  }) {
    return Medication(
      id: id,
      name: name ?? this.name,
      prescribedDose: prescribedDose ?? this.prescribedDose,
      timesMinutes: timesMinutes ?? this.timesMinutes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'prescribedDose': prescribedDose,
    'timesMinutes': timesMinutes,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'] as String,
      name: json['name'] as String,
      prescribedDose: json['prescribedDose'] as String? ?? '',
      timesMinutes: (json['timesMinutes'] as List<dynamic>)
          .map((value) => (value as num).toInt())
          .toList(),
      isActive: json['isActive'] as bool? ?? true,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static String formatTime(int minutes) {
    final hour = (minutes ~/ 60).toString().padLeft(2, '0');
    final minute = (minutes % 60).toString().padLeft(2, '0');

    return '$hour:$minute';
  }
}

class MedicationDoseLog {
  final String medicationId;
  final String medicationName;
  final DateTime scheduledAt;
  final DateTime? confirmedAt;
  final String status;

  const MedicationDoseLog({
    required this.medicationId,
    required this.medicationName,
    required this.scheduledAt,
    required this.confirmedAt,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'medicationId': medicationId,
    'medicationName': medicationName,
    'scheduledAt': scheduledAt.toIso8601String(),
    'confirmedAt': confirmedAt?.toIso8601String(),
    'status': status,
  };

  factory MedicationDoseLog.fromJson(Map<String, dynamic> json) {
    return MedicationDoseLog(
      medicationId: json['medicationId'] as String,
      medicationName: json['medicationName'] as String,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String),
      confirmedAt: json['confirmedAt'] == null
          ? null
          : DateTime.tryParse(json['confirmedAt'] as String),
      status: json['status'] as String,
    );
  }
}
