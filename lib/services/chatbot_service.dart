import 'package:flutter/material.dart';

import 'chatbot/chatbot_engine.dart';
export 'chatbot/chatbot_engine.dart' show ChatSession;

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isUser, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

class ChatbotService {
  static final ChatSession _session = ChatSession();

  static ChatSession get session => _session;

  static Future<String> getResponse(String query) async {
    return ChatbotEngine.respond(query.trim(), _session);
  }

  static void resetSession() => _session.clear();

  static List<String> getSuggestions() => [
        'TCS',
        'Should I buy Reliance?',
        'How is IT sector?',
        'Compare HDFC Bank and ICICI Bank',
        'RSI for Infosys',
        'NIFTY outlook',
        'Best banking stock today',
        'News on TCS',
        'My watchlist',
      ];
}

class ChatbotState extends ChangeNotifier {
  final List<ChatMessage> _msgs = [
    ChatMessage(
      isUser: false,
      text: 'Hi — I\'m NeVark AI, your stock research assistant.\n\n'
          'I use live MarketStore prices, sector data, and the prediction engine.\n\n'
          'Try:\n'
          '• "TCS" or "Analyze Reliance"\n'
          '• "Should I buy INFY?"\n'
          '• "How is Banking sector?"\n'
          '• "Compare HDFC and ICICI"\n'
          '• "What does RSI indicate for Infosys?"\n'
          '• "NIFTY outlook"',
    ),
  ];

  bool _typing = false;

  List<ChatMessage> get messages => List.unmodifiable(_msgs);
  bool get typing => _typing;

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _msgs.add(ChatMessage(text: text.trim(), isUser: true));
    _typing = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 200));

    final reply = await ChatbotService.getResponse(text);

    _msgs.add(ChatMessage(text: reply, isUser: false));
    _typing = false;
    notifyListeners();
  }

  void clear() {
    ChatbotService.resetSession();
    _msgs.clear();
    _msgs.add(
      ChatMessage(
        isUser: false,
        text: 'Chat cleared. Ask about any NSE stock, sector, or index.',
      ),
    );
    notifyListeners();
  }
}
