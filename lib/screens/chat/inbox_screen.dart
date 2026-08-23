import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/chat_service.dart';
import 'chat_room_screen.dart';

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

  static const Color primaryTeal = Color(0xFF0D9488);
  static const Color sapphireBlue = Color(0xFF2563EB);
  static const Color slateDark = Color(0xFF0F172A);
  static const Color slateMuted = Color(0xFF64748B);
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color borderColor = Color(0xFFE2E8F0);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatRelativeTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays == 1) return "Yesterday";
    return "${dt.day}/${dt.month}";
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _supabase.auth.currentUser;
    final currentUserId = currentUser?.id ?? "";
    final activeThemeColor = widget.isCustomer ? primaryTeal : sapphireBlue;

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 46.0,
        centerTitle: true,
        title: Text(
          "StyLuxe",
          style: GoogleFonts.poppins(
            color: slateDark,
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: slateDark, size: 16),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. Header Banner
            _buildHeaderBanner(activeThemeColor),

            // 2. Search Filter Bar
            _buildSearchBar(),

            // 3. Conversations List Stream
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

                  if (filtered.isEmpty) {
                    return _buildEmptyInboxPlaceholder();
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final conv = filtered[index];
                      return _buildConversationCard(conv, activeThemeColor);
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

  // ================= 1. HEADER BANNER =================
  Widget _buildHeaderBanner(Color activeColor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: activeColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.forum_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isCustomer ? "Seller Direct Messages" : "Customer Inquiries & Chat",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                Text(
                  widget.isCustomer
                      ? "Chat directly with store owners before and after orders"
                      : "Answer customer questions, discuss sizes & boost sales",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.04);
  }

  // ================= 2. SEARCH BAR =================
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val.trim()),
          style: GoogleFonts.poppins(fontSize: 12.5, color: slateDark),
          decoration: InputDecoration(
            hintText: "Search conversations or messages...",
            hintStyle: GoogleFonts.poppins(color: slateMuted.withValues(alpha: 0.7), fontSize: 12),
            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: slateMuted),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  // ================= 3. CONVERSATION CARD =================
  Widget _buildConversationCard(ChatConversation conv, Color activeColor) {
    final otherName = widget.isCustomer
        ? (conv.sellerName ?? "StyLuxe Verified Seller")
        : (conv.customerName ?? "Valued Customer");
    final otherAvatar = widget.isCustomer ? conv.sellerAvatar : conv.customerAvatar;
    final unread = widget.isCustomer ? conv.customerUnread : conv.sellerUnread;
    final hasUnread = unread > 0;
    final isOtherTyping = widget.isCustomer ? conv.isSellerTyping : conv.isCustomerTyping;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatRoomScreen(
              conversation: conv,
              isCustomer: widget.isCustomer,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: hasUnread ? activeColor.withValues(alpha: 0.5) : borderColor),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar with online green dot
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: activeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: otherAvatar != null && otherAvatar.isNotEmpty
                      ? ClipOval(child: Image.network(otherAvatar, width: 44, height: 44, fit: BoxFit.cover))
                      : Text(
                          otherName.isNotEmpty ? otherName[0].toUpperCase() : "S",
                          style: GoogleFonts.poppins(color: activeColor, fontWeight: FontWeight.w800, fontSize: 17),
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
            const SizedBox(width: 12),

            // Middle Content: Name, Last Message, Product Context
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          otherName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: slateDark,
                            fontSize: 13,
                            fontWeight: hasUnread ? FontWeight.w800 : FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        _formatRelativeTime(conv.lastMessageAt),
                        style: GoogleFonts.poppins(
                          color: hasUnread ? activeColor : slateMuted,
                          fontSize: 10,
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),

                  // Product context badge (if any)
                  if (conv.contextProductName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          const Icon(Icons.shopping_bag_outlined, size: 11, color: primaryTeal),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              conv.contextProductName!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(color: primaryTeal, fontSize: 10, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Last message / typing indicator
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isOtherTyping ? "typing..." : (conv.lastMessage ?? "No messages yet"),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: isOtherTyping
                                ? activeColor
                                : (hasUnread ? slateDark : slateMuted),
                            fontSize: 11.5,
                            fontWeight: (hasUnread || isOtherTyping) ? FontWeight.w700 : FontWeight.w500,
                            fontStyle: isOtherTyping ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: activeColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "$unread",
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
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
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildEmptyInboxPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.forum_outlined, color: slateMuted, size: 36),
            ),
            const SizedBox(height: 12),
            Text(
              "No Messages Yet",
              style: GoogleFonts.poppins(color: slateDark, fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              widget.isCustomer
                  ? "Open any product and tap 'Chat with Seller' to ask sizing, fabric, or delivery questions."
                  : "Customer product inquiries and chat messages will appear here.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: slateMuted, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}
