import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:calcrow/core/sheet_type_logic/ods_logic.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ODS buildBytes keeps content.xml parseable for bundled fixture', () async {
    final sourceBytes = await rootBundle.load(
      'test_objects/manipulate/Arbeitszeiten_2026.ods',
    );
    final input = Uint8List.sublistView(sourceBytes);
    final parsed = OdsSheetLogic.parse(
      bytes: input,
      fileName: 'Arbeitszeiten_2026.ods',
      path: null,
    );

    final rebuilt = OdsSheetLogic.buildBytes(parsed);
    final archive = ZipDecoder().decodeBytes(rebuilt, verify: true);
    final contentFile = archive.findFile('content.xml');

    expect(contentFile, isNotNull);
    expect(
      () => XmlDocument.parse(
        utf8.decode(contentFile!.content as List<int>),
      ),
      returnsNormally,
    );
    expect(
      _findDuplicateAttributes(
        utf8.decode(contentFile!.content as List<int>),
      ),
      isEmpty,
    );
  });

  test('ODS buildBytes keeps footer rows in place for bundled fixture', () async {
    final sourceBytes = await rootBundle.load(
      'test_objects/manipulate/Arbeitszeiten_2026.ods',
    );
    final input = Uint8List.sublistView(sourceBytes);
    final parsed = OdsSheetLogic.parse(
      bytes: input,
      fileName: 'Arbeitszeiten_2026.ods',
      path: null,
    );

    expect(parsed.rows, hasLength(31));

    final rebuilt = OdsSheetLogic.buildBytes(parsed);
    final archive = ZipDecoder().decodeBytes(rebuilt, verify: true);
    final contentFile = archive.findFile('content.xml');
    expect(contentFile, isNotNull);

    final document = XmlDocument.parse(
      utf8.decode(contentFile!.content as List<int>),
    );
    final rows = _tableRows(document, parsed.xlsxSheetName!);

    expect(rows[32][0], isEmpty);
    expect(rows[33][3], 'Summe');
    expect(rows[34][5], isNotEmpty);
    expect(rows[34][6], isNotEmpty);
  });
}

List<String> _findDuplicateAttributes(String xml) {
  final duplicates = <String>[];
  final tagPattern = RegExp(r'<[^!?][^>]*>', dotAll: true);
  final attributePattern = RegExp(r'([A-Za-z_][\w.\-:]*?)\s*=');

  for (final tagMatch in tagPattern.allMatches(xml)) {
    final tag = tagMatch.group(0)!;
    final seen = <String>{};
    for (final attributeMatch in attributePattern.allMatches(tag)) {
      final name = attributeMatch.group(1)!;
      if (!seen.add(name)) {
        duplicates.add('$name in $tag');
      }
    }
  }

  return duplicates;
}

List<List<String>> _tableRows(XmlDocument document, String tableName) {
  const nsOffice = 'urn:oasis:names:tc:opendocument:xmlns:office:1.0';
  const nsTable = 'urn:oasis:names:tc:opendocument:xmlns:table:1.0';
  const nsText = 'urn:oasis:names:tc:opendocument:xmlns:text:1.0';

  final spreadsheet = document.rootElement
      .findElements('body', namespace: nsOffice)
      .first
      .findElements('spreadsheet', namespace: nsOffice)
      .first;
  final table = spreadsheet
      .findElements('table', namespace: nsTable)
      .firstWhere(
        (element) => element.getAttribute('name', namespace: nsTable) == tableName,
      );

  return table
      .findElements('table-row', namespace: nsTable)
      .map((row) {
        final values = <String>[];
        for (final cell in row.childElements) {
          if (cell.name.namespaceUri != nsTable) continue;
          if (cell.name.local != 'table-cell' &&
              cell.name.local != 'covered-table-cell') {
            continue;
          }
          final repeat =
              int.tryParse(
                cell.getAttribute('number-columns-repeated', namespace: nsTable) ??
                    '1',
              ) ??
              1;
          final text = cell
              .findElements('p', namespace: nsText)
              .map((element) => element.innerText.trim())
              .where((value) => value.isNotEmpty)
              .join('\n');
          for (var i = 0; i < repeat; i++) {
            values.add(text);
          }
        }
        return values;
      })
      .toList();
}
