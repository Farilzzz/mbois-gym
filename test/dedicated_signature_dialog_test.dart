import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mbois_gym_pt/widgets/dedicated_signature_dialog.dart';

void main() {
  group('DedicatedSignatureDialog & SignaturePreviewCard TDD Suite', () {
    testWidgets(
      '1. DedicatedSignatureDialog renders required UI elements and PopScope(canPop: false)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    DedicatedSignatureDialog.show(context);
                  },
                  child: const Text('Buka Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka Dialog'));
        await tester.pumpAndSettle();

        // Verify PopScope with canPop == false
        final popScopeFinder = find.byType(PopScope);
        expect(popScopeFinder, findsWidgets);
        final popScope = tester.widget<PopScope>(popScopeFinder.first);
        expect(popScope.canPop, isFalse);

        // Verify SafeArea is present
        expect(find.byType(SafeArea), findsWidgets);

        // Verify instruction text
        expect(
          find.text('Silakan tanda tangan pada kotak berikut'),
          findsOneWidget,
        );

        // Verify action buttons
        expect(find.widgetWithText(OutlinedButton, 'Hapus'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Batal'), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Simpan'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Gesture handling supports multi-stroke without auto-clearing between strokes',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    DedicatedSignatureDialog.show(context);
                  },
                  child: const Text('Buka Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka Dialog'));
        await tester.pumpAndSettle();

        final canvasFinder = find.byKey(const Key('signature_canvas'));
        expect(canvasFinder, findsOneWidget);

        // First stroke: drag a small diagonal line
        final center = tester.getCenter(canvasFinder);
        final gesture1 = await tester.startGesture(center);
        for (int i = 1; i <= 4; i++) {
          await gesture1.moveBy(Offset(10.0 * i, 5.0 * i));
        }
        await gesture1.up();
        await tester.pumpAndSettle();

        // State check: after pointerUp, strokes are NOT cleared
        expect(find.text('1 goresan'), findsOneWidget);

        // Second stroke: start another stroke from a different location
        final gesture2 = await tester.startGesture(
          center + const Offset(-50, -30),
        );
        for (int i = 1; i <= 4; i++) {
          await gesture2.moveBy(Offset(-10.0 * i, 5.0 * i));
        }
        await gesture2.up();
        await tester.pumpAndSettle();

        // Both strokes must be retained (multi-stroke support)
        expect(find.text('2 goresan'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Validation rejects signature with fewer than 8 points and shows error message',
      (tester) async {
        DedicatedSignatureResult? savedResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    savedResult = await DedicatedSignatureDialog.show(context);
                  },
                  child: const Text('Buka Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka Dialog'));
        await tester.pumpAndSettle();

        // Attempt to save when empty (0 points)
        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();

        // Dialog should remain open
        expect(
          find.text('Silakan tanda tangan pada kotak berikut'),
          findsOneWidget,
        );
        expect(find.textContaining('minimal 8 titik'), findsOneWidget);
        expect(savedResult, isNull);

        // Add only a short tap/dot (e.g. 2 points)
        final canvasFinder = find.byKey(const Key('signature_canvas'));
        final center = tester.getCenter(canvasFinder);
        final gesture = await tester.startGesture(center);
        await gesture.moveBy(const Offset(2, 2));
        await gesture.up();
        await tester.pumpAndSettle();

        // Try saving with < 8 points
        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();

        expect(
          find.text('Silakan tanda tangan pada kotak berikut'),
          findsOneWidget,
        );
        expect(find.textContaining('minimal 8 titik'), findsOneWidget);
        expect(savedResult, isNull);
      },
    );

    testWidgets(
      '4. Hapus button clears all strokes and resets validation error',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    DedicatedSignatureDialog.show(context);
                  },
                  child: const Text('Buka Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka Dialog'));
        await tester.pumpAndSettle();

        // Trigger error first
        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();
        expect(find.textContaining('minimal 8 titik'), findsOneWidget);

        // Draw stroke
        final canvasFinder = find.byKey(const Key('signature_canvas'));
        final center = tester.getCenter(canvasFinder);
        final gesture = await tester.startGesture(center);
        for (int i = 1; i <= 5; i++) {
          await gesture.moveBy(Offset(5.0 * i, 5.0 * i));
        }
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.text('1 goresan'), findsOneWidget);

        // Tap Hapus
        await tester.tap(find.widgetWithText(OutlinedButton, 'Hapus'));
        await tester.pumpAndSettle();

        // Verify canvas cleared and goresan counter reset
        expect(find.text('0 goresan'), findsOneWidget);
        expect(find.textContaining('minimal 8 titik'), findsNothing);
      },
    );

    testWidgets('5. Batal button closes dialog without saving (returns null)', (
      tester,
    ) async {
      DedicatedSignatureResult? savedResult = DedicatedSignatureResult(
        strokes: const [
          [Offset(1, 1)],
        ],
        points: const [Offset(1, 1)],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  savedResult = await DedicatedSignatureDialog.show(context);
                },
                child: const Text('Buka Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Dialog'));
      await tester.pumpAndSettle();

      // Draw some points
      final canvasFinder = find.byKey(const Key('signature_canvas'));
      final center = tester.getCenter(canvasFinder);
      final gesture = await tester.startGesture(center);
      for (int i = 1; i <= 10; i++) {
        await gesture.moveBy(Offset(5.0 * i, 2.0 * i));
      }
      await gesture.up();
      await tester.pumpAndSettle();

      // Tap Batal
      await tester.tap(find.widgetWithText(TextButton, 'Batal'));
      await tester.pumpAndSettle();

      // Dialog is dismissed and result is null
      expect(
        find.text('Silakan tanda tangan pada kotak berikut'),
        findsNothing,
      );
      expect(savedResult, isNull);
    });

    testWidgets(
      '6. Simpan button validates min 8 points and returns signature data',
      (tester) async {
        DedicatedSignatureResult? savedResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    savedResult = await DedicatedSignatureDialog.show(context);
                  },
                  child: const Text('Buka Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Buka Dialog'));
        await tester.pumpAndSettle();

        final canvasFinder = find.byKey(const Key('signature_canvas'));
        final center = tester.getCenter(canvasFinder);

        // Stroke 1: 5 points
        final gesture1 = await tester.startGesture(center);
        for (int i = 1; i <= 4; i++) {
          await gesture1.moveBy(Offset(10.0 * i, 0));
        }
        await gesture1.up();
        await tester.pumpAndSettle();

        // Stroke 2: 5 points (Total >= 10 points)
        final gesture2 = await tester.startGesture(
          center + const Offset(0, 20),
        );
        for (int i = 1; i <= 4; i++) {
          await gesture2.moveBy(Offset(10.0 * i, 0));
        }
        await gesture2.up();
        await tester.pumpAndSettle();

        // Save
        await tester.tap(find.widgetWithText(ElevatedButton, 'Simpan'));
        await tester.pumpAndSettle();

        // Dialog should close
        expect(
          find.text('Silakan tanda tangan pada kotak berikut'),
          findsNothing,
        );

        // Result should be populated
        expect(savedResult, isNotNull);
        expect(savedResult!.strokes.length, 2);
        expect(savedResult!.totalPoints, greaterThanOrEqualTo(8));
        expect(savedResult!.isValid, isTrue);
        expect(savedResult!.timestamp, isNotNull);
      },
    );

    testWidgets(
      '7. SignaturePreviewCard displays preview, Terverifikasi status, timestamp, and edit button',
      (tester) async {
        bool editTapped = false;
        final fixedTime = DateTime(2026, 11, 1, 14, 30);
        final dummySignature = DedicatedSignatureResult(
          strokes: [
            [
              const Offset(10, 10),
              const Offset(20, 20),
              const Offset(30, 20),
              const Offset(40, 25),
            ],
            [
              const Offset(50, 30),
              const Offset(60, 35),
              const Offset(70, 40),
              const Offset(80, 45),
            ],
          ],
          timestamp: fixedTime,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SignaturePreviewCard(
                signature: dummySignature,
                signerLabel: 'Tanda Tangan Klien',
                onEdit: () {
                  editTapped = true;
                },
              ),
            ),
          ),
        );

        // Verify signer label
        expect(find.text('Tanda Tangan Klien'), findsOneWidget);

        // Verify 'Terverifikasi' status badge
        expect(find.text('Terverifikasi'), findsOneWidget);

        // Verify formatted timestamp
        expect(find.textContaining('01/11/2026 14:30'), findsOneWidget);

        // Verify 'Ubah Tanda Tangan' button
        final editButtonFinder = find.widgetWithText(
          OutlinedButton,
          'Ubah Tanda Tangan',
        );
        expect(editButtonFinder, findsOneWidget);

        // Tap edit button
        await tester.tap(editButtonFinder);
        await tester.pumpAndSettle();
        expect(editTapped, isTrue);
      },
    );

    testWidgets(
      '8. SignaturePreviewCard shows unverified state when signature is null or empty',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SignaturePreviewCard(
                signature: null,
                signerLabel: 'Tanda Tangan Coach',
                onEdit: () {},
              ),
            ),
          ),
        );

        expect(find.text('Tanda Tangan Coach'), findsOneWidget);
        expect(find.text('Belum ditandatangani'), findsOneWidget);
        expect(find.text('Belum ada tanda tangan'), findsOneWidget);
        expect(find.text('Terverifikasi'), findsNothing);
      },
    );
  });
}
