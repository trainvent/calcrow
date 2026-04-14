import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:calcrow/core/data/services/webdav_service.dart';
import 'package:calcrow/features/home/presentation/tabs/Settings/webdav_error_presentation.dart';

void main() {
  testWidgets(
    'shows Details action for browserBlocked errors and opens details dialog',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1000, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  showWebDavErrorSnackBar(
                    context: context,
                    error: WebDavException(
                      'Browser blocked the WebDAV request.',
                      kind: WebDavErrorKind.browserBlocked,
                      technicalDetails: 'XMLHttpRequest error',
                      requestMethod: 'PROPFIND',
                      requestUri: Uri.parse(
                        'https://cloud.example.com/remote.php/dav/files/user/',
                      ),
                    ),
                    isWebBuildOverride: true,
                  );
                });
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      await tester.pump();
      expect(find.text('Browser blocked the WebDAV request.'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);

      final action = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
      action.onPressed?.call();
      await tester.pumpAndSettle();

      expect(find.text('WebDAV error details'), findsOneWidget);
      expect(
        find.textContaining('Request host: cloud.example.com'),
        findsOneWidget,
      );
      expect(find.textContaining('Request method: PROPFIND'), findsOneWidget);
      expect(
        find.textContaining(
          'Required CORS methods: PROPFIND, GET, PUT, OPTIONS',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Required CORS headers: Authorization, Depth, Content-Type',
        ),
        findsOneWidget,
      );
    },
  );
}
