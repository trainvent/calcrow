import 'package:flutter/material.dart';

abstract final class AppLayoutConstants {
  static const double pageHorizontalPadding = 16;
  static const double pageTopPadding = 12;
  static const double pageBottomPadding = 22;
  static const EdgeInsets pageContentPadding = EdgeInsets.fromLTRB(
    pageHorizontalPadding,
    pageTopPadding,
    pageHorizontalPadding,
    pageBottomPadding,
  );

  static const double pageHeaderBottomSpacing = 14;
  static const double pageHeaderIconSize = 32;
  static const double pageHeaderIconRadius = 8;
  static const double pageHeaderIconGap = 12;
  static const double pageHeaderControlVerticalOffset = -3;
}
