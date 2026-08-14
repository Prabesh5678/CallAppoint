class Biomarker {
  final String id;
  final String patient;
  final String name;
  final double value;
  final String unit;
  final String? referenceRange;
  final DateTime recordedAt;
  final String? notes;

  Biomarker({
    required this.id,
    required this.patient,
    required this.name,
    required this.value,
    required this.unit,
    this.referenceRange,
    required this.recordedAt,
    this.notes,
  });

  factory Biomarker.fromJson(Map<String, dynamic> json) {
    return Biomarker(
      id: json['id'],
      patient: json['patient'],
      name: json['name'],
      value: double.parse(json['value'].toString()),
      unit: json['unit'],
      referenceRange: json['reference_range'],
      recordedAt: DateTime.parse(json['recorded_at']).toLocal(),
      notes: json['notes'],
    );
  }
}

class BiomarkerTrend {
  final String name;
  final String? unit;
  final List<BiomarkerTrendPoint> points;

  BiomarkerTrend({
    required this.name,
    this.unit,
    required this.points,
  });

  factory BiomarkerTrend.fromJson(Map<String, dynamic> json) {
    final List<dynamic> trendsJson = json['trends'] ?? [];
    return BiomarkerTrend(
      name: json['biomarker'],
      unit: json['unit'],
      points: trendsJson.map((e) => BiomarkerTrendPoint.fromJson(e)).toList(),
    );
  }
}

class BiomarkerTrendPoint {
  final DateTime date;
  final double value;

  BiomarkerTrendPoint({
    required this.date,
    required this.value,
  });

  factory BiomarkerTrendPoint.fromJson(Map<String, dynamic> json) {
    return BiomarkerTrendPoint(
      date: DateTime.parse(json['date']),
      value: double.parse(json['value'].toString()),
    );
  }
}
