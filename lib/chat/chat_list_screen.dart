// lib/chat/chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _chatRooms = [];
  Map<int, int> _unreadCounts = {};
  bool _isLoading = true;
  
  // Realtime subscriptions
  RealtimeChannel? _messagesSubscription;
  RealtimeChannel? _roomsSubscription;

  @override
  void initState() {
    super.initState();
    _loadChatRooms();
    _setupRealtimeSubscriptions();
  }

  @override
  void dispose() {
    // Clean up subscriptions
    _messagesSubscription?.unsubscribe();
    _roomsSubscription?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscriptions() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    // Subscribe to new messages in all chat rooms
    _messagesSubscription = _supabase
        .channel('all_chat_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            debugPrint('New message detected in any room: ${payload.newRecord}');
            _handleNewMessage(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            debugPrint('Message updated: ${payload.newRecord}');
            _handleMessageUpdate(payload.newRecord);
          },
        )
        .subscribe();

    // Subscribe to chat room updates
    _roomsSubscription = _supabase
        .channel('all_chat_rooms')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_rooms',
          callback: (payload) {
            debugPrint('New chat room created: ${payload.newRecord}');
            _loadChatRooms();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_rooms',
          callback: (payload) {
            debugPrint('Chat room updated: ${payload.newRecord}');
            _handleRoomUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  void _handleNewMessage(Map<String, dynamic> newMessage) {
    if (!mounted) return;
    
    final chatRoomId = newMessage['chat_room_id'] as int;
    final senderId = newMessage['sender_id'] as String;
    final currentUserId = _supabase.auth.currentUser?.id;
    
    // Find the room in our list
    final roomIndex = _chatRooms.indexWhere((room) => room['room_id'] == chatRoomId);
    
    if (roomIndex != -1) {
      // Update the room's last message
      setState(() {
        _chatRooms[roomIndex]['last_message'] = newMessage['message_text'];
        _chatRooms[roomIndex]['last_message_time'] = newMessage['sent_at'];
        _chatRooms[roomIndex]['is_last_message_mine'] = senderId == currentUserId;
        
        // Update unread count if message is not from current user
        if (senderId != currentUserId) {
          _unreadCounts[chatRoomId] = (_unreadCounts[chatRoomId] ?? 0) + 1;
        }
        
        // Move this room to the top
        final room = _chatRooms.removeAt(roomIndex);
        _chatRooms.insert(0, room);
      });
    } else {
      // New room, reload all rooms
      _loadChatRooms();
    }
  }

  void _handleMessageUpdate(Map<String, dynamic> updatedMessage) {
    if (!mounted) return;
    
    final chatRoomId = updatedMessage['chat_room_id'] as int;
    
    // If message was marked as read, update unread count
    if (updatedMessage['is_read'] == true) {
      _loadUnreadCounts();
    }
  }

  void _handleRoomUpdate(Map<String, dynamic> updatedRoom) {
    if (!mounted) return;
    
    final roomId = updatedRoom['id'] as int;
    final roomIndex = _chatRooms.indexWhere((room) => room['room_id'] == roomId);
    
    if (roomIndex != -1) {
      // Move updated room to top
      setState(() {
        final room = _chatRooms.removeAt(roomIndex);
        _chatRooms.insert(0, room);
      });
    }
  }

  Future<void> _loadChatRooms() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get all chat rooms for current user
      final roomsData = await _supabase
          .from('chat_rooms')
          .select('''
            id,
            user_1_id,
            user_2_id,
            skill_1_id,
            skill_2_id,
            updated_at
          ''')
          .or('user_1_id.eq.$userId,user_2_id.eq.$userId')
          .order('updated_at', ascending: false);

      // Load unread counts
      await _loadUnreadCounts();

      // Fetch details for each room
      List<Map<String, dynamic>> rooms = [];
      for (var room in roomsData as List) {
        final otherUserId =
            room['user_1_id'] == userId ? room['user_2_id'] : room['user_1_id'];

        // Get other user's details
        final userData = await _supabase
            .from('users')
            .select('name')
            .eq('id', otherUserId)
            .maybeSingle();

        final profileData = await _supabase
            .from('profiles')
            .select('profile_picture_url')
            .eq('id', otherUserId)
            .maybeSingle();

        // Get last message
        final lastMessage = await _supabase
            .from('chat_messages')
            .select('message_text, sent_at, sender_id')
            .eq('chat_room_id', room['id'])
            .order('sent_at', ascending: false)
            .limit(1)
            .maybeSingle();

        // Get skills if they exist
        String? skill1Name;
        String? skill2Name;
        
        if (room['skill_1_id'] != null) {
          final skill1 = await _supabase
              .from('skills')
              .select('name')
              .eq('id', room['skill_1_id'])
              .maybeSingle();
          skill1Name = skill1?['name'];
        }
        
        if (room['skill_2_id'] != null) {
          final skill2 = await _supabase
              .from('skills')
              .select('name')
              .eq('id', room['skill_2_id'])
              .maybeSingle();
          skill2Name = skill2?['name'];
        }

        rooms.add({
          'room_id': room['id'],
          'other_user_id': otherUserId,
          'other_user_name': userData?['name'] ?? 'Unknown',
          'profile_picture_url': profileData?['profile_picture_url'],
          'last_message': lastMessage?['message_text'],
          'last_message_time': lastMessage?['sent_at'],
          'is_last_message_mine': lastMessage?['sender_id'] == userId,
          'skill_1': skill1Name,
          'skill_2': skill2Name,
        });
      }

      if (!mounted) return;

      setState(() {
        _chatRooms = rooms;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading chat rooms: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadUnreadCounts() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final unreadData = await _supabase.rpc('get_unread_count', params: {
        'p_user_id': userId,
      }) as List;

      if (!mounted) return;

      Map<int, int> unreadMap = {};
      for (var item in unreadData) {
        unreadMap[item['chat_room_id'] as int] = item['unread_count'] as int;
      }

      setState(() {
        _unreadCounts = unreadMap;
      });
    } catch (e) {
      debugPrint('Error loading unread counts: $e');
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 7) {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      } else if (difference.inDays > 0) {
        return '${difference.inDays}d ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      debugPrint('Error formatting time: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
        actions: [
          // Show total unread count badge
          if (_unreadCounts.values.fold<int>(0, (sum, count) => sum + count) > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _unreadCounts.values.fold<int>(0, (sum, count) => sum + count).toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadChatRooms,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chatRooms.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadChatRooms,
                  child: ListView.builder(
                    itemCount: _chatRooms.length,
                    itemBuilder: (context, index) {
                      final room = _chatRooms[index];
                      final unreadCount = _unreadCounts[room['room_id']] ?? 0;
                      
                      return _buildChatTile(room, unreadCount);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Start chatting with other users!',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(Map<String, dynamic> room, int unreadCount) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: room['profile_picture_url'] != null
                ? NetworkImage(room['profile_picture_url'])
                : null,
            child: room['profile_picture_url'] == null
                ? Text(
                    (room['other_user_name'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          // Online indicator (you can implement this based on your needs)
          // Positioned(
          //   right: 0,
          //   bottom: 0,
          //   child: Container(
          //     width: 14,
          //     height: 14,
          //     decoration: BoxDecoration(
          //       color: Colors.green,
          //       shape: BoxShape.circle,
          //       border: Border.all(color: Colors.white, width: 2),
          //     ),
          //   ),
          // ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              room['other_user_name'] ?? 'Unknown',
              style: TextStyle(
                fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                unreadCount > 99 ? '99+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          // Show skills if available
          if (room['skill_1'] != null && room['skill_2'] != null)
            Text(
              '${room['skill_1']} ↔ ${room['skill_2']}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (room['is_last_message_mine'] == true)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Icon(
                    Icons.done_all,
                    size: 14,
                    color: unreadCount > 0 ? Colors.blue : Colors.grey[600],
                  ),
                ),
              Expanded(
                child: Text(
                  room['last_message'] ?? 'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(room['last_message_time']),
                style: TextStyle(
                  fontSize: 12,
                  color: unreadCount > 0 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey[500],
                  fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: () async {
        // Navigate to chat room
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(
              chatRoomId: room['room_id'],
              otherUserId: room['other_user_id'],
              otherUserName: room['other_user_name'],
              otherUserProfilePic: room['profile_picture_url'],
            ),
          ),
        );
        
        // Reload chats when returning to update read status
        _loadChatRooms();
      },
    );
  }
}