import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ChatMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String text;
  final String? productName;
  final String? productImage;
  final String? productPrice;
  final String? productId;
  final bool isRead;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.text,
    this.productName,
    this.productImage,
    this.productPrice,
    this.productId,
    this.isRead = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'text': text,
        'product_name': productName,
        'product_image': productImage,
        'product_price': productPrice,
        'product_id': productId,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id']?.toString() ?? const Uuid().v4(),
        conversationId: json['conversation_id']?.toString() ?? '',
        senderId: json['sender_id']?.toString() ?? '',
        receiverId: json['receiver_id']?.toString() ?? '',
        text: json['text']?.toString() ?? '',
        productName: json['product_name']?.toString(),
        productImage: json['product_image']?.toString(),
        productPrice: json['product_price']?.toString(),
        productId: json['product_id']?.toString(),
        isRead: json['is_read'] == true,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
            : DateTime.now(),
      );
}

class ChatConversation {
  final String id;
  final String customerId;
  final String sellerId;
  final String? customerName;
  final String? sellerName;
  final String? customerAvatar;
  final String? sellerAvatar;
  final String? lastMessage;
  final DateTime lastMessageAt;
  final int customerUnread;
  final int sellerUnread;
  final bool isCustomerTyping;
  final bool isSellerTyping;
  final String? contextProductId;
  final String? contextProductName;
  final String? contextProductImage;
  final String? contextProductPrice;
  final DateTime createdAt;

  ChatConversation({
    required this.id,
    required this.customerId,
    required this.sellerId,
    this.customerName,
    this.sellerName,
    this.customerAvatar,
    this.sellerAvatar,
    this.lastMessage,
    required this.lastMessageAt,
    this.customerUnread = 0,
    this.sellerUnread = 0,
    this.isCustomerTyping = false,
    this.isSellerTyping = false,
    this.contextProductId,
    this.contextProductName,
    this.contextProductImage,
    this.contextProductPrice,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'seller_id': sellerId,
        'customer_name': customerName,
        'seller_name': sellerName,
        'customer_avatar': customerAvatar,
        'seller_avatar': sellerAvatar,
        'last_message': lastMessage,
        'last_message_at': lastMessageAt.toIso8601String(),
        'customer_unread': customerUnread,
        'seller_unread': sellerUnread,
        'is_customer_typing': isCustomerTyping,
        'is_seller_typing': isSellerTyping,
        'context_product_id': contextProductId,
        'context_product_name': contextProductName,
        'context_product_image': contextProductImage,
        'context_product_price': contextProductPrice,
        'created_at': createdAt.toIso8601String(),
      };

  factory ChatConversation.fromJson(Map<String, dynamic> json) => ChatConversation(
        id: json['id']?.toString() ?? const Uuid().v4(),
        customerId: json['customer_id']?.toString() ?? '',
        sellerId: json['seller_id']?.toString() ?? '',
        customerName: json['customer_name']?.toString(),
        sellerName: json['seller_name']?.toString(),
        customerAvatar: json['customer_avatar']?.toString(),
        sellerAvatar: json['seller_avatar']?.toString(),
        lastMessage: json['last_message']?.toString(),
        lastMessageAt: json['last_message_at'] != null
            ? DateTime.tryParse(json['last_message_at']) ?? DateTime.now()
            : DateTime.now(),
        customerUnread: (json['customer_unread'] as num?)?.toInt() ?? 0,
        sellerUnread: (json['seller_unread'] as num?)?.toInt() ?? 0,
        isCustomerTyping: json['is_customer_typing'] == true,
        isSellerTyping: json['is_seller_typing'] == true,
        contextProductId: json['context_product_id']?.toString(),
        contextProductName: json['context_product_name']?.toString(),
        contextProductImage: json['context_product_image']?.toString(),
        contextProductPrice: json['context_product_price']?.toString(),
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
            : DateTime.now(),
      );
}

class ChatService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Get or create conversation between customer and seller
  static Future<ChatConversation> getOrCreateConversation({
    required String customerId,
    required String sellerId,
    String? customerName,
    String? sellerName,
    String? customerAvatar,
    String? sellerAvatar,
    String? productId,
    String? productName,
    String? productImage,
    String? productPrice,
  }) async {
    try {
      // 1. Check if conversation already exists
      final res = await _supabase
          .from('conversations')
          .select('*')
          .eq('customer_id', customerId)
          .eq('seller_id', sellerId)
          .limit(1);

      if (res.isNotEmpty) {
        final existing = ChatConversation.fromJson(res.first);

        // Update product context if newly provided
        if (productId != null && productId != existing.contextProductId) {
          try {
            await _supabase.from('conversations').update({
              'context_product_id': productId,
              'context_product_name': productName,
              'context_product_image': productImage,
              'context_product_price': productPrice,
            }).eq('id', existing.id);
          } catch (_) {}
        }
        return existing;
      }

      // 2. Create new conversation
      final newId = const Uuid().v4();
      final newConv = ChatConversation(
        id: newId,
        customerId: customerId,
        sellerId: sellerId,
        customerName: customerName ?? "Valued Customer",
        sellerName: sellerName ?? "StyLuxe Verified Seller",
        customerAvatar: customerAvatar,
        sellerAvatar: sellerAvatar,
        lastMessage: "Chat started",
        lastMessageAt: DateTime.now(),
        contextProductId: productId,
        contextProductName: productName,
        contextProductImage: productImage,
        contextProductPrice: productPrice,
        createdAt: DateTime.now(),
      );

      await _supabase.from('conversations').insert(newConv.toJson());
      return newConv;
    } catch (e) {
      debugPrint("getOrCreateConversation error: $e");
      // Fallback in-memory conversation object so UI never crashes
      return ChatConversation(
        id: "conv_${customerId}_$sellerId",
        customerId: customerId,
        sellerId: sellerId,
        customerName: customerName ?? "Valued Customer",
        sellerName: sellerName ?? "StyLuxe Verified Seller",
        lastMessage: "Chat started",
        lastMessageAt: DateTime.now(),
        contextProductId: productId,
        contextProductName: productName,
        contextProductImage: productImage,
        contextProductPrice: productPrice,
        createdAt: DateTime.now(),
      );
    }
  }

