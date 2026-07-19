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
      content: Text(error.localizedMessage(context.l10n)),
      action: canShowDetails
          ? SnackBarAction(
              label: context.l10n.details,
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
  final kindLabel = _kindLabel(context.l10n, error.kind);
  final technicalDetails = error.technicalDetails ?? 'n/a';

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(context.l10n.webdavErrorDetails),
      content: SingleChildScrollView(
        child: SelectableText(
          '${context.l10n.summary}: ${error.localizedMessage(context.l10n)}\n'
          '${context.l10n.kind}: $kindLabel\n'
          '${context.l10n.origin}: $origin\n'
          '${context.l10n.requestHost}: ${requestHost == null || requestHost.isEmpty ? context.l10n.unknown : requestHost}\n'
          '${context.l10n.requestPath}: $requestPath\n'
          '${context.l10n.requestMethod}: $requestMethod\n'
          '${context.l10n.requiredCORSMethods}: PROPFIND, GET, PUT, OPTIONS\n'
          '${context.l10n.requiredCORSHeaders}: Authorization, Depth, Content-Type\n'
          '${context.l10n.technicalDetails}: $technicalDetails',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(context.l10n.close),
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

String _kindLabel(
  AppLocalizations localizations,
  WebDavErrorKind kind,
) {
  return switch (kind) {
    WebDavErrorKind.browserBlocked => localizations.browserBlocked,
    WebDavErrorKind.network => localizations.network,
    WebDavErrorKind.auth => localizations.auth,
    WebDavErrorKind.methodNotAllowed => localizations.methodNotAllowed,
    WebDavErrorKind.http => localizations.http,
    WebDavErrorKind.unknown => localizations.unknown,
  };
}
