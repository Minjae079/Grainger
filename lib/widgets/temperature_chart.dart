
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../models/sensor_data.dart';

class TemperatureChart extends StatelessWidget {
  final List<TemperaturePoint> history1;
  final List<TemperaturePoint> history2;

  const TemperatureChart({
    super.key,
    required this.history1,
    required this.history2,
  });

  List<FlSpot> makeSpots(
    List<TemperaturePoint> history,
    DateTime now,
  ) {
    return history.map((point) {
      final secondsAgo = now
              .difference(point.time)
              .inMilliseconds /
          1000.0;

      // Display last 60 seconds
      final x = math.max(
        0.0,
        60.0 - secondsAgo,
      );

      return FlSpot(x, point.value);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final all = [
      ...history1,
      ...history2,
    ];

    if (all.length < 2) {
      return const SizedBox(
        height: 220,
        child: Center(
          child: Text('온도 데이터 수집 중...'),
        ),
      );
    }

    final now = DateTime.now();

    final spots1 = makeSpots(history1, now);
    final spots2 = makeSpots(history2, now);

    final values =
        all.map((point) => point.value).toList();

    final minTemp = values.reduce(math.min);
    final maxTemp = values.reduce(math.max);

    return Column(
      children: [
        const Row(
          children: [
            Icon(
              Icons.circle,
              size: 12,
              color: Colors.blue,
            ),
            Text(' 센서 1     '),
            Icon(
              Icons.circle,
              size: 12,
              color: Colors.teal,
            ),
            Text(' 센서 2'),
          ],
        ),

        const SizedBox(height: 16),

        SizedBox(
          height: 230,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 60,
              minY: minTemp - 0.7,
              maxY: maxTemp + 0.7,

              gridData: const FlGridData(
                show: true,
              ),

              titlesData: const FlTitlesData(
                show: false,
              ),

              borderData: FlBorderData(
                show: false,
              ),

              lineBarsData: [
                if (spots1.isNotEmpty)
                  LineChartBarData(
                    spots: spots1,
                    isCurved: false,
                    color: Colors.blue,
                    barWidth: 3,
                    dotData: const FlDotData(
                      show: false,
                    ),
                  ),

                if (spots2.isNotEmpty)
                  LineChartBarData(
                    spots: spots2,
                    isCurved: false,
                    color: Colors.teal,
                    barWidth: 3,
                    dotData: const FlDotData(
                      show: false,
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          '최근 60초 온도 변화',
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
