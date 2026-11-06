import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// Android Emulator -> Windows Python server
const String bridgeUrl = 'http://10.0.2.2:8765/temperature';
const Duration pollInterval = Duration(seconds: 2);

void main() => runApp(const TempAlertApp());

double? readNumber(dynamic value) =>
    value is num && value.toDouble().isFinite ? value.toDouble() : null;

// ====================================
// Sensor data
// ====================================

class SensorInfo {
  final bool ok;
  final double? temperature;
  final double? slope;
  final double? etaMinutes;
  final bool danger;

  const SensorInfo({
    required this.ok,
    required this.temperature,
    required this.slope,
    required this.etaMinutes,
    required this.danger,
  });
}

class DeviceData {
  final SensorInfo sensor1;
  final SensorInfo sensor2;
  final bool anyDanger;
  final bool anySensorError;
  final int? sequence;

  const DeviceData({
    required this.sensor1,
    required this.sensor2,
    required this.anyDanger,
    required this.anySensorError,
    this.sequence,
  });

  factory DeviceData.fromJson(Map<String, dynamic> json) {
    final s1 = SensorInfo(
      ok: json['sensorOk'] == true,
      temperature: readNumber(json['temperature']),
      slope: readNumber(json['slope']),
      etaMinutes: readNumber(json['etaMinutes']),
      danger: json['danger'] == true,
    );

    final s2 = SensorInfo(
      ok: json['sensor2Ok'] == true,
      temperature: readNumber(json['temperature2']),
      slope: readNumber(json['slope2']),
      etaMinutes: readNumber(json['etaMinutes2']),
      danger: json['danger2'] == true,
    );

    return DeviceData(
      sensor1: s1,
      sensor2: s2,
      anyDanger: (s1.ok && s1.danger) || (s2.ok && s2.danger),
      anySensorError: !s1.ok || !s2.ok,
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

// ====================================
// Flutter app
// ====================================

class TempAlertApp extends StatelessWidget {
  const TempAlertApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '배관 동파 감지',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MonitorScreen(),
    );
  }
}

class MonitorScreen extends StatefulWidget {
  const MonitorScreen({super.key});

  @override
  State<MonitorScreen> createState() => _MonitorScreenState();
}

class _MonitorScreenState extends State<MonitorScreen> {
  Timer? _timer;

  bool _demoMode = true;
  bool _connected = false;
  bool _busy = false;
  bool _alertShown = false;

  int _generation = 0;
  int _demoStep = 0;
  int? _lastSequence;

  String? _error;
  DeviceData? _latest;

  final List<TemperaturePoint> _history1 = [];
  final List<TemperaturePoint> _history2 = [];

  @override
  void initState() {
    super.initState();

    _load();

    _timer = Timer.periodic(pollInterval, (_) => _load());
  }

  // ====================================
  // Demo temperature data
  // ====================================

  DeviceData _makeDemo() {
    final step = _demoStep++;

    final t1 = math.max(-5.0, 13.0 - 0.035 * step);

    final t2 = math.max(-5.0, 14.0 - 0.045 * step);

    final double? s1 = step >= 5 ? -1.05 : null;

    final double? s2 = step >= 5 ? -1.35 : null;

    final double? eta1 = s1 != null && t1 > 2 ? (t1 - 2) / -s1 : null;

    final double? eta2 = s2 != null && t2 > 2 ? (t2 - 2) / -s2 : null;

    final danger1 = t1 <= 2 || (t1 <= 12 && eta1 != null && eta1 <= 15);

    final danger2 = t2 <= 2 || (t2 <= 12 && eta2 != null && eta2 <= 15);

    return DeviceData(
      sensor1: SensorInfo(
        ok: true,
        temperature: t1,
        slope: s1,
        etaMinutes: eta1,
        danger: danger1,
      ),
      sensor2: SensorInfo(
        ok: true,
        temperature: t2,
        slope: s2,
        etaMinutes: eta2,
        danger: danger2,
      ),
      anyDanger: danger1 || danger2,
      anySensorError: false,
      sequence: step,
    );
  }

  // ====================================
  // Receive data every 2 seconds
  // ====================================

