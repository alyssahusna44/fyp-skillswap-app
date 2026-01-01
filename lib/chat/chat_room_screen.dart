// lib/chat/chat_room_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatRoomScreen extends StatefulWidget {
  final int chatRoomId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserProfilePic;

  const ChatRoomScreen({
    super.key,
    required this.chatRoomId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserProfilePic,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _supabase = Supabase.instance.client;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  
  // Realtime subscription
  RealtimeChannel? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _markMessagesAsRead();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    // Properly remove the subscription
    _messageSubscription?.unsubscribe();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    // Create a unique channel name for this chat room
    final channelName = 'chat_room_${widget.chatRoomId}';
    
    // Remove any existing subscription first
    _messageSubscription?.unsubscribe();
    
    // Subscribe to realtime changes
    _messageSubscription = _supabase
        .channel(channelName)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_room_id',
            value: widget.chatRoomId,
          ),
          callback: (payload) {
            debugPrint('New message received: ${payload.newRecord}');
            _handleNewMessage(payload.newRecord);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_room_id',
            value: widget.chatRoomId,
          ),
          callback: (payload) {
            debugPrint('Message updated: ${payload.newRecord}');
            _handleMessageUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  void _handleNewMessage(Map<String, dynamic> newRecord) {
    if (!mounted) return;
    
    final newMessage = {
      'id': newRecord['id'],
      'sender_id': newRecord['sender_id'],
      'message_text': newRecord['message_text'],
      'sent_at': newRecord['sent_at'],
      'is_read': newRecord['is_read'],
      'is_mine': newRecord['sender_id'] == _supabase.auth.currentUser?.id,
    };

    setState(() {
      // Check if message already exists (to avoid duplicates)
      final exists = _messages.any((msg) => msg['id'] == newMessage['id']);
      if (!exists) {
        _messages.add(newMessage);
        // Sort messages by sent_at
        _messages.sort((a, b) => 
          DateTime.parse(a['sent_at']).compareTo(DateTime.parse(b['sent_at']))
        );
      }
    });

    // Mark as read if it's not from current user
    if (!newMessage['is_mine']) {
      _markMessagesAsRead();
    }

    // Scroll to bottom
    _scrollToBottom();
  }

  void _handleMessageUpdate(Map<String, dynamic> updatedRecord) {
    if (!mounted) return;
    
    setState(() {
      final index = _messages.indexWhere((msg) => msg['id'] == updatedRecord['id']);
      if (index != -1) {
        _messages[index] = {
          'id': updatedRecord['id'],
          'sender_id': updatedRecord['sender_id'],
          'message_text': updatedRecord['message_text'],
          'sent_at': updatedRecord['sent_at'],
          'is_read': updatedRecord['is_read'],
          'is_mine': updatedRecord['sender_id'] == _supabase.auth.currentUser?.id,
        };
      }
    });
  }

  Future<void> _loadMessages() async {
    try {
      final messagesData = await _supabase
          .from('chat_messages')
          .select('id, sender_id, message_text, sent_at, is_read')
          .eq('chat_room_id', widget.chatRoomId)
          .order('sent_at', ascending: true);

      if (!mounted) return;

      setState(() {
        _messages = (messagesData as List).map((msg) {
          return {
            'id': msg['id'],
            'sender_id': msg['sender_id'],
            'message_text': msg['message_text'],
            'sent_at': msg['sent_at'],
            'is_read': msg['is_read'],
            'is_mine': msg['sender_id'] == _supabase.auth.currentUser?.id,
          };
        }).toList();
        _isLoading = false;
      });

      // Scroll to bottom after loading
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      debugPrint('Error loading messages: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Failed to load messages: $e');
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      await _supabase.rpc('mark_messages_as_read', params: {
        'p_chat_room_id': widget.chatRoomId,
        'p_user_id': _supabase.auth.currentUser?.id,
      });
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      // Clear the input field immediately for better UX
      _messageController.clear();

      await _supabase.from('chat_messages').insert({
        'chat_room_id': widget.chatRoomId,
        'sender_id': _supabase.auth.currentUser?.id,
        'message_text': messageText,
      });

      // Note: The realtime subscription will handle adding the message to the UI
      
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        _showError('Failed to send message: $e');
        // Restore the message text if sending failed
        _messageController.text = messageText;
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTime(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatDate(String timestamp) {
    final dateTime = DateTime.parse(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.otherUserProfilePic != null
                  ? NetworkImage(widget.otherUserProfilePic!)
                  : null,
              child: widget.otherUserProfilePic == null
                  ? Text(
                      widget.otherUserName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 16),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.otherUserName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadMessages,
            tooltip: 'Refresh messages',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Messages List
                Expanded(
                  child: _messages.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No messages yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Start the conversation!',
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final showDate = index == 0 ||
                                _formatDate(_messages[index - 1]['sent_at']) !=
                                    _formatDate(message['sent_at']);

                            return Column(
                              children: [
                                if (showDate)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _formatDate(message['sent_at']),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                _buildMessageBubble(message),
                              ],
                            );
                          },
                        ),
                ),

                // Message Input
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black,
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: 'Type a message...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                            maxLines: null,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _sendMessage(),
                            enabled: !_isSending,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: _isSending 
                            ? Colors.grey 
                            : Theme.of(context).primaryColor,
                        child: IconButton(
                          icon: _isSending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.send, color: Colors.white),
                          onPressed: _isSending ? null : _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMine = message['is_mine'] as bool;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine ? Theme.of(context).primaryColor : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message['message_text'],
              style: TextStyle(
                color: isMine ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(message['sent_at']),
                  style: TextStyle(
                    color: isMine ? Colors.white70 : Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message['is_read'] ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message['is_read'] ? Colors.blue[200] : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}