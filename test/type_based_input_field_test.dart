import 'package:calcrow/app/widgets/type_based_input_fields/boolean_input_field.dart';
import 'package:calcrow/app/widgets/type_based_input_fields/date_input_field.dart';
import 'package:calcrow/app/widgets/type_based_input_fields/decimal_input_field.dart';
import 'package:calcrow/app/widgets/type_based_input_fields/duration_input_field.dart';
import 'package:calcrow/app/widgets/type_based_input_fields/email_input_field.dart';
import 'package:calcrow/app/widgets/type_based_input_fields/integer_input_field.dart';
import 'package:calcrow/app/widgets/type_based_input_fields/money_input_field.dart';
import 'package:calcrow/app/widgets/type_based_input_fields/phone_input_field.dart';
import 'package:calcrow/app/widgets/type_based_input_fields/text_input_field.dart';
import 'package:calcrow/app/widgets/type_based_input_fields/time_input_field.dart';
import 'package:calcrow/app/widgets/type_based_input_fields/type_based_input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dispatches every supported field type to its reusable widget', (
    tester,
  ) async {
    final controllers = List<TextEditingController>.generate(
      10,
      (_) => TextEditingController(),
    );
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
    });

    const types = <String>[
      'text',
      'date',
      'time',
      'duration',
      'integer',
      'float',
      'money',
      'boolean',
      'email',
      'phone',
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                for (var index = 0; index < types.length; index++)
                  TypeBasedInputField(
                    controller: controllers[index],
                    labelText: types[index],
                    rawType: types[index],
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byType(TextInputField), findsNWidgets(6));
    expect(find.byType(DateInputField), findsOneWidget);
    expect(find.byType(TimeInputField), findsOneWidget);
    expect(find.byType(DurationInputField), findsOneWidget);
    expect(find.byType(IntegerInputField), findsOneWidget);
    expect(find.byType(DecimalInputField), findsNWidgets(2));
    expect(find.byType(MoneyInputField), findsOneWidget);
    expect(find.byType(BooleanInputField), findsOneWidget);
    expect(find.byType(EmailInputField), findsOneWidget);
    expect(find.byType(PhoneInputField), findsOneWidget);
  });

  testWidgets('numeric, email, and phone fields use matching keyboards', (
    tester,
  ) async {
    Future<TextInputType?> keyboardFor(String type) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TypeBasedInputField(
              controller: controller,
              labelText: type,
              rawType: type,
            ),
          ),
        ),
      );
      final keyboard = tester
          .widget<TextField>(find.byType(TextField))
          .keyboardType;
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      return keyboard;
    }

    expect(
      await keyboardFor('integer'),
      const TextInputType.numberWithOptions(signed: true),
    );
    expect(
      await keyboardFor('float'),
      const TextInputType.numberWithOptions(signed: true, decimal: true),
    );
    expect(
      await keyboardFor('money'),
      const TextInputType.numberWithOptions(signed: true, decimal: true),
    );
    expect(await keyboardFor('email'), TextInputType.emailAddress);
    expect(await keyboardFor('phone'), TextInputType.phone);
  });

  testWidgets('boolean and duration fields write normalized stored values', (
    tester,
  ) async {
    final booleanController = TextEditingController();
    final durationController = TextEditingController();
    addTearDown(booleanController.dispose);
    addTearDown(durationController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TypeBasedInputField(
                controller: booleanController,
                labelText: 'Done',
                rawType: 'boolean',
              ),
              TypeBasedInputField(
                controller: durationController,
                labelText: 'Duration',
                rawType: 'duration',
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('TRUE'));
    await tester.enterText(find.widgetWithText(TextField, 'Hours'), '2');
    await tester.enterText(find.widgetWithText(TextField, 'Minutes'), '15');
    await tester.pump();

    expect(booleanController.text, 'TRUE');
    expect(durationController.text, '02:15:00');
  });
}
