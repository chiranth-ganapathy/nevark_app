// Copy this file to angel_one_config.dart and fill in your Angel One credentials.
// angel_one_config.dart is gitignored — do not commit real keys.

class AngelOneConfig {
  static const String apiKey = 'YOUR_API_KEY';
  static const String clientCode = 'YOUR_CLIENT_CODE';
  static const String mpin = 'YOUR_MPIN';
  static const String totpSecret = 'YOUR_TOTP_SECRET';

  static const String baseUrl = 'https://apiconnect.angelbroking.com';
  static const String loginUrl =
      'https://apiconnect.angelbroking.com/rest/auth/angelbroking/user/v1/loginByPassword';
  static const String quoteUrl =
      'https://apiconnect.angelbroking.com/rest/secure/angelbroking/market/v1/quote/';
  static const String searchUrl =
      'https://apiconnect.angelbroking.com/rest/secure/angelbroking/order/v1/searchScrip';
}
