import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aqua_eco_sched_flutter/main.dart';

void main() {
  testWidgets('AquaEcoSched smoke test on desktop viewport', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AquaEcoSchedApp());
    await tester.pumpAndSettle();

    expect(find.text('AquaEcoSched'), findsOneWidget);
  });

  testWidgets('AquaEcoSched mobile viewport test (390x844) with BottomNavigationBar & Tabs', (WidgetTester tester) async {
    // Typical mobile screen resolution
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AquaEcoSchedApp());
    await tester.pumpAndSettle();

    // Verify Title and Mobile BottomNavigationBar
    expect(find.text('AquaEcoSched'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);

    // Verify tab 0 (Scheduler) elements
    expect(find.text('Launch Simulation'), findsOneWidget);

    // Tap "Pods" on bottom bar (index 1)
    await tester.tap(find.text('Pods'));
    await tester.pumpAndSettle();
    expect(find.text('🖥️ Subsea Datacenter Fleet Status'), findsOneWidget);

    // Tap "Weights" on bottom bar (index 2)
    await tester.tap(find.text('Weights'));
    await tester.pumpAndSettle();
    expect(find.text('⚖️ Balanced AquaEco'), findsOneWidget);

    // Tap "Baselines" on bottom bar (index 3)
    await tester.tap(find.text('Baselines'));
    await tester.pumpAndSettle();
    expect(find.text('0 VIOLATIONS'), findsWidgets);

    // Tap "Missions" on bottom bar (index 4)
    await tester.tap(find.text('Missions'));
    await tester.pumpAndSettle();
    expect(find.text('No active subsea execution task'), findsOneWidget);

    // Go back to Scheduler and launch simulation
    await tester.tap(find.text('Scheduler'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Launch Simulation'));
    await tester.pumpAndSettle();

    // Verify it automatically switched to Missions with active task
    expect(find.text('Advance Progress (+25%)'), findsOneWidget);

    // Advance progress
    await tester.tap(find.text('Advance Progress (+25%)'));
    await tester.pumpAndSettle();
    expect(find.text('25%'), findsOneWidget);
  });

  testWidgets('CoolingProfileChart renders 30 pods with scrollability and filter options without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AquaEcoSchedApp());
    await tester.pumpAndSettle();

    // Tap "Pods" tab
    await tester.tap(find.text('Pods'));
    await tester.pumpAndSettle();

    // Verify CoolingProfileChart elements
    expect(find.text('All (30)'), findsOneWidget);
    expect(find.text('Top 10 ΔT'), findsOneWidget);
    expect(find.text('Near Limit'), findsOneWidget);
    expect(find.text('Swipe to scroll'), findsOneWidget);

    // Tap "Top 10 ΔT" filter
    await tester.tap(find.text('Top 10 ΔT'));
    await tester.pumpAndSettle();

    // Tap back to "All (30)"
    await tester.tap(find.text('All (30)'));
    await tester.pumpAndSettle();
  });

  testWidgets('Deploying a new pod dynamically updates fleet count in scheduler', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AquaEcoSchedApp());
    await tester.pumpAndSettle();

    // Verify "🖥️ Add Pod" ribbon button is visible in Scheduler
    expect(find.text('🖥️ Add Pod'), findsOneWidget);

    // Tap "🖥️ Add Pod"
    await tester.tap(find.text('🖥️ Add Pod'));
    await tester.pumpAndSettle();

    // Verify form opened
    expect(find.text('Deploy New Subsea Compute Pod'), findsOneWidget);

    // Ensure submit button visible and tap
    await tester.ensureVisible(find.text('Deploy Pod to Active Global Fleet'));
    await tester.tap(find.text('Deploy Pod to Active Global Fleet'));
    await tester.pumpAndSettle();

    // Switch to Pods tab to see updated count (31)
    await tester.tap(find.text('Pods'));
    await tester.pumpAndSettle();
    expect(find.text('All (31)'), findsOneWidget);
  });

  testWidgets('Creating and saving a new workload dynamically updates catalog and selects it', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const AquaEcoSchedApp());
    await tester.pumpAndSettle();

    // Verify "➕ New Workload" ribbon button is visible in Scheduler
    expect(find.text('➕ New Workload'), findsOneWidget);

    // Tap "➕ New Workload"
    await tester.tap(find.text('➕ New Workload'));
    await tester.pumpAndSettle();

    // Verify form opened
    expect(find.text('Register New Computational Workload'), findsOneWidget);

    // Ensure submit button visible and tap
    await tester.ensureVisible(find.text('Save Workload to Active Catalog'));
    await tester.tap(find.text('Save Workload to Active Catalog'));
    await tester.pumpAndSettle();

    // Verify workload profile header updated to 31 Verified workloads
    expect(find.text('Workload Profile (31 Verified):'), findsOneWidget);
  });
}

