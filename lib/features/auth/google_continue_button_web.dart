import 'package:flutter/material.dart';
import 'package:google_sign_in_web/web_only.dart' as google_web;

class GoogleContinueButton extends StatelessWidget {
  const GoogleContinueButton({
    super.key,
    required this.isLoading,
    required this.label,
    required this.locale,
    required this.onPressed,
  });

  final bool isLoading;
  final String label;
  final String locale;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: isLoading,
      child: Opacity(
        opacity: isLoading ? 0.6 : 1,
        child: Center(
          child: google_web.renderButton(
            configuration: google_web.GSIButtonConfiguration(
              type: google_web.GSIButtonType.standard,
              theme: google_web.GSIButtonTheme.outline,
              size: google_web.GSIButtonSize.large,
              text: google_web.GSIButtonText.continueWith,
              shape: google_web.GSIButtonShape.pill,
              logoAlignment: google_web.GSIButtonLogoAlignment.left,
              minimumWidth: 320,
              locale: locale,
            ),
          ),
        ),
      ),
    );
  }
}
