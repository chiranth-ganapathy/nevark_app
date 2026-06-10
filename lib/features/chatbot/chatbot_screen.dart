import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../services/chatbot_service.dart';

// ── Provider ──────────────────────────────────────────────────────
final chatProvider = ChangeNotifierProvider<ChatbotState>((ref) => ChatbotState());

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});
  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final _ctrl   = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    ref.read(chatProvider).sendMessage(t);
    _ctrl.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(chatProvider);
    final messages = state.messages;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppColors.cyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.smart_toy_outlined,
              color: AppColors.cyan, size: 18)),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Nevark AI',
              style: TextStyle(fontFamily: 'Syne', fontSize: 15,
                fontWeight: FontWeight.w700, color: Colors.white)),
            Text('Live research · MarketStore',
              style: TextStyle(fontFamily: 'Space Mono',
                fontSize: 9, color: AppColors.textMuted)),
          ]),
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: AppColors.textMuted),
            onPressed: () => ref.read(chatProvider).clear()),
        ],
      ),

      body: Column(children: [

        // ── Messages list ──────────────────────────────────────
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(16),
            itemCount: messages.length + (state.typing ? 1 : 0),
            itemBuilder: (_, i) {
              if (state.typing && i == messages.length) {
                return _TypingBubble();
              }
              return _MessageBubble(msg: messages[i]);
            },
          ),
        ),

        // ── Suggestions (show only at start) ──────────────────
        if (messages.length <= 1)
          Container(
            height: 44,
            margin: const EdgeInsets.only(bottom: 4),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: ChatbotService.getSuggestions()
                  .map((s) => _SuggestionChip(
                        text: s,
                        onTap: () {
                          _ctrl.text = s;
                          _send();
                        },
                      ))
                  .toList(),
            ),
          ),

        // ── Input bar ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(
              top: BorderSide(color: AppColors.cardBorder))),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                onSubmitted: (_) => _send(),
                style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Stock, sector, RSI, compare…',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontFamily: 'Space Mono',
                    fontSize: 12),
                  filled: true,
                  fillColor: AppColors.surface2,
                    border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppColors.cardBorder)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppColors.cardBorder)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppColors.cyan, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10)),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.cyan,
                  borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.send_rounded,
                  color: AppColors.bg, size: 18)),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── Message Bubble ───────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isUser
        ? Alignment.centerRight
        : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: msg.isUser
            ? AppColors.cyan.withOpacity(0.15)
            : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: msg.isUser
              ? AppColors.cyan.withOpacity(0.3)
              : AppColors.cardBorder)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: TextStyle(
                color: msg.isUser
                  ? AppColors.cyan
                  : AppColors.textPrimary,
                fontSize: 13,
                height: 1.6,
                fontFamily: msg.isUser ? null : 'Space Mono'),
            ),
            const SizedBox(height: 4),
            Text(
              _fmt(msg.timestamp),
              style: TextStyle(
                fontFamily: 'Space Mono',
                fontSize: 9,
                color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(DateTime t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Typing indicator ─────────────────────────────────────────────
class _TypingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5, color: AppColors.cyan)),
          const SizedBox(width: 10),
          Text('Fetching live data...',
            style: TextStyle(fontFamily: 'Space Mono',
              fontSize: 11, color: AppColors.textMuted)),
        ]),
      ),
    );
  }
}

// ── Suggestion Chip ──────────────────────────────────────────────
class _SuggestionChip extends StatelessWidget {
  final String       text;
  final VoidCallback onTap;
  const _SuggestionChip({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder)),
        child: Center(
          child: Text(text,
            style: TextStyle(
              fontFamily: 'Space Mono',
              fontSize: 11,
              color: AppColors.cyan)),
        ),
      ),
    );
  }
}