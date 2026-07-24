import 'package:flutter/material.dart';

abstract final class AppTextStyles {
  static const double pageTitleFontSize = 24;

  static const TextStyle pageTitle = TextStyle(
    fontSize: pageTitleFontSize,
    fontWeight: FontWeight.w800,
    height: 1.15,
  );
}
