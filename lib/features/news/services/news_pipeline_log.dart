import 'package:flutter/foundation.dart';

/// Temporary pipeline tracing — filter logcat/console with [NewsPipeline].
class NewsPipelineLog {
  static void i(String message) => debugPrint('[NewsPipeline] $message');

  static void api(String provider, String url, int status, int bodyLen) {
    i('$provider → HTTP $status, body ${bodyLen}B\n  $url');
  }

  static void parsed(String provider, int count, {String? sampleTitle}) {
    final sample = sampleTitle != null && sampleTitle.isNotEmpty
        ? ' · e.g. "${sampleTitle.length > 60 ? '${sampleTitle.substring(0, 60)}…' : sampleTitle}"'
        : '';
    i('$provider parsed $count articles$sample');
  }

  static void state(String label, {int? count, String? error}) {
    if (error != null) {
      i('Provider $label: ERROR — $error');
    } else {
      i('Provider $label: ${count ?? 0} articles');
    }
  }

  static void ui(String label, {int? count, bool loading = false, bool error = false}) {
    if (loading) {
      i('UI $label: loading');
    } else if (error) {
      i('UI $label: error');
    } else {
      i('UI $label: rendering ${count ?? 0} articles');
    }
  }
}
