import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../market_store.dart';
import 'alert_models.dart';
import 'alert_store.dart';

/// Watches [MarketStore] and fires alerts (no prediction logic changes).
class AlertMonitor {
  AlertMonitor._();
  static final AlertMonitor instance = AlertMonitor._();

  StreamSubscription<MarketSnapshot>? _sub;
  final Map<String, String> _lastSignal = {};
  final Map<String, int> _lastConfidence = {};
  final Map<String, String> _lastSectorTrend = {};

  void start() {
    _sub?.cancel();
    _sub = MarketStore.instance.stream.listen(_onSnapshot);
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> _onSnapshot(MarketSnapshot snap) async {
    if (!await _alertsEnabled()) return;

    final store = AlertStore.instance;
    for (final rule in store.rules) {
      if (!rule.enabled) continue;
      await _evaluate(rule);
    }
  }

  Future<bool> _alertsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final market = prefs.getBool('pref_market_alerts') ?? true;
    final prediction = prefs.getBool('pref_prediction_alerts') ?? true;
    return market || prediction;
  }

  Future<void> _evaluate(AlertRule rule) async {
    final prefs = await SharedPreferences.getInstance();
    final predictionAlerts =
        prefs.getBool('pref_prediction_alerts') ?? true;

    switch (rule.type) {
      case AlertType.price:
        await _checkPrice(rule);
        break;
      case AlertType.signalChange:
        if (predictionAlerts) await _checkSignalChange(rule);
        break;
      case AlertType.predictionChange:
        if (predictionAlerts) await _checkSignalChange(rule, isPrediction: true);
        break;
      case AlertType.confidenceChange:
        if (predictionAlerts) await _checkConfidence(rule);
        break;
      case AlertType.sector:
        await _checkSector(rule);
        break;
    }
  }

  Future<void> _checkPrice(AlertRule rule) async {
    final sym = rule.target.toUpperCase();
    final q = MarketStore.instance.quote(sym);
    if (q == null || q.ltp <= 0 || rule.priceThreshold == null) return;

    final hit = rule.priceAbove
        ? q.ltp >= rule.priceThreshold!
        : q.ltp <= rule.priceThreshold!;

    if (!hit) return;

    final key = 'price_${rule.id}_${q.ltp.toStringAsFixed(0)}';
    if (_firedRecently(key)) return;

    await _fire(
      rule,
      title: '$sym Price Alert',
      message: rule.priceAbove
          ? '$sym crossed above ₹${rule.priceThreshold!.toStringAsFixed(2)} (now ${q.priceStr})'
          : '$sym fell below ₹${rule.priceThreshold!.toStringAsFixed(2)} (now ${q.priceStr})',
    );
  }

  Future<void> _checkSignalChange(AlertRule rule,
      {bool isPrediction = false}) async {
    final sym = rule.target.toUpperCase();
    final pred = MarketStore.instance.prediction(sym);
    if (pred == null) return;

    final current = pred.signalStr;
    final prev = _lastSignal[sym];
    _lastSignal[sym] = current;

    if (prev == null || prev == current) return;

    if (rule.targetSignal != null &&
        rule.targetSignal!.isNotEmpty &&
        current != rule.targetSignal) {
      return;
    }

    final key = 'sig_${rule.id}_$current';
    if (_firedRecently(key)) return;

    await _fire(
      rule,
      title: isPrediction
          ? '$sym Prediction Updated'
          : '$sym Signal Changed',
      message: '$sym moved from $prev → $current (${pred.confidence}% confidence, ${pred.risk} risk)',
    );
  }

  Future<void> _checkConfidence(AlertRule rule) async {
    final sym = rule.target.toUpperCase();
    final pred = MarketStore.instance.prediction(sym);
    if (pred == null) return;

    final current = pred.confidence;
    final prev = _lastConfidence[sym];
    _lastConfidence[sym] = current;

    if (prev == null) return;

    final threshold = rule.confidenceThreshold ?? 8;
    if ((current - prev).abs() < threshold) return;

    if (rule.confidenceThreshold != null &&
        current < rule.confidenceThreshold!) {
      return;
    }

    final key = 'conf_${rule.id}_$current';
    if (_firedRecently(key)) return;

    await _fire(
      rule,
      title: '$sym Confidence Shift',
      message: 'Confidence changed $prev% → $current% (signal ${pred.signalStr})',
    );
  }

  Future<void> _checkSector(AlertRule rule) async {
    final sector = rule.target;
    final sp = MarketStore.instance.sector(sector);
    if (sp == null) return;

    final current = sp.trend;
    final prev = _lastSectorTrend[sector];
    _lastSectorTrend[sector] = current;

    if (prev == null || prev == current) return;

    final key = 'sector_${rule.id}_$current';
    if (_firedRecently(key)) return;

    await _fire(
      rule,
      title: '$sector Sector Alert',
      message: '$sector trend: $prev → $current (${sp.signal}, ${sp.confidence}% confidence)',
    );
  }

  final Map<String, DateTime> _cooldown = {};
  static const _cooldownDuration = Duration(minutes: 15);

  bool _firedRecently(String key) {
    final last = _cooldown[key];
    if (last != null &&
        DateTime.now().difference(last) < _cooldownDuration) {
      return true;
    }
    _cooldown[key] = DateTime.now();
    return false;
  }

  Future<void> _fire(
    AlertRule rule, {
    required String title,
    required String message,
  }) async {
    debugPrint('[Alert] $title — $message');
    await AlertStore.instance.pushTriggered(
      TriggeredAlert(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        type: rule.type,
        title: title,
        message: message,
        at: DateTime.now(),
      ),
    );
  }
}
