/// Marketaux API configuration.
/// Pass at build time: flutter run --dart-define=MARKETAUX_API_KEY=your_key
class NewsConfig {
  static const String apiKey = String.fromEnvironment(
    'MARKETAUX_API_KEY',
    defaultValue: 'QaBeBABteyCLJZr6ik3YK0tihCm4FXoeoQKG4gTg',
  );

  static const String baseUrl = 'https://api.marketaux.com/v1/news/all';

  static bool get hasApiKey => apiKey.isNotEmpty && apiKey != 'YOUR_KEY_HERE';
}
