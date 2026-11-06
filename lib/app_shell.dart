
import 'dart:async';

import 'package:flutter/material.dart';

import 'models/sensor_data.dart';
import 'services/temperature_service.dart';
import 'pages/home_page.dart';
import 'pages/menu_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final TemperatureService service =
      TemperatureService();

  int selectedTab = 0;
  int modeVersion = 0;
  int? lastSequence;

  bool demoMode = true;
  bool connected = false;
  bool loading = false;
  bool warningShown = false;

  String? error;
  SensorSnapshot? latest;
  DateTime? lastUpdated;

  Timer? timer;

  final List<TemperaturePoint> history1 = [];
  final List<TemperaturePoint> history2 = [];

  @override
  void initState() {
    super.initState();

    loadData();

    timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => loadData(),
    );
  }

  Future<void> loadData() async {
    if (loading) return;

    loading = true;
    final currentVersion = modeVersion;

    try {
      final SensorSnapshot data = demoMode
          ? service.createDemoData()
          : await service.fetchRealData();

      if (!mounted ||
          currentVersion != modeVersion) {
        return;
      }

      final now = DateTime.now();

      setState(() {
        connected = true;
        error = null;
        latest = data;

        final isNew =
            data.sequence == null ||
            data.sequence != lastSequence;

        if (isNew) {
          lastSequence = data.sequence;
          lastUpdated = now;

          if (data.sensor1.ok &&
              data.sensor1.temperature != null) {
            history1.add(
              TemperaturePoint(
                now,
                data.sensor1.temperature!,
              ),
            );
          }

          if (data.sensor2.ok &&
              data.sensor2.temperature != null) {
            history2.add(
              TemperaturePoint(
                now,
                data.sensor2.temperature!,
              ),
            );
          }
        }

        // Keep only 60 seconds of readings
        history1.removeWhere(
          (point) =>
              now.difference(point.time) >
              const Duration(seconds: 60),
        );

        history2.removeWhere(
          (point) =>
              now.difference(point.time) >
              const Duration(seconds: 60),
        );
      });

      if (data.anyDanger && !warningShown) {
        warningShown = true;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '동파 위험! 센서 상태를 확인하세요.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      } else if (!data.anyDanger) {
        warningShown = false;
      }
    } catch (e) {
      if (!mounted ||
          currentVersion != modeVersion) {
        return;
      }

      setState(() {
        connected = false;
        error = e.toString();
      });
    } finally {
      loading = false;
    }
  }

  void changeMode(bool value) {
    setState(() {
      modeVersion++;
      demoMode = value;

      connected = false;
      error = null;
      latest = null;
      lastUpdated = null;
      lastSequence = null;
      warningShown = false;

      history1.clear();
      history2.clear();

      service.resetDemo();
    });

    loadData();
  }

  void openMenu() {
    setState(() {
      selectedTab = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PIPE GUARD',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: Colors.white,
      ),

      body: SafeArea(
        child: IndexedStack(
          index: selectedTab,
          children: [
            HomePage(
              connected: connected,
              demoMode: demoMode,
              data: latest,
              lastUpdated: lastUpdated,
              error: error,
              onOpenMenu: openMenu,
            ),

            MenuPage(
              connected: connected,
              demoMode: demoMode,
              data: latest,
              error: error,
              history1: history1,
              history2: history2,
              onModeChanged: changeMode,
            ),
          ],
        ),
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) {
          setState(() {
            selectedTab = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: '홈',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_rounded),
            selectedIcon: Icon(
              Icons.sensors_rounded,
            ),
            label: '메뉴',
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }
}