  /// Send message
  static Future<ChatMessage?> sendMessage({
    required String conversationId,
    required String senderId,
    required String receiverId,
    required String text,
    bool isSenderCustomer = true,
    String? productName,
    String? productImage,
    String? productPrice,
    String? productId,
  }) async {
    final now = DateTime.now();
    final messageId = const Uuid().v4();

    final msg = ChatMessage(
      id: messageId,
      conversationId: conversationId,
      senderId: senderId,
      receiverId: receiverId,
      text: text.trim(),
      productName: productName,
      productImage: productImage,
      productPrice: productPrice,
      productId: productId,
      isRead: false,
      createdAt: now,
    );

    try {
      // 1. Insert message into messages table
      await _supabase.from('messages').insert(msg.toJson());

      // 2. Update conversation last message and unread count
      final updateData = {
        'last_message': text.trim(),
        'last_message_at': now.toIso8601String(),
        if (isSenderCustomer) 'seller_unread': 1 else 'customer_unread': 1,
        if (isSenderCustomer) 'is_customer_typing': false else 'is_seller_typing': false,
      };

      await _supabase.from('conversations').update(updateData).eq('id', conversationId);
      return msg;
    } catch (e) {
      debugPrint("sendMessage error: $e");
      return msg;
    }
  }

  /// Stream messages for a conversation
  static Stream<List<ChatMessage>> streamMessages(String conversationId) {
    try {
      return _supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true)
          .map((data) => data.map((json) => ChatMessage.fromJson(json)).toList());
    } catch (e) {
      debugPrint("streamMessages error: $e");
      return const Stream.empty();
    }
  }

  /// Stream conversations for user (Customer or Seller)
  static Stream<List<ChatConversation>> streamConversations(String userId) {
    try {
      return _supabase
          .from('conversations')
          .stream(primaryKey: ['id'])
          .order('last_message_at', ascending: false)
          .map((data) {
            final filtered = data.where((item) {
              return item['customer_id'] == userId || item['seller_id'] == userId;
            }).toList();
            return filtered.map((json) => ChatConversation.fromJson(json)).toList();
          });
    } catch (e) {
      debugPrint("streamConversations error: $e");
      return const Stream.empty();
    }
  }

  /// Mark conversation as read
  static Future<void> markAsRead(String conversationId, String currentUserId, bool isCustomer) async {
    try {
      // 1. Mark unread counter in conversation
      await _supabase.from('conversations').update({
        if (isCustomer) 'customer_unread': 0 else 'seller_unread': 0,
      }).eq('id', conversationId);

      // 2. Mark messages received by current user as read
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('conversation_id', conversationId)
          .eq('receiver_id', currentUserId);
    } catch (e) {
      debugPrint("markAsRead error: $e");
    }
  }

  /// Set typing status
  static Future<void> setTypingStatus(String conversationId, bool isCustomer, bool isTyping) async {
    try {
      await _supabase.from('conversations').update({
        if (isCustomer) 'is_customer_typing': isTyping else 'is_seller_typing': isTyping,
      }).eq('id', conversationId);
    } catch (e) {
      debugPrint("setTypingStatus error: $e");
    }
  }

  /// Update online presence
  static Future<void> updatePresence(String userId, bool isOnline) async {
    try {
      await _supabase.from('users').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (_) {}
  }
}
