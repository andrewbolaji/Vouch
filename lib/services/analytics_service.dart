import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// A recorded analytics call, used for test assertions.
@immutable
class AnalyticsCall {
  const AnalyticsCall(this.name, [this.params]);
  final String name;
  final Map<String, Object>? params;
}

/// Event name constants. No magic strings anywhere else.
class _Events {
  static const signIn = 'sign_in';
  static const signUp = 'sign_up';
  static const voteCast = 'vote_cast';
  static const saveToggle = 'save_toggle';
  static const commentSubmit = 'comment_submit';
  static const commentReport = 'comment_report';
  static const suggestionSubmit = 'suggestion_submit';
  static const paywallView = 'paywall_view';
  static const upgradeTap = 'upgrade_tap';
  static const shareRestaurant = 'share_restaurant';
  static const accountDelete = 'account_delete';
}

/// Parameter key constants.
class _Params {
  static const method = 'method';
  static const restaurantId = 'restaurant_id';
  static const cityId = 'city_id';
  static const action = 'action';
  static const source = 'source';
  static const tier = 'tier';
}

/// User property key constants.
class _UserProps {
  static const membershipTier = 'membership_tier';
  static const signInMethod = 'sign_in_method';
}

/// Fields that must never appear in any event or user property.
/// Used by tests to enforce the no-PII rule.
const piiFieldNames = {
  'email',
  'displayName',
  'display_name',
  'photoUrl',
  'photo_url',
  'commentText',
  'comment_text',
  'password',
  'token',
};

/// Thin analytics abstraction. Screens and providers call methods here,
/// never FirebaseAnalytics directly.
class AnalyticsService {
  /// Production constructor backed by FirebaseAnalytics.
  AnalyticsService({FirebaseAnalytics? analytics})
      : _analytics = analytics ?? FirebaseAnalytics.instance,
        _sink = null;

  /// Test constructor that records calls into [sink] without Firebase.
  AnalyticsService.test(List<AnalyticsCall> sink)
      : _analytics = null,
        _sink = sink;

  final FirebaseAnalytics? _analytics;
  final List<AnalyticsCall>? _sink;

  /// Navigator observer for automatic screen_view logging.
  FirebaseAnalyticsObserver get navigatorObserver =>
      FirebaseAnalyticsObserver(analytics: _analytics!);

  // -- Events --

  void logSignIn({required String method}) {
    _log(_Events.signIn, {_Params.method: method});
  }

  void logSignUp({required String method}) {
    _log(_Events.signUp, {_Params.method: method});
  }

  void logVoteCast({
    required String restaurantId,
    required String cityId,
  }) {
    _log(_Events.voteCast, {
      _Params.restaurantId: restaurantId,
      _Params.cityId: cityId,
    });
  }

  void logSaveToggle({
    required String restaurantId,
    required String action,
  }) {
    _log(_Events.saveToggle, {
      _Params.restaurantId: restaurantId,
      _Params.action: action,
    });
  }

  void logCommentSubmit({required String restaurantId}) {
    _log(_Events.commentSubmit, {_Params.restaurantId: restaurantId});
  }

  void logCommentReport({required String restaurantId}) {
    _log(_Events.commentReport, {_Params.restaurantId: restaurantId});
  }

  void logSuggestionSubmit({required String cityId}) {
    _log(_Events.suggestionSubmit, {_Params.cityId: cityId});
  }

  void logPaywallView({required String source}) {
    _log(_Events.paywallView, {_Params.source: source});
  }

  void logUpgradeTap({required String tier}) {
    _log(_Events.upgradeTap, {_Params.tier: tier});
  }

  void logShareRestaurant({required String restaurantId}) {
    _log(_Events.shareRestaurant, {_Params.restaurantId: restaurantId});
  }

  void logAccountDelete() {
    _log(_Events.accountDelete);
  }

  // -- User properties --

  void setMembershipTier(String tier) {
    _setUserProperty(_UserProps.membershipTier, tier);
  }

  void setSignInMethod(String method) {
    _setUserProperty(_UserProps.signInMethod, method);
  }

  // -- Internals --

  void _log(String name, [Map<String, Object>? params]) {
    if (_sink != null) {
      _sink.add(AnalyticsCall(name, params));
      return;
    }
    // Fire-and-forget; analytics failures are non-fatal.
    unawaited(_analytics?.logEvent(name: name, parameters: params));
  }

  void _setUserProperty(String name, String value) {
    if (_sink != null) {
      _sink.add(AnalyticsCall('set_user_property', {name: value}));
      return;
    }
    // Fire-and-forget; analytics failures are non-fatal.
    unawaited(_analytics?.setUserProperty(name: name, value: value));
  }
}
