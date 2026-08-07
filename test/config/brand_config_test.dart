import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/config/brand_config.dart';

void main() {
  group('BrandConfig legal URLs', () {
    test('privacyPolicyUrl is a real URL, not the submission placeholder',
        () {
      expect(
        BrandConfig.privacyPolicyUrl.startsWith('https://'),
        isTrue,
        reason: 'BrandConfig.privacyPolicyUrl is still the placeholder '
            '"TODO_SET_BEFORE_SUBMISSION". Set the real privacy policy '
            'URL before submitting to the App Store.',
      );
    });
  });
}
