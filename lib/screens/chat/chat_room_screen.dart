import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/chat_service.dart';

/// Facebook Messenger + WhatsApp Hybrid Chat Room Screen
class ChatRoomScreen extends StatefulWidget {
  final ChatConversation conversation;
  final bool isCustomer; // true if current user is customer, false if seller

  const ChatRoomScreen({
    super.key,
    required this.conversation,
    this.isCustomer = true,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  Timer? _typingTimer;
  bool _isLocalTyping = false;
  bool _showProductContext = true;

  StreamSubscription<List<Map<String, dynamic>>>? _convSubscription;
  bool _isOtherPartyTyping = false;

  // Hybrid Signature Theme Colors
  static const Color messengerBlue = Color(0xFF0084FF);
  static const Color messengerLightBlue = Color(0xFF00C6FF);
  static const Color whatsappGreen = Color(0xFF25D366);
  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color primaryTealLight = Color(0xFF14B8A6);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color bubbleWhite = Colors.white;
  static const Color borderColor = Color(0xFFE2E8F0);

  final List<String> _quickInquiries = [
    "Is this in stock?",
    "Can you share exact size chart?",
    "When will it be dispatched?",
    "Is the fabric pure cotton/original?",
    "Do you offer color options?",
  ];

  @override
  void initState() {
    super.initState();
    _markConversationRead();
    _listenToConversationChanges();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _convSubscription?.cancel();
    _clearTypingStatus();
    super.dispose();
  }

  void _markConversationRead() {
    final currentUserId = _supabase.auth.currentUser?.id ?? (widget.isCustomer ? widget.conversation.customerId : widget.conversation.sellerId);
    ChatService.markAsRead(widget.conversation.id, currentUserId, widget.isCustomer);
  }

  void _listenToConversationChanges() {
    try {
      _convSubscription = _supabase
          .from('conversations')
          .stream(primaryKey: ['id'])
          .eq('id', widget.conversation.id)
          .listen((data) {
            if (!mounted || data.isEmpty) return;
            final conv = data.first;
            final otherTyping = widget.isCustomer
                ? (conv['is_seller_typing'] == true)
                : (conv['is_customer_typing'] == true);

            if (_isOtherPartyTyping != otherTyping) {
              setState(() {
                _isOtherPartyTyping = otherTyping;
              });
              if (otherTyping) _scrollToBottom();
            }
          });
    } catch (_) {}
  }

  void _onTextChanged(String text) {
    setState(() {}); // Updates send/mic action icon

    if (text.trim().isNotEmpty && !_isLocalTyping) {
      _isLocalTyping = true;
      ChatService.setTypingStatus(widget.conversation.id, widget.isCustomer, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(milliseconds: 2000), () {
      _clearTypingStatus();
    });
  }

  void _clearTypingStatus() {
    if (_isLocalTyping) {
      _isLocalTyping = false;
      ChatService.setTypingStatus(widget.conversation.id, widget.isCustomer, false);
    }
  }

  Future<void> _sendMessage({String? customText}) async {
    final messageText = (customText ?? _textController.text).trim();
    if (messageText.isEmpty) return;

    if (customText == null) _textController.clear();
    _clearTypingStatus();
    setState(() {});

    final currentUserId = _supabase.auth.currentUser?.id ?? (widget.isCustomer ? widget.conversation.customerId : widget.conversation.sellerId);
    final receiverId = widget.isCustomer ? widget.conversation.sellerId : widget.conversation.customerId;

    await ChatService.sendMessage(
      conversationId: widget.conversation.id,
      senderId: currentUserId,
      receiverId: receiverId,
      text: messageText,
      isSenderCustomer: widget.isCustomer,
      productId: _showProductContext ? widget.conversation.contextProductId : null,
      productName: _showProductContext ? widget.conversation.contextProductName : null,
      productImage: _showProductContext ? widget.conversation.contextProductImage : null,
      productPrice: _showProductContext ? widget.conversation.contextProductPrice : null,
    );

    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutQuad,
        );
      }
    });
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return "$hour:$min $ampm";
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _supabase.auth.currentUser?.id ?? (widget.isCustomer ? widget.conversation.customerId : widget.conversation.sellerId);
    final otherName = widget.isCustomer
        ? (widget.conversation.sellerName ?? "StyLuxe Verified Seller")
        : (widget.conversation.customerName ?? "Valued Customer");
    final otherAvatar = widget.isCustomer ? widget.conversation.sellerAvatar : widget.conversation.customerAvatar;
    final activeColor = widget.isCustomer ? primaryTeal : messengerBlue;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: _buildHybridAppBar(otherName, otherAvatar, activeColor),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Pinned Product Context Card (Marketplace / Catalog style)
            if (_showProductContext && widget.conversation.contextProductName != null)
              _buildProductContextBanner(activeColor),

