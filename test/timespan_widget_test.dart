import 'package:calcrow/features/home/editing/widgets/timespan_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('updates visible minutes when parent controller is replaced', (
    tester,
  ) async {
    await tester.pumpWidget(const _TimespanHarness());

    expect(find.widgetWithText(TextField, '45'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Hours'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Minutes'), findsOneWidget);

    await tester.tap(find.text('New Row'));
    await tester.pump();

    for (final textField in tester.widgetList<TextField>(
      find.byType(TextField),
    )) {
      expect(textField.controller?.text, isEmpty);
    }
  });

  testWidgets('stores hours and minutes as HH:MM:SS', (tester) async {
    await tester.pumpWidget(const _TimespanHarness());

    await tester.enterText(find.widgetWithText(TextField, 'Hours'), '2');
    await tester.enterText(find.widgetWithText(TextField, 'Minutes'), '15');
    await tester.pump();

    expect(find.text('stored: 02:15:00'), findsOneWidget);
  });

  testWidgets('leaves duration empty when both fields are empty', (
    tester,
  ) async {
    await tester.pumpWidget(const _TimespanHarness(initialValue: ''));

    await tester.enterText(find.widgetWithText(TextField, 'Hours'), '');
    await tester.enterText(find.widgetWithText(TextField, 'Minutes'), '');
    await tester.pump();

    expect(find.text('stored: '), findsOneWidget);
  });
}

class _TimespanHarness extends StatefulWidget {
  const _TimespanHarness({this.initialValue = '00:45:00'});

  final String initialValue;

  @override
  State<_TimespanHarness> createState() => _TimespanHarnessState();
}

class _TimespanHarnessState extends State<_TimespanHarness> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _replaceController() {
    final oldController = _controller;
    setState(() {
      _controller = TextEditingController();
    });
    oldController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            TimespanWidget(controller: _controller, labelText: 'Pause'),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (context, value, _) => Text('stored: ${value.text}'),
            ),
            TextButton(
              onPressed: _replaceController,
              child: const Text('New Row'),
            ),
          ],
        ),
      ),
    );
  }
}
