
import 'package:flutter/material.dart';
import '../models/sensor_data.dart';

class HomePage extends StatelessWidget {
  final bool connected;
  final bool demoMode;
  final SensorSnapshot? data;
  final DateTime? lastUpdated;
  final String? error;
  final VoidCallback onOpenMenu;

  const HomePage({
    super.key,
    required this.connected,
    required this.demoMode,
    required this.data,
    required this.lastUpdated,
    required this.error,
    required this.onOpenMenu,
  });

  String formatTime(DateTime? time) {
    if (time == null) return '수신 기록 없음';

    String two(int n) =>
        n.toString().padLeft(2, '0');

    return '${two(time.hour)}:'
        '${two(time.minute)}:'
        '${two(time.second)}';
  }

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 12,
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
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final danger =
        connected && (data?.anyDanger ?? false);

    final sensorError =
        connected && (data?.anySensorError ?? false);

    final Color statusColor = !connected
        ? Colors.blueGrey
        : danger
            ? Colors.red
            : sensorError
                ? Colors.orange
                : Colors.green;

    final String statusTitle = !connected
        ? '연결 대기 중'
        : danger
            ? '동파 위험 감지'
            : sensorError
                ? '센서 점검 필요'
                : '배관 상태 정상';

    final String description = !connected
        ? '데이터 연결을 확인해주세요.'
        : danger
            ? '동파 위험 조건이 감지됐습니다.'
            : sensorError
                ? '일부 센서의 측정값을 확인할 수 없습니다.'
                : '현재 동파 위험 조건이 감지되지 않았습니다.';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          '안녕하세요!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          '배관의 안전 상태를 확인하세요.',
          style: TextStyle(
            color: Colors.black54,
          ),
        ),

        const SizedBox(height: 24),

        // Overall system status
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: statusColor,
            borderRadius:
                BorderRadius.circular(22),
          ),
          child: Column(
            children: [
              Icon(
                danger
                    ? Icons.warning_amber_rounded
                    : sensorError
                        ? Icons.error_outline
                        : connected
                            ? Icons.shield_outlined
                            : Icons.wifi_off,
                size: 60,
                color: Colors.white,
              ),

              const SizedBox(height: 18),

              Text(
                statusTitle,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // Connection information
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  '시스템 상태',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 14),

                infoRow(
                  '데이터 연결',
                  connected ? '정상' : '연결 안 됨',
                ),

                const Divider(height: 1),

                infoRow(
                  '정상 센서',
                  '${connected ? (data?.workingCount ?? 0) : 0} / 2개',
                ),

                const Divider(height: 1),

                infoRow(
                  '데이터 모드',
                  demoMode ? '테스트 모드' : 'Arduino USB',
                ),

                const Divider(height: 1),

                infoRow(
                  '마지막 수신',
                  formatTime(lastUpdated),
                ),
              ],
            ),
          ),
        ),

        if (error != null) ...[
          const SizedBox(height: 12),
          Text(
            error!,
            style: const TextStyle(
              color: Colors.red,
              fontSize: 12,
            ),
          ),
        ],

        const SizedBox(height: 24),

        FilledButton.icon(
          onPressed: onOpenMenu,
          icon: const Icon(
            Icons.arrow_forward,
          ),
          label: const Text(
            '센서 모니터링 확인하기',
          ),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.all(18),
          ),
        ),

        const SizedBox(height: 18),

        const Text(
          '현재 버전에서는 앱이 실행 중일 때만 '
          '위험 알림이 표시됩니다.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }
}
