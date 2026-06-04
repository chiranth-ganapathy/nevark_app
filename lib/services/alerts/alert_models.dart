enum AlertType {
  price,
  signalChange,
  sector,
  confidenceChange,
  predictionChange,
}

extension AlertTypeLabel on AlertType {
  String get label {
    switch (this) {
      case AlertType.price:
        return 'Price';
      case AlertType.signalChange:
        return 'Signal Change';
      case AlertType.sector:
        return 'Sector';
      case AlertType.confidenceChange:
        return 'Confidence Change';
      case AlertType.predictionChange:
        return 'Prediction Change';
    }
  }
}

/// User-defined alert rule (persisted).
class AlertRule {
  final String id;
  final AlertType type;
  final String target;
  final bool enabled;
  final double? priceThreshold;
  final bool priceAbove;
  final int? confidenceThreshold;
  final String? targetSignal;

  const AlertRule({
    required this.id,
    required this.type,
    required this.target,
    this.enabled = true,
    this.priceThreshold,
    this.priceAbove = true,
    this.confidenceThreshold,
    this.targetSignal,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'target': target,
        'enabled': enabled,
        'priceThreshold': priceThreshold,
        'priceAbove': priceAbove,
        'confidenceThreshold': confidenceThreshold,
        'targetSignal': targetSignal,
      };

  factory AlertRule.fromJson(Map<String, dynamic> json) => AlertRule(
        id: json['id'] as String,
        type: AlertType.values[(json['type'] as int).clamp(0, 4)],
        target: json['target'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
        priceThreshold: (json['priceThreshold'] as num?)?.toDouble(),
        priceAbove: json['priceAbove'] as bool? ?? true,
        confidenceThreshold: json['confidenceThreshold'] as int?,
        targetSignal: json['targetSignal'] as String?,
      );

  AlertRule copyWith({bool? enabled}) => AlertRule(
        id: id,
        type: type,
        target: target,
        enabled: enabled ?? this.enabled,
        priceThreshold: priceThreshold,
        priceAbove: priceAbove,
        confidenceThreshold: confidenceThreshold,
        targetSignal: targetSignal,
      );
}

/// Fired alert shown in history.
class TriggeredAlert {
  final String id;
  final AlertType type;
  final String title;
  final String message;
  final DateTime at;
  bool read;

  TriggeredAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.at,
    this.read = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'title': title,
        'message': message,
        'at': at.toIso8601String(),
        'read': read,
      };

  factory TriggeredAlert.fromJson(Map<String, dynamic> json) => TriggeredAlert(
        id: json['id'] as String,
        type: AlertType.values[(json['type'] as int).clamp(0, 4)],
        title: json['title'] as String? ?? '',
        message: json['message'] as String? ?? '',
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
        read: json['read'] as bool? ?? false,
      );
}
