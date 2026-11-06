
import 'package:flutter/material.dart';

import '../models/sensor_data.dart';
import '../widgets/temperature_chart.dart';

class MenuPage extends StatelessWidget {
  final bool connected;
  final bool demoMode;
  final SensorSnapshot? data;
  final String? error;

  final List<TemperaturePoint> history1;
  final List<TemperaturePoint> history2;

  final ValueChanged<bool> onModeChanged;

  const MenuPage({
    super.key,
    required this.connected,
    required this.demoMode,
    required this.data,
    required this.error,
    required this.history1,
    required this.history2,
    required this.onModeChanged,
  });

  String temperatureText(double? value) {
    if (value == null) return '-- °C';
    return '${value.toStringAsFixed(2)} °C';
  }

  String slopeText(double? value) {
    if (value == null) return '계산 중';
    return '${value.toStringAsFixed(3)} °C/min';
  }

  String etaText(SensorData sensor) {
    if (!sensor.ok) return '측정 불가';

    if (sensor.temperature != null &&
        sensor.temperature! <= 2) {
      return '2°C 이하';
    }

    if (sensor.etaMinutes == null) {
      return '예측 불가';
    }

    return '${sensor.etaMinutes!.toStringAsFixed(1)}분';
  }

  Widget detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black54,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget sensorCard({
    required String title,
    required SensorData? sensor,
    required Color color,
  }) {
    final ok = connected &&
        sensor?.ok == true &&
        sensor?.temperature != null;

    final danger = ok && sensor!.danger;

    final Color statusColor = !connected
        ? Colors.blueGrey
        : !ok
            ? Colors.orange
            : danger
                ? Colors.red
                : Colors.green;

    final String status = !connected
        ? '데이터 연결 안 됨'
        : !ok
            ? '센서 연결 오류'
            : danger
                ? '동파 위험'
                : '정상 측정 중';

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.thermostat,
                  color: color,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Icon(
                  ok
                      ? Icons.check_circle
                      : Icons.error_outline,
                  color: statusColor,
                ),
              ],
            ),

            const SizedBox(height: 20),

            Text(
              ok
                  ? temperatureText(
                      sensor?.temperature,
                    )
                  : '측정 불가',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: ok ? color : Colors.orange,
              ),
            ),

            const SizedBox(height: 16),

            const Divider(),

            detailRow(
              '냉각 기울기',
              ok
                  ? slopeText(sensor?.slope)
                  : '측정 불가',
            ),

            detailRow(
              '2°C 도달 예상',
              ok && sensor != null
                  ? etaText(sensor)
                  : '측정 불가',
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '센서 모니터링',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          '각 센서의 온도와 냉각 속도를 확인하세요.',
          style: TextStyle(
            color: Colors.black54,
          ),
        ),

        const SizedBox(height: 20),

        Card(
          color: Colors.white,
          child: SwitchListTile(
            title: const Text('테스트 데이터 사용'),
            subtitle: Text(
              demoMode
                  ? '가상 센서 데이터'
                  : '실제 Arduino USB 데이터',
            ),
            value: demoMode,
            onChanged: onModeChanged,
          ),
        ),

        const SizedBox(height: 12),

        if (!connected && error != null) ...[
          Text(
            error!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
        ],

        sensorCard(
          title: '센서 1 · D2',
          sensor: data?.sensor1,
          color: Colors.blue,
        ),

        const SizedBox(height: 12),

        sensorCard(
          title: '센서 2 · D3',
          sensor: data?.sensor2,
          color: Colors.teal,
        ),

        const SizedBox(height: 24),

        const Text(
          '실시간 온도 그래프',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TemperatureChart(
              history1: history1,
              history2: history2,
            ),
          ),
        ),

        if (connected && data?.anyDanger == true)
          const Card(
            color: Color(0xFFFFEBEE),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '동파 위험이 감지되었습니다.',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

        if (connected &&
            data?.anySensorError == true)
          const Card(
            color: Color(0xFFFFF3E0),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '일부 센서의 연결 상태를 확인해주세요.',
                style: TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