            // 2. Chat Messages Canvas Stream
            Expanded(
              child: Stack(
                children: [
                  // Subtle WhatsApp-Style Background Wallpaper Tint
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF0F2F5),
                      ),
                    ),
                  ),

                  StreamBuilder<List<ChatMessage>>(
                    stream: ChatService.streamMessages(widget.conversation.id),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return Center(child: CircularProgressIndicator(color: activeColor));
                      }

                      final messages = snapshot.data ?? [];

                      if (messages.isEmpty) {
                        return Column(
                          children: [
                            Expanded(child: _buildEmptyChatPlaceholder(otherName, activeColor)),
                            _buildQuickInquiryChips(activeColor),
                          ],
                        );
                      }

                      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                        physics: const BouncingScrollPhysics(),
                        itemCount: messages.length + (_isOtherPartyTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == messages.length && _isOtherPartyTyping) {
                            return _buildTypingIndicatorBubble(otherName, otherAvatar, activeColor);
                          }

                          final msg = messages[index];
                          final isMe = msg.senderId == currentUserId;
                          final isFirstOrDifferentDate = index == 0 ||
                              messages[index - 1].createdAt.day != msg.createdAt.day;

                          return Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              if (isFirstOrDifferentDate) _buildWhatsAppDatePill(msg.createdAt),
                              _buildHybridMessageBubble(msg, isMe, activeColor),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            // 3. WhatsApp + Messenger Hybrid Input Bar
            _buildHybridInputBar(activeColor),
          ],
        ),
      ),
    );
  }

  // ================= 1. HYBRID APP BAR (WhatsApp + Messenger) =================
  PreferredSizeWidget _buildHybridAppBar(String otherName, String? otherAvatar, Color activeColor) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 1.0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      toolbarHeight: 58.0,
      leadingWidth: 38,
      leading: IconButton(
        padding: const EdgeInsets.only(left: 10),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slateDark, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          // 40px Circular Avatar with Online Ring (Messenger style)
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: activeColor.withValues(alpha: 0.12),
                backgroundImage: otherAvatar != null && otherAvatar.isNotEmpty ? NetworkImage(otherAvatar) : null,
                child: otherAvatar == null || otherAvatar.isEmpty
                    ? Text(
                        otherName.isNotEmpty ? otherName[0].toUpperCase() : "S",
                        style: GoogleFonts.poppins(color: activeColor, fontWeight: FontWeight.w800, fontSize: 16),
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 11.5,
                  height: 11.5,
                  decoration: BoxDecoration(
                    color: whatsappGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // Name and Active Now / Typing Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        otherName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: slateDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded, color: messengerBlue, size: 14),
                  ],
                ),
                Text(
                  _isOtherPartyTyping
                      ? "typing..."
                      : "Active now",
                  style: GoogleFonts.poppins(
                    color: _isOtherPartyTyping ? activeColor : const Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: _isOtherPartyTyping ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // WhatsApp Audio Call
        IconButton(
          icon: const Icon(Icons.call_outlined, color: messengerBlue, size: 21),
          tooltip: "Audio Call",
          onPressed: () => _showCallingToast("Voice Call"),
        ),
        // Messenger Video Call
        IconButton(
          icon: const Icon(Icons.videocam_outlined, color: messengerBlue, size: 23),
          tooltip: "Video Call",
          onPressed: () => _showCallingToast("Video Call"),
        ),
        // Info / Verified Shield
        IconButton(
          icon: const Icon(Icons.info_outline_rounded, color: slateMuted, size: 21),
          tooltip: "Store Info",
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "🔒 End-to-End Verified StyLuxe Business Chat",
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                backgroundColor: slateDark,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _showCallingToast(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "$type feature connecting to verified seller...",
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        backgroundColor: messengerBlue,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ================= 2. PINNED PRODUCT CONTEXT (Facebook Marketplace Card) =================
  Widget _buildProductContextBanner(Color activeColor) {
    final name = widget.conversation.contextProductName ?? "Inquired Item";
    final price = widget.conversation.contextProductPrice ?? "";
    final img = widget.conversation.contextProductImage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Product Thumbnail
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: img != null && img.isNotEmpty
                ? Image.network(img, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.image, size: 20, color: slateMuted))
                : const Icon(Icons.shopping_bag_outlined, size: 20, color: slateMuted),
          ),
          const SizedBox(width: 10),

          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: activeColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "INQUIRING PRODUCT",
                        style: GoogleFonts.poppins(color: activeColor, fontSize: 8.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(color: slateDark, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                if (price.isNotEmpty)
                  Text(
                    price,
                    style: GoogleFonts.poppins(color: activeColor, fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
              ],
            ),
          ),

          // Dismiss Icon
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.close_rounded, color: slateMuted, size: 17),
            onPressed: () => setState(() => _showProductContext = false),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  // ================= 3. HYBRID MESSAGE BUBBLE (Messenger Gradient + WhatsApp Checkmarks) =================
  Widget _buildHybridMessageBubble(ChatMessage msg, bool isMe, Color activeColor) {
    final gradientColors = isMe
        ? (activeColor == primaryTeal
            ? [primaryTeal, primaryTealLight]
            : [messengerBlue, messengerLightBlue])
        : [bubbleWhite, bubbleWhite];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // If Incoming Message, show small sender avatar
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: activeColor.withValues(alpha: 0.15),
              backgroundImage: widget.conversation.sellerAvatar != null && widget.conversation.sellerAvatar!.isNotEmpty
                  ? NetworkImage(widget.conversation.sellerAvatar!)
                  : null,
              child: widget.conversation.sellerAvatar == null || widget.conversation.sellerAvatar!.isEmpty
                  ? Icon(Icons.storefront_rounded, size: 14, color: activeColor)
                  : null,
            ),
            const SizedBox(width: 6),
          ],

          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                gradient: isMe
                    ? LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isMe ? null : bubbleWhite,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: isMe ? activeColor.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Text Content
                  Text(
                    msg.text,
                    style: GoogleFonts.poppins(
                      color: isMe ? Colors.white : slateDark,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Timestamp & WhatsApp-Style Double Blue Ticks
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(msg.createdAt),
                        style: GoogleFonts.poppins(
                          color: isMe ? Colors.white.withValues(alpha: 0.80) : slateMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 14,
                          color: msg.isRead ? const Color(0xFF67E8F9) : Colors.white.withValues(alpha: 0.80),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 150.ms).slideY(begin: 0.04);
  }

  // ================= 4. TYPING INDICATOR BUBBLE (Messenger Jumping Dots) =================
  Widget _buildTypingIndicatorBubble(String otherName, String? otherAvatar, Color activeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: activeColor.withValues(alpha: 0.15),
            backgroundImage: otherAvatar != null && otherAvatar.isNotEmpty ? NetworkImage(otherAvatar) : null,
            child: otherAvatar == null || otherAvatar.isEmpty
                ? Icon(Icons.storefront_rounded, size: 14, color: activeColor)
                : null,
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleWhite,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _AnimatedTypingDots(activeColor: activeColor),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  // ================= 5. QUICK INQUIRY CHIPS (Messenger Quick Replies) =================
  Widget _buildQuickInquiryChips(Color activeColor) {
    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 6, top: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        physics: const BouncingScrollPhysics(),
        itemCount: _quickInquiries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final q = _quickInquiries[index];
          return InkWell(
            onTap: () => _sendMessage(customText: q),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: activeColor.withValues(alpha: 0.35), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                q,
                style: GoogleFonts.poppins(color: activeColor, fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
            ),
          );
        },
      ),
    );
  }

  // ================= 6. HYBRID CHAT INPUT BAR (WhatsApp + Messenger) =================
  Widget _buildHybridInputBar(Color activeColor) {
    final hasText = _textController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 1. Messenger Attachment Icon '+'
          IconButton(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: Icon(Icons.add_circle_rounded, color: activeColor, size: 26),
            onPressed: () => _showAttachmentBottomSheet(activeColor),
          ),

          // 2. WhatsApp / Messenger Input Pill
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Emoji Icon
                  IconButton(
                    padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                    icon: const Icon(Icons.emoji_emotions_outlined, color: slateMuted, size: 21),
                    onPressed: () {},
                  ),

                  // Text Field
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      onChanged: _onTextChanged,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      style: GoogleFonts.poppins(color: slateDark, fontSize: 13.5),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: "Message...",
                        hintStyle: GoogleFonts.poppins(color: slateMuted, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                      ),
                    ),
                  ),

                  // Camera Icon
                  IconButton(
                    padding: const EdgeInsets.only(right: 8, bottom: 8, top: 8),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                    icon: const Icon(Icons.camera_alt_outlined, color: slateMuted, size: 21),
                    onPressed: () => _showAttachmentBottomSheet(activeColor),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 3. Messenger Send Plane or WhatsApp Voice Mic
          InkWell(
            onTap: () {
              if (hasText) {
                _sendMessage();
              } else {
                _showCallingToast("Voice Note");
              }
            },
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: activeColor,
                gradient: LinearGradient(
                  colors: activeColor == primaryTeal
                      ? [primaryTeal, primaryTealLight]
                      : [messengerBlue, messengerLightBlue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(
                hasText ? Icons.send_rounded : Icons.mic_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAttachmentBottomSheet(Color activeColor) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              Text("Share to Chat", style: GoogleFonts.poppins(color: slateDark, fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _attachmentActionItem(Icons.camera_alt_rounded, "Camera", const Color(0xFFEC4899), () => Navigator.pop(ctx)),
                  _attachmentActionItem(Icons.photo_library_rounded, "Gallery", const Color(0xFF8B5CF6), () => Navigator.pop(ctx)),
                  _attachmentActionItem(Icons.shopping_bag_rounded, "Catalog", activeColor, () => Navigator.pop(ctx)),
                  _attachmentActionItem(Icons.location_on_rounded, "Location", const Color(0xFF10B981), () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _attachmentActionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.poppins(color: slateDark, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ================= 7. WHATSAPP DATE PILL =================
  Widget _buildWhatsAppDatePill(DateTime dt) {
    final now = DateTime.now();
    String label;
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      label = "TODAY";
    } else if (dt.day == now.day - 1 && dt.month == now.month && dt.year == now.year) {
      label = "YESTERDAY";
    } else {
      const months = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
      label = "${months[dt.month - 1]} ${dt.day}, ${dt.year}";
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(color: slateMuted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
      ),
    );
  }

  Widget _buildEmptyChatPlaceholder(String otherName, Color activeColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded, color: activeColor, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              "Say hello to $otherName 👋",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: slateDark, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              "Ask about product availability, fabrics, custom sizes, or delivery options.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: slateMuted, fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedTypingDots extends StatefulWidget {
  final Color activeColor;
  const _AnimatedTypingDots({this.activeColor = const Color(0xFF0084FF)});

  @override
  State<_AnimatedTypingDots> createState() => _AnimatedTypingDotsState();
}

class _AnimatedTypingDotsState extends State<_AnimatedTypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final val = (_anim.value + (i * 0.25)) % 1.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6 + (val < 0.5 ? val * 6 : (1.0 - val) * 6),
              decoration: BoxDecoration(
                color: widget.activeColor,
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
