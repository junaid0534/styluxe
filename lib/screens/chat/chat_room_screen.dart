import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/chat_service.dart';

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

  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color bgLight = Color(0xFFF8FAFC);
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
    final activeColor = widget.isCustomer ? primaryTeal : sapphireBlue;

    return Scaffold(
      backgroundColor: bgLight,
      appBar: _buildChatAppBar(otherName, otherAvatar, activeColor),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Pinned Product Context Card (if inquiring about an item)
            if (_showProductContext && widget.conversation.contextProductName != null)
              _buildProductContextBanner(),

            // 2. Chat Messages Stream List
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: ChatService.streamMessages(widget.conversation.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: primaryTeal));
                  }

                  final messages = snapshot.data ?? [];

                  if (messages.isEmpty) {
                    return Column(
                      children: [
                        Expanded(child: _buildEmptyChatPlaceholder(otherName)),
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
                        return _buildTypingIndicatorBubble(otherName);
                      }

                      final msg = messages[index];
                      final isMe = msg.senderId == currentUserId;
                      final isFirstOrDifferentDate = index == 0 ||
                          messages[index - 1].createdAt.day != msg.createdAt.day;

                      return Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (isFirstOrDifferentDate) _buildDateDivider(msg.createdAt),
                          _buildMessageBubble(msg, isMe, activeColor),
                        ],
                      );
                    },
                  );
                },
              ),
            ),

            // 3. Chat Input Bar
            _buildChatInputBar(activeColor),
          ],
        ),
      ),
    );
  }

  // ================= 1. APP BAR =================
  PreferredSizeWidget _buildChatAppBar(String otherName, String? otherAvatar, Color activeColor) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0.5,
      leadingWidth: 40,
      leading: IconButton(
        padding: const EdgeInsets.only(left: 12),
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slateDark, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          // Avatar with glowing online badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: activeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: activeColor.withValues(alpha: 0.3), width: 1.2),
                ),
                alignment: Alignment.center,
                child: otherAvatar != null && otherAvatar.isNotEmpty
                    ? ClipOval(child: Image.network(otherAvatar, fit: BoxFit.cover, width: 38, height: 38))
                    : Text(
                        otherName.isNotEmpty ? otherName[0].toUpperCase() : "S",
                        style: GoogleFonts.poppins(color: activeColor, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),

          // Name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  otherName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: slateDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _isOtherPartyTyping
                      ? "typing..."
                      : "Active Now",
                  style: GoogleFonts.poppins(
                    color: _isOtherPartyTyping ? activeColor : const Color(0xFF10B981),
                    fontSize: 10.5,
                    fontWeight: _isOtherPartyTyping ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.shield_outlined, color: slateMuted, size: 20),
          tooltip: "Verified Chat",
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "Encrypted & Protected StyLuxe Chat",
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                backgroundColor: slateDark,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }

  // ================= 2. PINNED PRODUCT CONTEXT BANNER =================
  Widget _buildProductContextBanner() {
    final name = widget.conversation.contextProductName ?? "Inquired Product";
    final price = widget.conversation.contextProductPrice ?? "";
    final img = widget.conversation.contextProductImage;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          // Product Thumbnail
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: bgLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: img != null && img.isNotEmpty
                ? Image.network(img, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.image, size: 20, color: slateMuted))
                : const Icon(Icons.shopping_bag_outlined, size: 20, color: slateMuted),
          ),
          const SizedBox(width: 10),

          // Product Title & Price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: primaryTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "INQUIRING ITEM",
                        style: GoogleFonts.poppins(color: primaryTeal, fontSize: 8.5, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(color: slateDark, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                if (price.isNotEmpty)
                  Text(
                    price,
                    style: GoogleFonts.poppins(color: primaryTeal, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
              ],
            ),
          ),

          // Close button
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(Icons.close_rounded, color: slateMuted, size: 16),
            onPressed: () => setState(() => _showProductContext = false),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  // ================= 3. MESSAGE BUBBLE =================
  Widget _buildMessageBubble(ChatMessage msg, bool isMe, Color activeColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.storefront_rounded, size: 13, color: activeColor),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: isMe ? activeColor : Colors.white,
                gradient: isMe
                    ? LinearGradient(
                        colors: [activeColor, activeColor == primaryTeal ? primaryDark : const Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
                border: isMe ? null : Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: isMe ? activeColor.withValues(alpha: 0.22) : const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Text
                  Text(
                    msg.text,
                    style: GoogleFonts.poppins(
                      color: isMe ? Colors.white : slateDark,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),

                  // Timestamp & Read ticks
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(msg.createdAt),
                        style: GoogleFonts.poppins(
                          color: isMe ? Colors.white.withValues(alpha: 0.75) : slateMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                          size: 13,
                          color: msg.isRead ? const Color(0xFF67E8F9) : Colors.white.withValues(alpha: 0.75),
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
    ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.05);
  }

  // ================= 4. TYPING INDICATOR BUBBLE =================
  Widget _buildTypingIndicatorBubble(String otherName) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "$otherName is typing",
                  style: GoogleFonts.poppins(color: slateMuted, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 6),
                _AnimatedTypingDots(),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  // ================= 5. QUICK INQUIRY CHIPS =================
  Widget _buildQuickInquiryChips(Color activeColor) {
    return Container(
      height: 34,
      margin: const EdgeInsets.only(bottom: 6),
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
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Text(
                q,
                style: GoogleFonts.poppins(color: slateDark, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          );
        },
      ),
    );
  }

  // ================= 6. CHAT INPUT BAR =================
  Widget _buildChatInputBar(Color activeColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          // Text Input Field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: bgLight,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor),
              ),
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                onChanged: _onTextChanged,
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
                style: GoogleFonts.poppins(color: slateDark, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Type a message...",
                  hintStyle: GoogleFonts.poppins(color: slateMuted.withValues(alpha: 0.7), fontSize: 12.5),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send Button
          InkWell(
            onTap: () => _sendMessage(),
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: activeColor,
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
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateDivider(DateTime dt) {
    final now = DateTime.now();
    String label;
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      label = "Today";
    } else if (dt.day == now.day - 1 && dt.month == now.month && dt.year == now.year) {
      label = "Yesterday";
    } else {
      label = "${dt.day}/${dt.month}/${dt.year}";
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(color: slateMuted, fontSize: 9.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildEmptyChatPlaceholder(String otherName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline_rounded, color: primaryTeal, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              "Start Conversation with $otherName",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: slateDark, fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              "Ask about product sizing, fabric, discounts, or delivery options.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: slateMuted, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedTypingDots extends StatefulWidget {
  @override
  State<_AnimatedTypingDots> createState() => _AnimatedTypingDotsState();
}

class _AnimatedTypingDotsState extends State<_AnimatedTypingDots> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
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
            final val = (_anim.value + (i * 0.2)) % 1.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 5,
              height: 5 + (val < 0.5 ? val * 6 : (1.0 - val) * 6),
              decoration: const BoxDecoration(
                color: Color(0xFF0D9488),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
