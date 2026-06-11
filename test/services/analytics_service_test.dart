import 'package:flutter_test/flutter_test.dart';
import 'package:vouch/services/analytics_service.dart';

void main() {
  late List<AnalyticsCall> sink;
  late AnalyticsService sut;

  setUp(() {
    sink = [];
    sut = AnalyticsService.test(sink);
  });

  group('event names and params', () {
    test('logSignIn fires sign_in with method', () {
      sut.logSignIn(method: 'google');
      expect(sink, hasLength(1));
      expect(sink.first.name, 'sign_in');
      expect(sink.first.params, {'method': 'google'});
    });

    test('logSignUp fires sign_up with method', () {
      sut.logSignUp(method: 'email');
      expect(sink, hasLength(1));
      expect(sink.first.name, 'sign_up');
      expect(sink.first.params, {'method': 'email'});
    });

    test('logVoteCast fires vote_cast with restaurant_id and city_id', () {
      sut.logVoteCast(restaurantId: 'r1', cityId: 'c1');
      expect(sink.first.name, 'vote_cast');
      expect(sink.first.params, {'restaurant_id': 'r1', 'city_id': 'c1'});
    });

    test('logSaveToggle fires save_toggle with action', () {
      sut.logSaveToggle(restaurantId: 'r1', action: 'save');
      expect(sink.first.name, 'save_toggle');
      expect(sink.first.params, {'restaurant_id': 'r1', 'action': 'save'});
    });

    test('logCommentSubmit fires comment_submit', () {
      sut.logCommentSubmit(restaurantId: 'r1');
      expect(sink.first.name, 'comment_submit');
      expect(sink.first.params, {'restaurant_id': 'r1'});
    });

    test('logCommentReport fires comment_report', () {
      sut.logCommentReport(restaurantId: 'r1');
      expect(sink.first.name, 'comment_report');
      expect(sink.first.params, {'restaurant_id': 'r1'});
    });

    test('logSuggestionSubmit fires suggestion_submit', () {
      sut.logSuggestionSubmit(cityId: 'c1');
      expect(sink.first.name, 'suggestion_submit');
      expect(sink.first.params, {'city_id': 'c1'});
    });

    test('logPaywallView fires paywall_view with source', () {
      sut.logPaywallView(source: 'top10');
      expect(sink.first.name, 'paywall_view');
      expect(sink.first.params, {'source': 'top10'});
    });

    test('logUpgradeTap fires upgrade_tap with tier', () {
      sut.logUpgradeTap(tier: 'localsPass');
      expect(sink.first.name, 'upgrade_tap');
      expect(sink.first.params, {'tier': 'localsPass'});
    });

    test('logShareRestaurant fires share_restaurant', () {
      sut.logShareRestaurant(restaurantId: 'r1');
      expect(sink.first.name, 'share_restaurant');
      expect(sink.first.params, {'restaurant_id': 'r1'});
    });

    test('logAccountDelete fires account_delete with no params', () {
      sut.logAccountDelete();
      expect(sink.first.name, 'account_delete');
      expect(sink.first.params, isNull);
    });
  });

  group('user properties', () {
    test('setMembershipTier fires set_user_property', () {
      sut.setMembershipTier('locals_pass');
      expect(sink.first.name, 'set_user_property');
      expect(sink.first.params, {'membership_tier': 'locals_pass'});
    });

    test('setSignInMethod fires set_user_property', () {
      sut.setSignInMethod('apple');
      expect(sink.first.name, 'set_user_property');
      expect(sink.first.params, {'sign_in_method': 'apple'});
    });
  });

  group('no PII', () {
    test('no event contains PII field names', () {
      // Fire every event
      sut
        ..logSignIn(method: 'email')
        ..logSignUp(method: 'email')
        ..logVoteCast(restaurantId: 'r1', cityId: 'c1')
        ..logSaveToggle(restaurantId: 'r1', action: 'save')
        ..logCommentSubmit(restaurantId: 'r1')
        ..logCommentReport(restaurantId: 'r1')
        ..logSuggestionSubmit(cityId: 'c1')
        ..logPaywallView(source: 'top10')
        ..logUpgradeTap(tier: 'localsPass')
        ..logShareRestaurant(restaurantId: 'r1')
        ..logAccountDelete()
        ..setMembershipTier('free')
        ..setSignInMethod('google');

      for (final call in sink) {
        if (call.params == null) continue;
        for (final key in call.params!.keys) {
          expect(
            piiFieldNames.contains(key),
            isFalse,
            reason: 'Event "${call.name}" contains PII field "$key"',
          );
        }
      }
    });

    test('piiFieldNames blocklist covers known PII fields', () {
      expect(piiFieldNames, contains('email'));
      expect(piiFieldNames, contains('displayName'));
      expect(piiFieldNames, contains('display_name'));
      expect(piiFieldNames, contains('photoUrl'));
      expect(piiFieldNames, contains('photo_url'));
      expect(piiFieldNames, contains('commentText'));
      expect(piiFieldNames, contains('comment_text'));
      expect(piiFieldNames, contains('password'));
      expect(piiFieldNames, contains('token'));
    });
  });
}
