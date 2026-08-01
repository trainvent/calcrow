import 'package:flutter/material.dart';
import 'package:trainvent_general/trainvent_general.dart';

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
    return Material(
      color: const Color(0xFFFFFFFF),
      shape: const StadiumBorder(side: BorderSide(color: Color(0xFF747775))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Image.asset(
                  'assets/images/google_g_logo.png',
                  width: 20,
                  height: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Center(
                    child: isLoading
                        ? const TriangleLoadingIndicator(
                            size: 24,
                            strokeWidth: 2,
                            strokeColor: Color(0xFF1F1F1F),
                            baseColor: Color(0xFF1F1F1F),
                          )
                        : Text(
                            label,
                            style: const TextStyle(
                              color: Color(0xFF1F1F1F),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