  Future<void> _load() async {
    if (_busy) return;

    _busy = true;
    final generation = _generation;

    try {
      late DeviceData incoming;

      if (_demoMode) {
        incoming = _makeDemo();
      } else {
        final response = await http
            .get(Uri.parse(bridgeUrl))
            .timeout(const Duration(seconds: 3));

        if (response.statusCode != 200) {
          throw Exception('USB 브리지 오류: HTTP ${response.statusCode}');
        }

        final decoded = jsonDecode(response.body);

        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('잘못된 JSON 형식');
        }

        incoming = DeviceData.fromJson(decoded);
      }

      if (!mounted || generation != _generation) {
        return;
      }

      final now = DateTime.now();

      setState(() {
        _connected = true;
        _error = null;
        _latest = incoming;

        // Avoid duplicate graph points
        if (incoming.sequence == null || incoming.sequence != _lastSequence) {
          _lastSequence = incoming.sequence;

          final t1 = incoming.sensor1.temperature;
          final t2 = incoming.sensor2.temperature;

          if (incoming.sensor1.ok && t1 != null) {
            _history1.add(TemperaturePoint(now, t1));
          }

          if (incoming.sensor2.ok && t2 != null) {
            _history2.add(TemperaturePoint(now, t2));
          }

          // Keep only 60 seconds
          _history1.removeWhere(
            (p) => now.difference(p.time) > const Duration(seconds: 60),
          );

          _history2.removeWhere(
            (p) => now.difference(p.time) > const Duration(seconds: 60),
          );
        }
      });

      // In-app warning
      if (incoming.anyDanger && !_alertShown) {
        _alertShown = true;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('동파 위험 감지! 온도와 냉각 기울기를 확인하세요.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      } else if (!incoming.anyDanger) {
        _alertShown = false;
      }
    } catch (e) {
      if (!mounted || generation != _generation) {
        return;
      }

      setState(() {
        _connected = false;
        _error = e.toString();
      });
    } finally {
      _busy = false;
    }
  }

  // ====================================
  // Switch demo/real data
  // ====================================

  void _changeMode(bool demo) {
    setState(() {
      _generation++;
      _demoMode = demo;
      _connected = false;
      _latest = null;
      _error = null;
      _demoStep = 0;
      _lastSequence = null;
      _alertShown = false;

      _history1.clear();
      _history2.clear();
    });

    _load();
  }

  String _tempText(double? t) {
    if (t == null) return '-- °C';

    return '${t.toStringAsFixed(2)} °C';
  }

  String _slopeText(double? s) {
    if (s == null) return '계산 중';

    return '${s.toStringAsFixed(3)} °C/min';
  }

  String _etaText(SensorInfo s) {
    if (!s.ok) return '측정 불가';

    if (s.temperature != null && s.temperature! <= 2) {
      return '2°C 이하';
    }

    if (s.etaMinutes == null) {
      return '계산 불가';
    }

    return '${s.etaMinutes!.toStringAsFixed(1)}분';
  }

  // ====================================
  // Individual sensor card
  // ====================================

