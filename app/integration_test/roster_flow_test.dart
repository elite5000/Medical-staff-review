import 'package:app/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Ported from e2e/roster-flow.spec.mts: builds up a whole practice from scratch through
/// the real UI (building, tag, role, room, staff, rule) against a real running backend, and
/// confirms the solver actually produces a satisfying roster end-to-end. Every entity name
/// is suffixed so this is safe to run against a shared backend without colliding with other
/// data.
///
/// Requires a backend already running on port 8000 (bound to 0.0.0.0 if targeting an
/// emulator, not just 127.0.0.1) with no pairing token configured (dev mode — see
/// backend/app/config.py). See app/README or the migration plan's Verification section for
/// how to start one against a throwaway DB.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'creates a practice from scratch and generates a roster satisfying its rules',
    (tester) async {
      final suffix = DateTime.now().millisecondsSinceEpoch.toString();
      final buildingName = 'Hospital $suffix';
      final tagName = 'Emergency Department $suffix';
      final roleName = 'Senior Fellow $suffix';
      final roomName = 'ED Room $suffix';
      final staffName = 'Dr. Alice $suffix';
      final ruleName = 'ED minimum staffing $suffix';

      await tester.pumpWidget(const MedicalStaffReviewApp());
      await tester.pumpAndSettle();

      // A prior run's pairing is remembered via real shared_preferences on this machine (see
      // ConnectionStore), so _RootPage may skip straight past ConnectScreen to AppShell —
      // only drive the connect form if it's actually showing.
      final hostField = find.widgetWithText(TextField, 'Host / IP address');
      if (hostField.evaluate().isNotEmpty) {
        // Android emulators can't reach the host machine via 127.0.0.1 — 10.0.2.2 is the
        // special alias the emulator maps back to the host's loopback interface.
        final backendHost = defaultTargetPlatform == TargetPlatform.android
            ? '10.0.2.2'
            : '127.0.0.1';
        await tester.enterText(hostField, backendHost);
        await tester.enterText(find.widgetWithText(TextField, 'Port'), '8000');
        await tester.tap(find.widgetWithText(FilledButton, 'Connect'));
        await tester.pumpAndSettle();
      }

      // --- Building (08:00-16:00 default divides into two 4-hour shift blocks) ---
      await tester.tap(find.text('Buildings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        buildingName,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text(buildingName), findsOneWidget);

      // --- Tag ---
      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), tagName);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text(tagName), findsOneWidget);

      // --- Role ---
      await tester.tap(find.text('Roles'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), roleName);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text(roleName), findsOneWidget);

      // --- Room (building + tag from above) ---
      await tester.tap(find.text('Rooms'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), roomName);
      await tester.tap(
        find.byType(DropdownButtonFormField<int>).first,
      ); // Building
      await tester.pumpAndSettle();
      await tester.tap(find.text(buildingName).last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, tagName));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.text(roomName), findsOneWidget);

      // --- Staff (holding the role above) ---
      await tester.tap(find.text('Staff'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), staffName);
      await tester.tap(find.widgetWithText(CheckboxListTile, roleName));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      // Saving a new staff member switches this same page into edit mode in place (see
      // StaffFormPage) rather than navigating away, so the app bar title flips to "Edit".
      expect(find.text('Edit Staff Member'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // --- Rule: a tag-scoped minimum-count rule — the ED needs at least 1 Senior Fellow ---
      await tester.tap(find.text('Rules'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name'), ruleName);
      // Rule type already defaults to "Minimum count", and since this rule is the only role
      // and only tag that exist at this point in the test, Role/Tag already default to them
      // (see RuleFormPage's `_roleId ??= roles.firstOrNull?.id` and similar for `_tagId`) —
      // only "Applies to" needs to actually change, from its Building default to Tag.
      //
      // find.text('Building') is ambiguous even before opening the dropdown: Flutter's
      // DropdownButtonFormField keeps an off-screen copy of every menu item for layout sizing,
      // so both the visible selected value and the hidden sizing copy match. Locate the
      // dropdown itself positionally instead (order: rule type, role, applies-to, tag/building).
      final dropdowns = find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField,
      );
      await tester.tap(dropdowns.at(2)); // "Applies to"
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tag').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Minimum count'),
        '1',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      // --- Generate the roster ---
      await tester.tap(find.text('Rosters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Generate Roster'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start date'));
      await tester.pumpAndSettle();
      // The picker opens on the current month — August 2026 is one month ahead of the
      // 2026-07-28 the migration plan's environment is dated to.
      final nextMonth = find.byTooltip('Next month');
      if (nextMonth.evaluate().isNotEmpty) {
        await tester.tap(nextMonth);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('3'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Number of days'),
        '1',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Generate'));
      // The solver runs synchronously inside the generate request — give it real time.
      await tester.pumpAndSettle(const Duration(seconds: 10));

      expect(find.text('Violations'), findsNothing);
      // The 08:00-16:00 opening hours divide into two 4-hour shift blocks, so the room
      // appears twice — once per block — and the lone qualifying staff member must be
      // assigned to both, satisfying the minimum-count rule with zero violations.
      expect(find.textContaining(roomName), findsNWidgets(2));
      expect(find.textContaining(staffName), findsNWidgets(2));
    },
  );
}
