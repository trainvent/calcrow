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

  static Future<List<DocumentPrefill>> readForFileName(
    String fileName, {
    Iterable<String> legacyDocumentKeys = const <String>[],
  }) async {
    final primaryKey = documentPrefillKey(fileName);
    final preferences = await SharedPreferences.getInstance();
    final cache = _decodeCache(preferences.getString(_cacheKey));

    List<DocumentPrefill> decodeAt(String key) {
      final rawPrefills = cache[key];
      if (rawPrefills is! List) return const <DocumentPrefill>[];
      return rawPrefills
          .map(DocumentPrefill.fromMap)
          .whereType<DocumentPrefill>()
          .toList(growable: false);
    }

    var prefills = decodeAt(primaryKey);
    if (prefills.isNotEmpty) return prefills;

    for (final legacyKey in legacyDocumentKeys) {
      prefills = decodeAt(legacyKey);
      if (prefills.isNotEmpty) break;
    }
    if (prefills.isEmpty) {
      final matchingLegacyKey = cache.keys.cast<String?>().firstWhere(
        (key) => key != null && _legacyKeyMatchesFileName(key, fileName),
        orElse: () => null,
      );
      if (matchingLegacyKey != null) {
        prefills = decodeAt(matchingLegacyKey);
      }
    }
    if (prefills.isNotEmpty) {
      cache[primaryKey] = prefills.map((prefill) => prefill.toMap()).toList();
      await preferences.setString(_cacheKey, jsonEncode(cache));
    }
    return prefills;
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

  static bool _legacyKeyMatchesFileName(String key, String fileName) {
    if (!key.startsWith('local:')) return false;
    final normalizedName = fileName.trim().toLowerCase();
    if (normalizedName.isEmpty) return false;
    var decodedKey = key.toLowerCase();
    try {
      decodedKey = Uri.decodeFull(decodedKey);
    } catch (_) {
      // The raw key can still contain a directly comparable path.
    }
    return decodedKey.endsWith('/$normalizedName') ||
        decodedKey.endsWith(':$normalizedName') ||
        decodedKey.endsWith('\\$normalizedName');
  }
}
