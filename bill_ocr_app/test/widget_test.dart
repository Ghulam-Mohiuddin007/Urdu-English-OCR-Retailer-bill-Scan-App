import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bill_ocr_app/main.dart';
import 'package:bill_ocr_app/views/scanner/ocr_scanner_screen.dart';

void main() {
  testWidgets('RaaseedOcrApp smoke test and navigation to HomeScreen',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: RaaseedOcrApp(),
      ),
    );

    // Initial frame shows splash
    expect(find.byType(RaaseedOcrApp), findsOneWidget);

    // Fast-forward past splash duration (2600ms) and route transition (700ms)
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pumpAndSettle();

    // Verify navigation landed on OcrScannerScreen
    expect(find.byType(OcrScannerScreen), findsOneWidget);
  });
}
