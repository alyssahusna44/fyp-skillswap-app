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

  @override
  void initState() {
    super.initState();
    _loadChatRooms();
    _setupRealtimeSubscription();
  }

  void _setupRealtimeSubscription() {
    // Listen for new messages in real-time
    _supabase
        .channel('chat_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            _loadChatRooms();
          },
        )
        .subscribe();
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

      // Get unread counts
      final unreadData = await _supabase.rpc('get_unread_count', params: {
        'p_user_id': userId,
      }) as List;

      Map<int, int> unreadMap = {};
      for (var item in unreadData) {
        unreadMap[item['chat_room_id'] as int] = item['unread_count'] as int;
      }

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

        // Get skills
        final skill1 = await _supabase
            .from('skills')
            .select('name')
            .eq('id', room['skill_1_id'])
            .single();

        final skill2 = await _supabase
            .from('skills')
            .select('name')
            .eq('id', room['skill_2_id'])
            .single();

        rooms.add({
          'room_id': room['id'],
          'other_user_id': otherUserId,
          'other_user_name': userData?['name'] ?? 'Unknown',
          'profile_picture_url': profileData?['profile_picture_url'],
          'last_message': lastMessage?['message_text'],
          'last_message_time': lastMessage?['sent_at'],
          'is_last_message_mine': lastMessage?['sender_id'] == userId,
          'skill_1': skill1['name'],
          'skill_2': skill2['name'],
        });
      }

      setState(() {
        _chatRooms = rooms;
        _unreadCounts = unreadMap;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading chat rooms: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
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
      leading: CircleAvatar(
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
                unreadCount.toString(),
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
                  child: Icon(Icons.done_all, size: 14, color: Colors.grey[600]),
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
              Text(
                _formatTime(room['last_message_time']),
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatRoomScreen(
              chatRoomId: room['room_id'],
              otherUserId: room['other_user_id'],
              otherUserName: room['other_user_name'],
              otherUserProfilePic: room['profile_picture_url'],
            ),
          ),
        ).then((_) => _loadChatRooms());
      },
    );
  }
}