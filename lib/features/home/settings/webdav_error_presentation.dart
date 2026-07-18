import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:calcrow/l10n/app_localizations.dart';

import 'package:calcrow/core/data/services/webdav_service.dart';

void showWebDavErrorSnackBar({
  required BuildContext context,
  required WebDavException error,
  bool? isWebBuildOverride,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final isWebBuild = isWebBuildOverride ?? kIsWeb;
  final canShowDetails = isWebBuild;

  messenger.showSnackBar(
    SnackBar(
      content: LText(error.message),
      action: canShowDetails
          ? SnackBarAction(
              label: context.tr('Details'),
              onPressed: () => _showWebDavErrorDetailsDialog(
                context: context,
                error: error,
                isWebBuild: isWebBuild,
              ),
            )
          : null,
    ),
  );
}

Future<void> _showWebDavErrorDetailsDialog({
  required BuildContext context,
  required WebDavException error,
  required bool isWebBuild,
}) async {
  final requestHost = error.requestUri?.host;
  final requestMethod = error.requestMethod ?? 'unknown';
  final requestPath = error.requestUri?.path ?? '/';
  final origin = _resolveOriginLabel(isWebBuild: isWebBuild);
  final kindLabel = _kindLabel(error.kind);
  final technicalDetails = error.technicalDetails ?? 'n/a';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const LText('WebDAV error details'),
      content: SingleChildScrollView(
        child: SelectableText(
          '${context.tr('Summary')}: ${context.tr(error.message)}\n'
          '${context.tr('Kind')}: ${context.tr(kindLabel)}\n'
          '${context.tr('Origin')}: $origin\n'
          '${context.tr('Request host')}: ${requestHost == null || requestHost.isEmpty ? context.tr('unknown') : requestHost}\n'
          '${context.tr('Request path')}: $requestPath\n'
          '${context.tr('Request method')}: $requestMethod\n'
          '${context.tr('Required CORS methods')}: PROPFIND, GET, PUT, OPTIONS\n'
          '${context.tr('Required CORS headers')}: Authorization, Depth, Content-Type\n'
          '${context.tr('Technical details')}: $technicalDetails',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const LText('Close'),
        ),
      ],
    ),
  );
}

String _resolveOriginLabel({required bool isWebBuild}) {
  if (!isWebBuild) return 'n/a';
  try {
    return Uri.base.origin;
  } catch (_) {
    return Uri.base.toString();
  }
}

String _kindLabel(WebDavErrorKind kind) {
  return switch (kind) {
    WebDavErrorKind.browserBlocked => 'browser_blocked',
    WebDavErrorKind.network => 'network',
    WebDavErrorKind.auth => 'auth',
    WebDavErrorKind.methodNotAllowed => 'method_not_allowed',
    WebDavErrorKind.http => 'http',
    WebDavErrorKind.unknown => 'unknown',
  };
}
