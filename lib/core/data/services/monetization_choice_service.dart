import 'package:shared_preferences/shared_preferences.dart';

enum MonetizationChoice { ads }

MonetizationChoice? monetizationChoiceFromStorage(Object? value) {
  return switch ((value as String?)?.trim().toLowerCase()) {
    'ads' => MonetizationChoice.ads,
    _ => null,
  };
}

class MonetizationChoiceService {
  const MonetizationChoiceService._();

  static const String _preferencePrefix = 'monetization_choice_';

  static Future<MonetizationChoice?> read(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    return monetizationChoiceFromStorage(
      preferences.getString('$_preferencePrefix$uid'),
    );
  }

  static Future<void> save(String uid, MonetizationChoice choice) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('$_preferencePrefix$uid', choice.name);
  }
}
