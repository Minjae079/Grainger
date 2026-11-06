
double? parseNumber(dynamic value) {
  if (value is num) {
    final result = value.toDouble();
    return result.isFinite ? result : null;
  }
  return null;
}

class SensorData {
  final bool ok;
  final double? temperature;
  final double? slope;
  final double? etaMinutes;
  final bool danger;

  const SensorData({
    required this.ok,
    required this.temperature,
    required this.slope,
    required this.etaMinutes,
    required this.danger,
  });
}

class SensorSnapshot {
  final SensorData sensor1;
  final SensorData sensor2;
  final int? sequence;

  const SensorSnapshot({
    required this.sensor1,
    required this.sensor2,
    this.sequence,
  });

  int get workingCount =>
      (sensor1.ok ? 1 : 0) +
      (sensor2.ok ? 1 : 0);

  bool get anyDanger =>
      (sensor1.ok && sensor1.danger) ||
      (sensor2.ok && sensor2.danger);

  bool get anySensorError =>
      !sensor1.ok || !sensor2.ok;

  factory SensorSnapshot.fromJson(
    Map<String, dynamic> json,
  ) {
    final temp1 = parseNumber(json['temperature']);
    final temp2 = parseNumber(json['temperature2']);

    return SensorSnapshot(
      sensor1: SensorData(
        ok: json['sensorOk'] == true &&
            temp1 != null,
        temperature: temp1,
        slope: parseNumber(json['slope']),
        etaMinutes: parseNumber(
          json['etaMinutes'],
        ),
        danger: json['danger'] == true,
      ),
      sensor2: SensorData(
        ok: json['sensor2Ok'] == true &&
            temp2 != null,
        temperature: temp2,
        slope: parseNumber(json['slope2']),
        etaMinutes: parseNumber(
          json['etaMinutes2'],
        ),
        danger: json['danger2'] == true,
      ),
      sequence: json['sequence'] is num
          ? (json['sequence'] as num).toInt()
          : null,
    );
  }
}

class TemperaturePoint {
  final DateTime time;
  final double value;

  const TemperaturePoint(this.time, this.value);
}
