import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_states.dart';
import '../../core/widgets/glass_card.dart';
import '../../services/alerts/alert_models.dart';
import '../../services/alerts/alert_store.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    AlertStore.instance.addListener(_onStore);
    AlertStore.instance.load();
  }

  @override
  void dispose() {
    AlertStore.instance.removeListener(_onStore);
    super.dispose();
  }

  void _onStore() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final store = AlertStore.instance;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Alerts'),
        actions: [
          if (store.unreadCount > 0)
            TextButton(
              onPressed: () => store.markAllRead(),
              child: Text(
                'Mark read (${store.unreadCount})',
                style: TextStyle(
                  fontFamily: 'Space Mono',
                  fontSize: 10,
                  color: AppColors.cyan,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context),
        backgroundColor: AppColors.cyan,
        foregroundColor: AppColors.bg,
        icon: const Icon(Icons.add_alert_rounded),
        label: const Text('New alert', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            Container(
              color: AppColors.surface,
              child: TabBar(
                indicatorColor: AppColors.cyan,
                labelColor: AppColors.cyan,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: const TextStyle(fontFamily: 'Space Mono', fontSize: 11),
                tabs: const [
                  Tab(text: 'Active Rules'),
                  Tab(text: 'History'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _RulesTab(rules: store.rules),
                  _HistoryTab(history: store.history),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CreateAlertSheet(
        onSave: (rule) async {
          await AlertStore.instance.addRule(rule);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _RulesTab extends StatelessWidget {
  final List<AlertRule> rules;
  const _RulesTab({required this.rules});

  @override
  Widget build(BuildContext context) {
    if (rules.isEmpty) {
      return const AppEmptyState(
        icon: Icons.notifications_off_outlined,
        title: 'No alerts yet',
        subtitle: 'Create price, signal, sector, or confidence alerts.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: rules.length,
      itemBuilder: (_, i) {
        final r = rules[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            accent: AppColors.cyan,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.type.label.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Space Mono',
                          fontSize: 9,
                          color: AppColors.cyan.withValues(alpha: 0.8),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _ruleSummary(r),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: r.enabled,
                  activeThumbColor: AppColors.cyan,
                  onChanged: (v) =>
                      AlertStore.instance.setRuleEnabled(r.id, v),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.red, size: 20),
                  onPressed: () => AlertStore.instance.removeRule(r.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _ruleSummary(AlertRule r) {
  switch (r.type) {
    case AlertType.price:
      final dir = r.priceAbove ? 'above' : 'below';
      return '${r.target} $dir ₹${r.priceThreshold?.toStringAsFixed(0) ?? '?'}';
    case AlertType.signalChange:
      return '${r.target} → ${r.targetSignal ?? 'any change'}';
    case AlertType.predictionChange:
      return '${r.target} prediction updates';
    case AlertType.confidenceChange:
      return '${r.target} confidence ±${r.confidenceThreshold ?? 8}%';
    case AlertType.sector:
      return '${r.target} sector trend change';
  }
}

class _HistoryTab extends StatelessWidget {
  final List<TriggeredAlert> history;
  const _HistoryTab({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const AppEmptyState(
        icon: Icons.history_rounded,
        title: 'No triggered alerts',
        subtitle: 'Alerts appear here when conditions are met during market hours.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (_, i) {
        final h = history[i];
        final clr = h.read ? AppColors.textMuted : AppColors.cyan;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GlassCard(
            accent: h.read ? null : AppColors.amber,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.circle, size: 8, color: clr),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        h.title,
                        style: TextStyle(
                          fontFamily: 'Syne',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: h.read ? AppColors.textMuted : Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      _timeShort(h.at),
                      style: TextStyle(
                        fontFamily: 'Space Mono',
                        fontSize: 9,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  h.message,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _timeShort(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

class _CreateAlertSheet extends StatefulWidget {
  final Future<void> Function(AlertRule rule) onSave;
  const _CreateAlertSheet({required this.onSave});

  @override
  State<_CreateAlertSheet> createState() => _CreateAlertSheetState();
}

class _CreateAlertSheetState extends State<_CreateAlertSheet> {
  AlertType _type = AlertType.price;
  final _targetCtrl = TextEditingController(text: 'TCS');
  final _valueCtrl = TextEditingController(text: '4000');
  bool _priceAbove = true;
  String _signalTarget = 'BUY';

  @override
  void dispose() {
    _targetCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF090F18),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Create Alert',
            style: TextStyle(
              fontFamily: 'Syne',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AlertType.values.map((t) {
              final sel = _type == t;
              return ChoiceChip(
                label: Text(t.label,
                    style: TextStyle(fontFamily: 'Space Mono', fontSize: 10)),
                selected: sel,
                selectedColor: AppColors.cyan.withValues(alpha: 0.2),
                onSelected: (_) => setState(() => _type = t),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _targetCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: _type == AlertType.sector ? 'Sector name' : 'Symbol',
              labelStyle: TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
            ),
          ),
          if (_type == AlertType.price) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _valueCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Price (₹)',
                labelStyle: TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            SwitchListTile(
              title: const Text('Trigger when above',
                  style: TextStyle(color: Colors.white, fontSize: 13)),
              subtitle: Text(
                _priceAbove ? 'Above threshold' : 'Below threshold',
                style: TextStyle(fontFamily: 'Space Mono', fontSize: 10, color: AppColors.textMuted),
              ),
              value: _priceAbove,
              activeThumbColor: AppColors.cyan,
              onChanged: (v) => setState(() => _priceAbove = v),
            ),
          ],
          if (_type == AlertType.signalChange) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _signalTarget,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Notify when signal becomes',
                labelStyle: TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              items: ['BUY', 'SELL', 'HOLD', 'any change']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _signalTarget = v ?? 'BUY'),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _save,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.cyan,
              foregroundColor: AppColors.bg,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Save alert', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final target = _targetCtrl.text.trim().toUpperCase();
    if (target.isEmpty) return;

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    AlertRule rule;

    switch (_type) {
      case AlertType.price:
        final price = double.tryParse(_valueCtrl.text);
        if (price == null) return;
        rule = AlertRule(
          id: id,
          type: _type,
          target: target,
          priceThreshold: price,
          priceAbove: _priceAbove,
        );
        break;
      case AlertType.signalChange:
        rule = AlertRule(
          id: id,
          type: _type,
          target: target,
          targetSignal: _signalTarget == 'any change' ? null : _signalTarget,
        );
        break;
      case AlertType.predictionChange:
        rule = AlertRule(id: id, type: _type, target: target);
        break;
      case AlertType.confidenceChange:
        rule = AlertRule(
          id: id,
          type: _type,
          target: target,
          confidenceThreshold:
              int.tryParse(_valueCtrl.text) ?? 8,
        );
        break;
      case AlertType.sector:
        rule = AlertRule(
          id: id,
          type: _type,
          target: _targetCtrl.text.trim(),
        );
        break;
    }

    await widget.onSave(rule);
  }
}
