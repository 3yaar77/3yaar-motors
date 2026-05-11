import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autoreel/providers/local_chat_provider.dart';
import 'package:autoreel/providers/auth_provider.dart';
import 'package:autoreel/theme.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  const ChatPage({super.key, required this.conversationId});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final uid = context.read<AuthProvider>().currentUser?.uid ?? 'guest';
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    context.read<LocalChatProvider>().sendMessage(conversationId: widget.conversationId, senderId: uid, text: txt);
    _ctrl.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 80, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<LocalChatProvider>();
    final conv = chat.byId(widget.conversationId);
    final me = context.watch<AuthProvider>().currentUser?.uid ?? 'guest';
    final messages = chat.messages(widget.conversationId);

    return Scaffold(
      appBar: AppBar(
        title: Text(conv?.listingTitle ?? 'Chat'),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        actions: [
          if (conv != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Text(conv.sellerName.isEmpty ? 'Seller' : conv.sellerName, style: Theme.of(context).textTheme.labelMedium),
              ),
            ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final m = messages[index];
              final isMe = m.senderId == me;
              final isSystem = m.senderId == 'system';
              final bg = isSystem ? Colors.black.withValues(alpha: 0.2) : (isMe ? MarketplaceColors.accentYellow : Theme.of(context).colorScheme.surfaceContainerHighest);
              final fg = isSystem ? Colors.white70 : (isMe ? Colors.black : Colors.white);
              return Align(
                alignment: isSystem ? Alignment.center : isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  margin: EdgeInsets.only(top: 6, bottom: 6, left: isMe ? 48 : 0, right: isMe ? 0 : 48),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                  child: Text(m.text, style: TextStyle(color: fg)),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Write a message...',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _send,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MarketplaceColors.accentYellow,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ).copyWith(splashFactory: NoSplash.splashFactory),
                  child: const Icon(Icons.send),
                ),
              ),
            ]),
          ),
        )
      ]),
    );
  }
}
