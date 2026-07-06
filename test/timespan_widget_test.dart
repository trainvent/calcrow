import 'package:calcrow/features/home/editing/simple/widgets/timespan_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('updates visible minutes when parent controller is replaced', (
    tester,
  ) async {
    await tester.pumpWidget(const _TimespanHarness());

    expect(find.widgetWithText(TextField, '45'), findsOneWidget);

    await tester.tap(find.text('New Row'));
    await tester.pump();

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller?.text, isEmpty);
  });
}

class _TimespanHarness extends StatefulWidget {
  const _TimespanHarness();

  @override
  State<_TimespanHarness> createState() => _TimespanHarnessState();
}

class _TimespanHarnessState extends State<_TimespanHarness> {
  TextEditingController _controller = TextEditingController(text: '00:45:00');

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
