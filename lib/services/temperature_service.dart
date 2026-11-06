
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import '../models/sensor_data.dart';

class TemperatureService {
  // Android Emulator -> Windows USB server
  static const String url =
      'http://10.0.2.2:8765/temperature';

  int _demoStep = 0;

  void resetDemo() {
    _demoStep = 0;
  }

  // Actual Arduino data through Python
  Future<SensorSnapshot> fetchRealData() async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 3));

    if (response.statusCode != 200) {
      throw Exception(
        '데이터 수신 실패: HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
        '잘못된 센서 데이터 형식',
      );
    }

    return SensorSnapshot.fromJson(decoded);
  }

  // Simulated data for UI testing
  SensorSnapshot createDemoData() {
    final step = _demoStep++;

    final temp1 = math.max(
      -5.0,
      13.0 - step * 0.035,
    );

    final temp2 = math.max(
      -5.0,
      14.0 - step * 0.045,
    );

    final double? slope1 =
        step >= 5 && temp1 > -5 ? -1.05 : null;

    final double? slope2 =
        step >= 5 && temp2 > -5 ? -1.35 : null;

    final double? eta1 =
        slope1 != null && temp1 > 2
            ? (temp1 - 2) / -slope1
            : null;

    final double? eta2 =
        slope2 != null && temp2 > 2
            ? (temp2 - 2) / -slope2
            : null;

    final danger1 =
        temp1 <= 2 ||
        (temp1 <= 12 &&
            slope1 != null &&
            slope1 <= -0.3 &&
            eta1 != null &&
            eta1 <= 15);

    final danger2 =
        temp2 <= 2 ||
        (temp2 <= 12 &&
            slope2 != null &&
            slope2 <= -0.3 &&
            eta2 != null &&
            eta2 <= 15);

    return SensorSnapshot(
      sensor1: SensorData(
        ok: true,
        temperature: temp1,
        slope: slope1,
        etaMinutes: eta1,
        danger: danger1,
      ),
      sensor2: SensorData(
        ok: true,
        temperature: temp2,
        slope: slope2,
        etaMinutes: eta2,
        danger: danger2,
      ),
      sequence: step,
    );
  }
}
