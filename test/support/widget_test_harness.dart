import 'package:flutter/material.dart';

Widget materialTestApp({required Widget child, Size? size}) {
  final body = size == null
      ? child
      : SizedBox.fromSize(size: size, child: child);
  return MaterialApp(home: Scaffold(body: body));
}

Widget materialTestAppWithBottomBar(Widget bottomNavigationBar) {
  return MaterialApp(home: Scaffold(bottomNavigationBar: bottomNavigationBar));
}
