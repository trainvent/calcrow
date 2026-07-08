import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'simple_sheet_logic.dart';

class SimpleTypeHintCache {
  SimpleTypeHintCache._();

  static const String _csvTypeHintsPrefsKey = 'simple_csv_type_hints_v1';

  static Future<void> rememberCsvTypes({
    required String fileName,
    String? path,
    required List<String> valueTypes,
  }) async {
    final normalizedTypes = valueTypes
        .map(SimpleSheetLogic.displayTypeLabel)
        .where((type) => type.isNotEmpty)
        .toList(growable: false);
    if (normalizedTypes.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final cache = _readCache(prefs);
    cache[_cacheKey(fileName: fileName)] = normalizedTypes;
    if (path != null && path.trim().isNotEmpty) {
      cache[_cacheKey(fileName: fileName, path: path)] = normalizedTypes;
    }
    await prefs.setString(_csvTypeHintsPrefsKey, jsonEncode(cache));
  }

  static Future<List<String>?> readCsvTypes({
    required String fileName,
    String? path,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = _readCache(prefs);
    final raw =
        cache[_cacheKey(fileName: fileName, path: path)] ??
        cache[_cacheKey(fileName: fileName)];
    if (raw is! List) return null;
    final types = raw
        .whereType<String>()
        .map(SimpleSheetLogic.displayTypeLabel)
        .where((type) => type.isNotEmpty)
        .toList(growable: false);
    return types.isEmpty ? null : types;
  }

  static Future<void> clearCsvTypes({
    required String fileName,
    String? path,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cache = _readCache(prefs);
    cache.remove(_cacheKey(fileName: fileName));
    if (path != null && path.trim().isNotEmpty) {
      cache.remove(_cacheKey(fileName: fileName, path: path));
    }
    if (cache.isEmpty) {
      await prefs.remove(_csvTypeHintsPrefsKey);
      return;
    }
    await prefs.setString(_csvTypeHintsPrefsKey, jsonEncode(cache));
  }

  static Map<String, dynamic> _readCache(SharedPreferences prefs) {
    final raw = prefs.getString(_csvTypeHintsPrefsKey);
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Ignore malformed cache contents.
    }
    return <String, dynamic>{};
  }

  static String _cacheKey({required String fileName, String? path}) {
    final normalizedPath = path?.trim().toLowerCase();
    if (normalizedPath != null && normalizedPath.isNotEmpty) {
      return 'path:$normalizedPath';
    }
    return 'name:${fileName.trim().toLowerCase()}';
  }
}
