import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final LegalAiChatService _chatService = LegalAiChatService();
  final List<_ChatMessage> _messages = [];
  final List<Map<String, dynamic>> _chatSessions = [];
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _currentSessionId;
  bool _isBootstrapping = false;
  bool _isSending = false;
  bool _isLoadingHistory = false;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _loadChatSessions();
    if (_chatSessions.isNotEmpty) {
      _currentSessionId = _chatSessions.first['id'] as String;
    }
    await _loadConversationForSession(_currentSessionId);
  }

  Future<void> _loadChatSessions() async {
    setState(() {
      _isLoadingHistory = true;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('ai_chat_sessions')
          .orderBy('updatedAt', descending: true)
          .get();

      if (mounted) {
        setState(() {
          _chatSessions.clear();
          for (var doc in snapshot.docs) {
            _chatSessions.add({
              'id': doc.id,
              'title': doc.data()['title'] ?? 'New Chat'.translate(),
              'updatedAt': doc.data()['updatedAt'],
            });
          }
          _isLoadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _loadConversationForSession(String? sessionId) async {
    if (sessionId == null) {
      setState(() {
        _messages.clear();
        _currentSessionId = null;
        _isBootstrapping = false;
      });
      return;
    }

    setState(() => _isBootstrapping = true);
    _currentSessionId = sessionId;

    final messagesCollection = _userMessagesCollection(sessionId);
    if (messagesCollection == null) return;

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
              imageUrl: data['imageUrl']?.toString(),
              createdAt: createdAt,
              sourceTitles: data['sourceTitles'] is List
                  ? (data['sourceTitles'] as List)
                        .map((item) => item.toString())
                        .toList(growable: false)
                  : const [],
            );
          })
          .where((item) => item.text.trim().isNotEmpty || item.imageUrl != null)
          .toList(growable: false);

      if (mounted) {
        setState(() {
          _messages
            ..clear()
            ..addAll(loaded);
          _isBootstrapping = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isBootstrapping = false);
      }
    }
  }

  CollectionReference<Map<String, dynamic>>? _userMessagesCollection(
    String sessionId,
  ) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('ai_chat_sessions')
        .doc(sessionId)
        .collection('messages');
  }

  Future<String?> _getOrCreateSessionId(String initialText) async {
    if (_currentSessionId != null) return _currentSessionId;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    final title = initialText.length > 30
        ? '${initialText.substring(0, 30)}...'
        : initialText;

    final docRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .collection('ai_chat_sessions')
        .add({
          'title': title.isEmpty ? 'Image Attachment' : title,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

    _currentSessionId = docRef.id;
    _loadChatSessions(); // Refresh drawer
    return docRef.id;
  }

  Future<void> _persistMessage(_ChatMessage message, String sessionId) async {
    final messagesCollection = _userMessagesCollection(sessionId);
    if (messagesCollection == null) {
      return;
    }

    try {
      await messagesCollection.add({
        'text': message.text,
        'role': message.sender == _ChatSender.user ? 'user' : 'assistant',
        'createdAt': Timestamp.fromDate(message.createdAt),
        'imageUrl': message.imageUrl,
        'sourceTitles': message.sourceTitles,
      });

      await messagesCollection.parent!.update({
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (_) {}
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _AttachmentOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera'.translate(),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              _AttachmentOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery'.translate(),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendMessage([String? text]) async {
    if (_isSending) {
      return;
    }

    final messageText = (text ?? _messageController.text).trim();
    final imageToSend = _selectedImage;

    if (messageText.isEmpty && imageToSend == null) {
      return;
    }

    setState(() => _isSending = true);

    final sessionId = await _getOrCreateSessionId(messageText);
    if (sessionId == null) {
      setState(() => _isSending = false);
      return;
    }

    String? uploadedImageUrl;
    if (imageToSend != null) {
      try {
        final currentUser = FirebaseAuth.instance.currentUser!;
        final ref = FirebaseStorage.instance.ref().child(
          'ai_chats/${currentUser.uid}/$sessionId/${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await ref.putFile(imageToSend);
        uploadedImageUrl = await ref.getDownloadURL();
      } catch (_) {}
    }

    final userMessage = _ChatMessage(
      text: messageText,
      imageUrl: uploadedImageUrl,
      sender: _ChatSender.user,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _messageController.clear();
      _selectedImage = null;
    });
    _persistMessage(userMessage, sessionId);

    _scrollToBottom();

    try {
      // Prepare context for AI including image awareness
      String promptToAi = messageText;
      if (uploadedImageUrl != null) {
        promptToAi += '\n[User attached an image to this prompt]';
      }

      final reply = await _chatService.reply(
        userInput: promptToAi,
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
      _persistMessage(assistantMessage, sessionId);
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
      _persistMessage(failedMessage, sessionId);
    }

    _scrollToBottom();
  }

  void _startNewChat() {
    setState(() {
      _messages.clear();
      _currentSessionId = null;
      _isSending = false;
      _selectedImage = null;
    });
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
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: _buildHistoryDrawer(isDark),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : AppColors.navyBlue,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          'Mezaan AI'.translate(),
          style: GoogleFonts.cairo(
            fontSize: 20.sp,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isSending ? null : _startNewChat,
            tooltip: 'New chat'.translate(),
            icon: const Icon(Icons.add_comment_rounded),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    children: [
                      if (_isBootstrapping)
                        const Expanded(
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_messages.isEmpty)
                        Expanded(child: _buildEmptyState(isDark))
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
              if (_selectedImage != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12.r),
                          child: Image.file(
                            _selectedImage!,
                            height: 70.h,
                            width: 70.h,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          right: -4,
                          top: -4,
                          child: IconButton(
                            icon: const Icon(
                              Icons.cancel,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 4),
                              ],
                            ),
                            onPressed: () =>
                                setState(() => _selectedImage = null),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Container(
                margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
                padding: EdgeInsets.fromLTRB(8.w, 8.h, 14.w, 8.h),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C2B42) : Colors.white,
                  borderRadius: BorderRadius.circular(30.r),
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
                    IconButton(
                      onPressed: (_isSending || _isBootstrapping)
                          ? null
                          : _showAttachmentMenu,
                      icon: Icon(
                        Icons.add_circle_outline_rounded,
                        color: isDark
                            ? Colors.white54
                            : AppColors.textDark.withOpacity(0.5),
                        size: 26.sp,
                      ),
                    ),
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

  Widget _buildHistoryDrawer(bool isDark) {
    return Drawer(
      backgroundColor: isDark
          ? const Color(0xFF0F1726)
          : const Color(0xFFF4F7FB),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(16.r),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _startNewChat();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF1C2B42)
                      : Colors.white,
                  foregroundColor: isDark ? Colors.white : AppColors.navyBlue,
                  minimumSize: Size(double.infinity, 48.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  elevation: 0,
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF2A3550)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  'New Chat'.translate(),
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
              child: Text(
                'Recent History'.translate(),
                style: GoogleFonts.cairo(
                  color: isDark
                      ? Colors.white54
                      : AppColors.textDark.withOpacity(0.6),
                  fontWeight: FontWeight.w600,
                  fontSize: 13.sp,
                ),
              ),
            ),
            if (_isLoadingHistory)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_chatSessions.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No recent chats'.translate(),
                    style: TextStyle(
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _chatSessions.length,
                  itemBuilder: (context, index) {
                    final session = _chatSessions[index];
                    final isSelected = _currentSessionId == session['id'];
                    return ListTile(
                      title: Text(
                        session['title'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.cairo(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? Colors.white : AppColors.navyBlue)
                              : (isDark ? Colors.white70 : AppColors.textDark),
                        ),
                      ),
                      selected: isSelected,
                      selectedTileColor: isDark
                          ? const Color(0xFF1C2B42)
                          : AppColors.navyBlue.withOpacity(0.08),
                      leading: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: isSelected ? AppColors.legalGold : Colors.grey,
                        size: 20.sp,
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        if (!isSelected) {
                          _loadConversationForSession(session['id']);
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 60.h),
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: AppColors.navyBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.navyBlue,
              size: 40,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'How can I help you today?'.translate(),
            style: GoogleFonts.cairo(
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.navyBlue,
            ),
          ),
          SizedBox(height: 30.h),
          Wrap(
            spacing: 12.w,
            runSpacing: 12.h,
            alignment: WrapAlignment.center,
            children: [
              _SuggestionChip(
                label: 'Review a contract'.translate(),
                onTap: () => _sendMessage(
                  'What should I check before signing a contract?',
                ),
              ),
              _SuggestionChip(
                label: 'Labor Law'.translate(),
                onTap: () => _sendMessage(
                  'What are my rights regarding end of service compensation?',
                ),
              ),
              _SuggestionChip(
                label: 'Court process'.translate(),
                onTap: () => _sendMessage(
                  'What are the usual steps to file a case in court?',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28.r,
            backgroundColor: AppColors.navyBlue.withOpacity(0.1),
            child: Icon(icon, color: AppColors.navyBlue, size: 28.sp),
          ),
          SizedBox(height: 8.h),
          Text(label, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
        ],
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
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1C2B42)
              : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
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
    final bubbleColor = isUser
        ? const Color(0xFF0D2345)
        : (theme.brightness == Brightness.dark
              ? const Color(0xFF1C2B42)
              : Colors.white);
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
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF0D2345),
                ),
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
                    if (message.imageUrl != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12.r),
                        child: Image.network(
                          message.imageUrl!,
                          height: 160.h,
                          width: 220.w,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (message.text.isNotEmpty) SizedBox(height: 10.h),
                    ],
                    if (message.text.isNotEmpty)
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
  final String? imageUrl;
  final _ChatSender sender;
  final DateTime createdAt;
  final List<String> sourceTitles;

  const _ChatMessage({
    required this.text,
    this.imageUrl,
    required this.sender,
    required this.createdAt,
    this.sourceTitles = const [],
  });
}

enum _ChatSender { user, assistant }
