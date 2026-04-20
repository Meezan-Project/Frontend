import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mezaan/shared/localization/translate_extension.dart';
import 'package:mezaan/shared/theme/app_colors.dart';
import 'package:mezaan/user/services/legal_ai_chat_service.dart';

class UserAIChatScreen extends StatefulWidget {
  const UserAIChatScreen({super.key});

  @override
  State<UserAIChatScreen> createState() => _UserAIChatScreenState();
}

class _UserAIChatScreenState extends State<UserAIChatScreen> {
  final LegalAiChatService _chatService = LegalAiChatService();
  final List<_ChatMessage> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isBootstrapping = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadConversationForCurrentUser();
  }

  Future<void> _loadConversationForCurrentUser() async {
    setState(() {
      _isBootstrapping = true;
    });

    final messagesCollection = _userMessagesCollection();
    if (messagesCollection == null) {
      _messages
        ..clear()
        ..add(_initialAssistantMessage());
      if (mounted) {
        setState(() {
          _isBootstrapping = false;
        });
      }
      return;
    }

    try {
      final snapshot = await messagesCollection
          .orderBy('createdAt')
          .limit(120)
          .get();

      final loaded = snapshot.docs
          .map((doc) {
            final data = doc.data();
            final role = data['role']?.toString().toLowerCase().trim();
            final sender = role == 'user'
                ? _ChatSender.user
                : _ChatSender.assistant;

            final createdAtRaw = data['createdAt'];
            final createdAt = createdAtRaw is Timestamp
                ? createdAtRaw.toDate()
                : DateTime.now();

            return _ChatMessage(
              text: data['text']?.toString() ?? '',
              sender: sender,
              createdAt: createdAt,
              sourceTitles: data['sourceTitles'] is List
                  ? (data['sourceTitles'] as List)
                        .map((item) => item.toString())
                        .toList(growable: false)
                  : const [],
            );
          })
          .where((item) => item.text.trim().isNotEmpty)
          .toList(growable: false);

      _messages
        ..clear()
        ..addAll(loaded);

      if (_messages.isEmpty) {
        final initial = _initialAssistantMessage();
        _messages.add(initial);
        await _persistMessage(initial);
      }
    } catch (_) {
      _messages
        ..clear()
        ..add(_initialAssistantMessage());
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isBootstrapping = false;
    });
    _scrollToBottom();
  }

  _ChatMessage _initialAssistantMessage() {
    return _ChatMessage(
      text:
          'Hi! I am your legal AI assistant. I answer legal questions only and use your Firebase legal dataset when available.',
      sender: _ChatSender.assistant,
      createdAt: DateTime.now(),
    );
  }

  CollectionReference<Map<String, dynamic>>? _userMessagesCollection() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('legal_ai_chats')
        .doc('default')
        .collection('messages');
  }

  Future<void> _persistMessage(_ChatMessage message) async {
    final messagesCollection = _userMessagesCollection();
    if (messagesCollection == null) {
      return;
    }

    try {
      await messagesCollection.add({
        'text': message.text,
        'role': message.sender == _ChatSender.user ? 'user' : 'assistant',
        'createdAt': Timestamp.fromDate(message.createdAt),
        'sourceTitles': message.sourceTitles,
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? text]) async {
    if (_isSending) {
      return;
    }

    final messageText = (text ?? _messageController.text).trim();
    if (messageText.isEmpty) {
      return;
    }

    final userMessage = _ChatMessage(
      text: messageText,
      sender: _ChatSender.user,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _messageController.clear();
      _isSending = true;
    });
    _persistMessage(userMessage);

    _scrollToBottom();

    try {
      final reply = await _chatService.reply(
        userInput: messageText,
        history: _messages
            .map(
              (item) => LegalAiHistoryMessage(
                role: item.sender == _ChatSender.user
                    ? LegalAiRole.user
                    : LegalAiRole.assistant,
                text: item.text,
              ),
            )
            .toList(growable: false),
      );

      if (!mounted) {
        return;
      }

      final assistantMessage = _ChatMessage(
        text: reply.text,
        sender: _ChatSender.assistant,
        createdAt: DateTime.now(),
        sourceTitles: reply.sourceTitles,
      );

      setState(() {
        _messages.add(assistantMessage);
        _isSending = false;
      });
      _persistMessage(assistantMessage);
    } catch (_) {
      if (!mounted) {
        return;
      }

      final failedMessage = _ChatMessage(
        text:
            'I could not process your request right now. Please try again in a moment.',
        sender: _ChatSender.assistant,
        createdAt: DateTime.now(),
      );

      setState(() {
        _messages.add(failedMessage);
        _isSending = false;
      });
      _persistMessage(failedMessage);
    }

    _scrollToBottom();
  }

  void _resetConversation() {
    final currentCollection = _userMessagesCollection();
    final initial = _initialAssistantMessage();

    setState(() {
      _messages
        ..clear()
        ..add(initial);
      _isSending = false;
    });

    if (currentCollection != null) {
      currentCollection.get().then((snapshot) {
        for (final doc in snapshot.docs) {
          doc.reference.delete();
        }
      });
      _persistMessage(initial);
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF0B1220), Color(0xFF131C2C)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          )
        : const LinearGradient(
            colors: [Color(0xFFF8FAFE), Color(0xFFF1F6FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : AppColors.navyBlue,
        title: Text(
          'Legal AI Chat'.translate(),
          style: GoogleFonts.cairo(
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isSending ? null : _resetConversation,
            tooltip: 'New chat'.translate(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Container(
                  padding: EdgeInsets.all(18.r),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24.r),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D2345), Color(0xFF122F6A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 18,
                        offset: Offset(0, 10.h),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Talk with your legal assistant'.translate(),
                        style: GoogleFonts.cairo(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Ask legal questions only. Answers use your Firebase legal dataset and Gemini when configured.'
                            .translate(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          height: 1.38,
                          fontSize: 13.5.sp,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Wrap(
                        spacing: 10.w,
                        runSpacing: 10.h,
                        children: [
                          _SuggestionChip(
                            label: 'Contracts'.translate(),
                            onTap: () => _sendMessage(
                              'What should I check before signing a contract?',
                            ),
                          ),
                          _SuggestionChip(
                            label: 'Court process'.translate(),
                            onTap: () => _sendMessage(
                              'What are the usual steps to file a case in court?',
                            ),
                          ),
                          _SuggestionChip(
                            label: 'Rent dispute'.translate(),
                            onTap: () => _sendMessage(
                              'My landlord refuses to return my deposit. What legal steps should I take?',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    children: [
                      if (_isBootstrapping)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _messages.length,
                            padding: EdgeInsets.only(bottom: 8.h, top: 6.h),
                            itemBuilder: (context, index) {
                              return _ChatBubble(message: _messages[index]);
                            },
                          ),
                        ),
                      if (_isSending)
                        Padding(
                          padding: EdgeInsets.only(bottom: 12.h, top: 4.h),
                          child: Row(
                            children: [
                              const SizedBox(width: 6),
                              const CircularProgressIndicator(strokeWidth: 2.2),
                              SizedBox(width: 12.w),
                              Text(
                                'Analyzing legal dataset...'.translate(),
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color
                                      ?.withOpacity(0.72),
                                  fontSize: 13.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C2B42) : Colors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.18 : 0.08),
                      blurRadius: 18,
                      offset: Offset(0, 8.h),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        minLines: 1,
                        maxLines: 5,
                        style: GoogleFonts.cairo(
                          color: isDark ? Colors.white : AppColors.textDark,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type your legal question'.translate(),
                          hintStyle: TextStyle(
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color?.withOpacity(0.48),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) {
                          if (!_isBootstrapping) {
                            _sendMessage();
                          }
                        },
                      ),
                    ),
                    SizedBox(width: 10.w),
                    GestureDetector(
                      onTap: (_isSending || _isBootstrapping)
                          ? null
                          : _sendMessage,
                      child: Container(
                        width: 48.w,
                        height: 48.w,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D2345), Color(0xFF122F6A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.send_rounded,
                          color: _isSending
                              ? Colors.white.withOpacity(0.5)
                              : Colors.white,
                          size: 22.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _SuggestionChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.14),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final _ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.sender == _ChatSender.user;
    final theme = Theme.of(context);
    final bubbleColor = isUser ? const Color(0xFF0D2345) : theme.cardColor;
    final textColor = isUser ? Colors.white : theme.textTheme.bodyMedium?.color;
    final alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Row(
          mainAxisAlignment: isUser
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            if (!isUser) ...[
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2345).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: const Icon(Icons.smart_toy, color: Color(0xFF0D2345)),
              ),
              SizedBox(width: 10.w),
            ],
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.text,
                      style: GoogleFonts.cairo(
                        color: textColor,
                        fontSize: 14.sp,
                        height: 1.45,
                      ),
                    ),
                    if (!isUser && message.sourceTitles.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Text(
                        'Sources: ${message.sourceTitles.join(' | ')}',
                        style: GoogleFonts.cairo(
                          fontSize: 11.sp,
                          color: theme.textTheme.bodySmall?.color?.withOpacity(
                            0.72,
                          ),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (isUser) ...[
              SizedBox(width: 10.w),
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2345),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: const Icon(Icons.person, color: Colors.white),
              ),
            ],
          ],
        ),
        SizedBox(height: 5.h),
        Text(
          _formatTime(message.createdAt),
          style: GoogleFonts.cairo(
            fontSize: 10.5.sp,
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.58),
          ),
        ),
        SizedBox(height: 8.h),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _ChatMessage {
  final String text;
  final _ChatSender sender;
  final DateTime createdAt;
  final List<String> sourceTitles;

  const _ChatMessage({
    required this.text,
    required this.sender,
    required this.createdAt,
    this.sourceTitles = const [],
  });
}

enum _ChatSender { user, assistant }
