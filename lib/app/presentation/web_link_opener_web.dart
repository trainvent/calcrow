// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

void openExternalUrl(String url) {
  html.window.open(url, '_blank');
}

void openSameTabUrl(String url) {
  html.window.open(url, '_self');
}
