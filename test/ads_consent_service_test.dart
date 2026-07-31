import 'package:calcrow/core/data/services/ads_consent_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('consent gate permits users outside GDPR scope', () {
    expect(
      hasMinimumAdChoicesFromTcf(
        gdprApplies: 0,
        purposeConsents: '00000000000',
        purposeLegitimateInterests: '00000000000',
      ),
      isTrue,
    );
  });

  test('consent gate permits necessary-only choices', () {
    expect(
      hasMinimumAdChoicesFromTcf(
        gdprApplies: 1,
        purposeConsents: '00000000000',
        purposeLegitimateInterests: '01000011111',
      ),
      isTrue,
    );
  });

  test('consent gate rejects manually disabling every choice', () {
    expect(
      hasMinimumAdChoicesFromTcf(
        gdprApplies: 1,
        purposeConsents: '00000000000',
        purposeLegitimateInterests: '00000000000',
      ),
      isFalse,
    );
  });

  test('missing TCF data fails open instead of locking the app', () {
    expect(
      hasMinimumAdChoicesFromTcf(
        gdprApplies: 1,
        purposeConsents: null,
        purposeLegitimateInterests: null,
      ),
      isTrue,
    );
  });
}
