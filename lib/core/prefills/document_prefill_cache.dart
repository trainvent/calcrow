import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'document_prefill.dart';

class DocumentPrefillCache {
  DocumentPrefillCache._();

  static const String _cacheKey = 'calcrow.document_prefills.v1';

  static Future<List<DocumentPrefill>> read(String documentKey) async {
    final preferences = await SharedPreferences.getInstance();
    final cache = _decodeCache(preferences.getString(_cacheKey));
    final rawPrefills = cache[documentKey];
    if (rawPrefills is! List) return const <DocumentPrefill>[];
    return rawPrefills
        .map(DocumentPrefill.fromMap)
        .whereType<DocumentPrefill>()
        .toList(growable: false);
  }

  static Future<void> write(
    String documentKey,
    List<DocumentPrefill> prefills,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final cache = _decodeCache(preferences.getString(_cacheKey));
    cache[documentKey] = prefills.map((prefill) => prefill.toMap()).toList();
    await preferences.setString(_cacheKey, jsonEncode(cache));
  }

  static Map<String, dynamic> _decodeCache(String? encoded) {
    if (encoded == null || encoded.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // Invalid cache data is ignored and replaced on the next write.
    }
    return <String, dynamic>{};
  }
}
