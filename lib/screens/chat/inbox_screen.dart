import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/chat_service.dart';
import 'chat_room_screen.dart';

/// Facebook Messenger + WhatsApp Hybrid Inbox Screen
class InboxScreen extends StatefulWidget {
  final bool isCustomer;
  const InboxScreen({super.key, this.isCustomer = true});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // Signature Hybrid Color Palette
  static const Color messengerBlue = Color(0xFF0084FF);
  static const Color whatsappGreen = Color(0xFF25D366);
  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color surfaceWhite = Colors.white;
  static const Color searchBg = Color(0xFFF1F5F9);
  static const Color dividerColor = Color(0xFFF1F5F9);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return "Just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m";
    if (diff.inDays == 0 && now.day == dt.day) {
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return "$hour:$min $ampm";
    }
    if (diff.inDays == 1 || (diff.inDays < 2 && now.day != dt.day)) return "Yesterday";
    if (diff.inDays < 7) {
      const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      return days[dt.weekday - 1];
    }
    return "${dt.day}/${dt.month}/${dt.year.toString().substring(2)}";
  }

  String _formatCarouselName(String rawName) {
    final words = rawName.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return "User";
    if (words.length == 1) return words[0];
    return "${words[0]}\n${words[1]}";
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _supabase.auth.currentUser;
    final currentUserId = currentUser?.id ?? "";
    final activeThemeColor = widget.isCustomer ? primaryTeal : messengerBlue;

    return Scaffold(
      backgroundColor: surfaceWhite,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        surfaceTintColor: surfaceWhite,
        elevation: 0,
        toolbarHeight: 56.0,
        centerTitle: false,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slateDark, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: activeThemeColor.withValues(alpha: 0.12),
                  child: Text(
                    widget.isCustomer ? "C" : "S",
                    style: GoogleFonts.poppins(color: activeThemeColor, fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: whatsappGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Text(
              "Chats",
              style: GoogleFonts.poppins(
                color: slateDark,
                fontSize: 21,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        actions: [
          _iconActionButton(Icons.camera_alt_outlined, () {}),
          const SizedBox(width: 4),
          _iconActionButton(Icons.edit_square, () {}),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchCapsule(),
            Expanded(
              child: StreamBuilder<List<ChatConversation>>(
                stream: ChatService.streamConversations(currentUserId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return Center(child: CircularProgressIndicator(color: activeThemeColor));
                  }

                  final allConversations = snapshot.data ?? [];
                  final filtered = allConversations.where((c) {
                    final name = (widget.isCustomer ? c.sellerName : c.customerName) ?? "";
                    final last = c.lastMessage ?? "";
                    final query = _searchQuery.toLowerCase();
                    return query.isEmpty ||
                        name.toLowerCase().contains(query) ||
                        last.toLowerCase().contains(query);
                  }).toList();

                  if (allConversations.isEmpty) {
                    return _buildEmptyInboxPlaceholder(activeThemeColor);
                  }

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                    slivers: [
                      if (_searchQuery.isEmpty && allConversations.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _buildActiveContactsCarousel(allConversations, activeThemeColor),
                        ),
                      if (filtered.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              "No messages matching '$_searchQuery'",
                              style: GoogleFonts.poppins(color: slateMuted, fontSize: 13),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final conv = filtered[index];
                              return _buildHybridConversationTile(conv, activeThemeColor);
                            },
                            childCount: filtered.length,
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconActionButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: searchBg,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: slateDark, size: 18),
      ),
    );
  }

  Widget _buildSearchCapsule() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: searchBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
          style: GoogleFonts.poppins(fontSize: 13, color: slateDark, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            isDense: true,
            hintText: "Search chats or messages...",
            hintStyle: GoogleFonts.poppins(color: slateMuted, fontSize: 12.5),
            prefixIcon: const Icon(Icons.search_rounded, color: slateMuted, size: 19),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.cancel_rounded, color: slateMuted, size: 17),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = "");
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveContactsCarousel(List<ChatConversation> convs, Color activeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 106,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: convs.length,
            itemBuilder: (context, index) {
              final c = convs[index];
              final name = (widget.isCustomer ? c.sellerName : c.customerName) ?? "Store";
              final avatar = widget.isCustomer ? c.sellerAvatar : c.customerAvatar;
              final isTyping = widget.isCustomer ? c.isSellerTyping : c.isCustomerTyping;

              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => ChatRoomScreen(
                        conversation: c,
                        isCustomer: widget.isCustomer,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 78,
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: isTyping ? activeColor : Colors.transparent, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 23,
                              backgroundColor: activeColor.withValues(alpha: 0.12),
                              backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                              child: avatar == null || avatar.isEmpty
                                  ? Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : "S",
                                      style: GoogleFonts.poppins(color: activeColor, fontWeight: FontWeight.w800, fontSize: 16),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            right: 3,
                            bottom: 3,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: whatsappGreen,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatCarouselName(name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: slateDark,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 1, color: dividerColor, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildHybridConversationTile(ChatConversation conv, Color activeColor) {
    final name = (widget.isCustomer ? conv.sellerName : conv.customerName) ?? "StyLuxe Partner";
    final avatar = widget.isCustomer ? conv.sellerAvatar : conv.customerAvatar;
    final unread = widget.isCustomer ? conv.customerUnread : conv.sellerUnread;
    final hasUnread = unread > 0;
    final isTyping = widget.isCustomer ? conv.isSellerTyping : conv.isCustomerTyping;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => ChatRoomScreen(
              conversation: conv,
              isCustomer: widget.isCustomer,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: activeColor.withValues(alpha: 0.12),
                  backgroundImage: avatar != null && avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  child: avatar == null || avatar.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : "S",
                          style: GoogleFonts.poppins(color: activeColor, fontWeight: FontWeight.w800, fontSize: 18),
                        )
                      : null,
                ),
                Positioned(
                  right: 1,
                  bottom: 1,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: whatsappGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  color: slateDark,
                                  fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
                                  fontSize: 14.5,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, color: messengerBlue, size: 14),
                          ],
                        ),
                      ),
                      Text(
                        _formatTimestamp(conv.lastMessageAt),
                        style: GoogleFonts.poppins(
                          color: hasUnread ? activeColor : slateMuted,
                          fontSize: 11,
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Row 2: Message preview with WhatsApp double-ticks + Unread badge
                  Row(
                    children: [
                      if (isTyping)
                        Text(
                          "typing...",
                          style: GoogleFonts.poppins(
                            color: activeColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      else ...[
                        if (!hasUnread) ...[
                          const Icon(Icons.done_all_rounded, size: 15, color: messengerBlue),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            conv.lastMessage ?? "Started conversation",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: hasUnread ? slateDark : slateMuted,
                              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ],
                      if (hasUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: activeColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            unread.toString(),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= EMPTY INBOX =================
  Widget _buildEmptyInboxPlaceholder(Color activeColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chat_bubble_outline_rounded, color: activeColor, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              "No Conversations Yet",
              style: GoogleFonts.poppins(color: slateDark, fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              widget.isCustomer
                  ? "Open any product in the store and tap 'Chat with Seller' to ask questions about sizes, fabrics and offers."
                  : "Customer inquiries about your products will appear here in real-time.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: slateMuted, fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
