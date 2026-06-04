import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'alert_models.dart';

/// Persists alert rules and triggered history.
class AlertStore extends ChangeNotifier {
  AlertStore._();
  static final AlertStore instance = AlertStore._();

  static const _rulesKey = 'alert_rules_v1';
  static const _historyKey = 'alert_history_v1';
  static const _maxHistory = 80;

  final List<AlertRule> _rules = [];
  final List<TriggeredAlert> _history = [];

  List<AlertRule> get rules => List.unmodifiable(_rules);
  List<TriggeredAlert> get history => List.unmodifiable(_history);
  int get unreadCount => _history.where((h) => !h.read).length;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rulesRaw = prefs.getString(_rulesKey);
      final histRaw = prefs.getString(_historyKey);

      _rules.clear();
      if (rulesRaw != null) {
        final list = jsonDecode(rulesRaw) as List;
        _rules.addAll(
          list.map((e) => AlertRule.fromJson(e as Map<String, dynamic>)),
        );
      }

      _history.clear();
      if (histRaw != null) {
        final list = jsonDecode(histRaw) as List;
        _history.addAll(
          list.map((e) => TriggeredAlert.fromJson(e as Map<String, dynamic>)),
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[AlertStore] load failed: $e');
    }
  }

  Future<void> addRule(AlertRule rule) async {
    _rules.add(rule);
    await _saveRules();
    notifyListeners();
  }

  Future<void> removeRule(String id) async {
    _rules.removeWhere((r) => r.id == id);
    await _saveRules();
    notifyListeners();
  }

  Future<void> setRuleEnabled(String id, bool enabled) async {
    final i = _rules.indexWhere((r) => r.id == id);
    if (i < 0) return;
    _rules[i] = _rules[i].copyWith(enabled: enabled);
    await _saveRules();
    notifyListeners();
  }

  Future<void> pushTriggered(TriggeredAlert alert) async {
    _history.insert(0, alert);
    while (_history.length > _maxHistory) {
      _history.removeLast();
    }
    await _saveHistory();
    notifyListeners();
  }

  Future<void> markAllRead() async {
    for (final h in _history) {
      h.read = true;
    }
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> _saveRules() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _rulesKey,
      jsonEncode(_rules.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      jsonEncode(_history.map((h) => h.toJson()).toList()),
    );
  }
}