  Widget _sensorCard(String label, SensorInfo? sensor, Color color) {
    final ok = sensor?.ok == true && sensor?.temperature != null;

    final danger = ok && sensor!.danger;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  ok
                      ? (danger ? Icons.warning_amber : Icons.check_circle)
                      : Icons.error_outline,
                  color: ok
                      ? (danger ? Colors.red : Colors.green)
                      : Colors.orange,
                ),
              ],
            ),

            const SizedBox(height: 8),

            Text(
              ok ? _tempText(sensor?.temperature) : '온도 측정 불가',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: ok ? color : Colors.orange.shade900,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              '냉각 기울기: '
              '${ok ? _slopeText(sensor?.slope) : "센서 연결 오류"}',
            ),

            Text(
              '2°C 도달 예상: '
              '${sensor == null ? "데이터 없음" : _etaText(sensor)}',
            ),

            const SizedBox(height: 6),

            Text(
              ok ? (danger ? '동파 위험' : '정상 측정 중') : '센서 확인 필요',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: !ok
                    ? Colors.orange.shade900
                    : danger
                    ? Colors.red
                    : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================================
  // Temperature graph
  // ====================================

  Widget _chart() {
    final all = [..._history1, ..._history2];

    if (all.length < 2) {
      return const SizedBox(
        height: 210,
        child: Center(child: Text('온도 데이터 수집 중...')),
      );
    }

    DateTime first = all.first.time;

    for (final p in all) {
      if (p.time.isBefore(first)) {
        first = p.time;
      }
    }

    final spots1 = _history1.map((p) {
      return FlSpot(p.time.difference(first).inMilliseconds / 1000.0, p.value);
    }).toList();

    final spots2 = _history2.map((p) {
      return FlSpot(p.time.difference(first).inMilliseconds / 1000.0, p.value);
    }).toList();

    final values = all.map((p) => p.value).toList();

    final low = values.reduce(math.min);
    final high = values.reduce(math.max);

    double lastX = 1;

    if (spots1.isNotEmpty) {
      lastX = math.max(lastX, spots1.last.x);
    }

    if (spots2.isNotEmpty) {
      lastX = math.max(lastX, spots2.last.x);
    }

    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.circle, size: 11, color: Colors.indigo.shade600),
            const Text(' 센서 1     '),
            Icon(Icons.circle, size: 11, color: Colors.teal.shade600),
            const Text(' 센서 2'),
          ],
        ),

        const SizedBox(height: 10),

        SizedBox(
          height: 215,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: lastX,
              minY: low - 0.7,
              maxY: high + 0.7,
              titlesData: const FlTitlesData(show: false),
              borderData: FlBorderData(show: true),
              gridData: const FlGridData(show: true),
              lineBarsData: [
                if (spots1.isNotEmpty)
                  LineChartBarData(
                    spots: spots1,
                    isCurved: false,
                    color: Colors.indigo,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                if (spots2.isNotEmpty)
                  LineChartBarData(
                    spots: spots2,
                    isCurved: false,
                    color: Colors.teal,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 4),

        Text(
          '그래프 범위: '
          '${low.toStringAsFixed(1)} ~ '
          '${high.toStringAsFixed(1)} °C',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  // ====================================
  // Main screen
  // ====================================

  @override
  Widget build(BuildContext context) {
    final info = _latest;

    final anyDanger = _connected && (info?.anyDanger == true);

    final sensorError = _connected && (info?.anySensorError == true);

    final statusText = !_connected
        ? (_demoMode ? '테스트 데이터 준비 중' : 'USB 브리지 연결되지 않음')
        : anyDanger
        ? '동파 위험 감지'
        : sensorError
        ? '센서 연결 오류'
        : '정상 측정 중';

    final statusColor = !_connected
        ? Colors.grey
        : anyDanger
        ? Colors.red
        : sensorError
        ? Colors.orange
        : Colors.green;

    return Scaffold(
      appBar: AppBar(title: const Text('배관 동파 모니터링')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              title: const Text('테스트 데이터 사용'),
              subtitle: Text(_demoMode ? '가상 센서 2개' : 'UNO R4 USB 실제 데이터'),
              value: _demoMode,
              onChanged: _changeMode,
            ),

            const SizedBox(height: 4),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.circle, size: 12, color: statusColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      statusText,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],

            const SizedBox(height: 12),

            _sensorCard('센서 1 · D2', info?.sensor1, Colors.indigo),

            _sensorCard('센서 2 · D3', info?.sensor2, Colors.teal),

            const SizedBox(height: 10),

            const Text(
              '최근 60초 온도 그래프',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            _chart(),

            const SizedBox(height: 18),

            if (_connected && (anyDanger || sensorError))
              Card(
                color: anyDanger ? Colors.red.shade50 : Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    anyDanger
                        ? '경고: 한 개 이상의 센서에서 동파 위험이 감지됐습니다.'
                        : '주의: 하나 이상의 센서가 연결되지 않았습니다.',
                    style: TextStyle(
                      color: anyDanger
                          ? Colors.red.shade900
                          : Colors.orange.shade900,
                    ),
                  ),
                ),
              ),

            if (!_demoMode)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  '실제 데이터: Arduino USB → Windows Python 서버 → Android 에뮬레이터',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),

            const SizedBox(height: 12),

            const Text(
              '※ 화면 경고는 앱 실행 중에만 표시됩니다. '
              '백그라운드 푸시 알림은 아직 구현하지 않았습니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
