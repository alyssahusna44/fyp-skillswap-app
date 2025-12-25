// lib/profile/user_profile_view_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:table_calendar/table_calendar.dart';
import '../chat/chat_room_screen.dart';
import '../reviews/write_review_screen.dart';
import '../reviews/user_reviews_screen.dart';

class UserProfileViewScreen extends StatefulWidget {
  final String userId;

  const UserProfileViewScreen({super.key, required this.userId});

  @override
  State<UserProfileViewScreen> createState() => _UserProfileViewScreenState();
}

class _UserProfileViewScreenState extends State<UserProfileViewScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;

  // Profile data
  String? _name;
  String? _bio;
  String? _location;
  String? _phoneNumber;
  String? _profilePictureUrl;
  double _averageRating = 0.0;
  List<String> _skillsToTeach = [];
  List<String> _skillsToLearn = [];
  List<Map<String, dynamic>> _availability = [];

  // Calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _availabilityMap = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      // Load profile data
      final profileData = await _supabase
          .from('profiles')
          .select(
            'bio, profile_picture_url, location, phone_number, average_rating',
          )
          .eq('id', widget.userId)
          .maybeSingle();

      // Load user data (name)
      final userData = await _supabase
          .from('users')
          .select('name')
          .eq('id', widget.userId)
          .maybeSingle();

      // Load skills
      final skillsData = await _supabase
          .from('user_skills')
          .select('''
            skill_level,
            skills!inner(name)
          ''')
          .eq('user_id', widget.userId);

      // Load availability
      final availabilityData = await _supabase
          .from('availability')
          .select(
            'day_of_week, start_time, end_time, is_recurring, date_specific',
          )
          .eq('user_id', widget.userId);

      setState(() {
        _name = userData?['name'];
        _bio = profileData?['bio'];
        _location = profileData?['location'];
        _phoneNumber = profileData?['phone_number'];
        _profilePictureUrl = profileData?['profile_picture_url'];
        _averageRating = (profileData?['average_rating'] ?? 0.0).toDouble();

        // Separate skills
        _skillsToTeach = (skillsData as List)
            .where((s) => s['skill_level'] == 'TEACH')
            .map((s) => s['skills']['name'] as String)
            .toList();

        _skillsToLearn = (skillsData as List)
            .where((s) => s['skill_level'] == 'LEARN')
            .map((s) => s['skills']['name'] as String)
            .toList();

        _availability = (availabilityData as List)
            .map(
              (a) => {
                'day_of_week': a['day_of_week'],
                'start_time': a['start_time'],
                'end_time': a['end_time'],
                'is_recurring': a['is_recurring'] ?? true,
                'date_specific': a['date_specific'],
              },
            )
            .toList();

        // Build availability map for calendar
        _buildAvailabilityMap();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() => _isLoading = false);
      _showError('Failed to load profile: $e');
    }
  }

  void _buildAvailabilityMap() {
    Map<DateTime, List<Map<String, dynamic>>> tempMap = {};
    final today = DateTime.now();
    final endDate = today.add(const Duration(days: 60));

    for (var avail in _availability) {
      if (avail['is_recurring'] == true) {
        final dayOfWeek = _getDayNumber(avail['day_of_week']);

        for (
          DateTime date = today;
          date.isBefore(endDate);
          date = date.add(const Duration(days: 1))
        ) {
          if (date.weekday == dayOfWeek) {
            final dateKey = DateTime(date.year, date.month, date.day);
            tempMap[dateKey] = tempMap[dateKey] ?? [];
            tempMap[dateKey]!.add({
              'start_time': avail['start_time'],
              'end_time': avail['end_time'],
              'is_recurring': true,
            });
          }
        }
      } else if (avail['date_specific'] != null) {
        final date = DateTime.parse(avail['date_specific']);
        final dateKey = DateTime(date.year, date.month, date.day);
        tempMap[dateKey] = tempMap[dateKey] ?? [];
        tempMap[dateKey]!.add({
          'start_time': avail['start_time'],
          'end_time': avail['end_time'],
          'is_recurring': false,
        });
      }
    }

    _availabilityMap = tempMap;
  }

  int _getDayNumber(String dayOfWeek) {
    const days = {
      'MON': 1,
      'TUE': 2,
      'WED': 3,
      'THU': 4,
      'FRI': 5,
      'SAT': 6,
      'SUN': 7,
    };
    return days[dayOfWeek] ?? 1;
  }

  List<Map<String, dynamic>> _getAvailabilityForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _availabilityMap[dateKey] ?? [];
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _makePhoneCall() async {
    if (_phoneNumber == null || _phoneNumber!.isEmpty) {
      _showError('No phone number available');
      return;
    }

    final Uri phoneUri = Uri(scheme: 'tel', path: _phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      _showError('Cannot make phone call');
    }
  }

  Future<void> _sendSMS() async {
    if (_phoneNumber == null || _phoneNumber!.isEmpty) {
      _showError('No phone number available');
      return;
    }

    final Uri smsUri = Uri(scheme: 'sms', path: _phoneNumber);
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    } else {
      _showError('Cannot send SMS');
    }
  }

  Future<void> _sendEmail() async {
    try {
      final userData = await _supabase
          .from('users')
          .select('email')
          .eq('id', widget.userId)
          .maybeSingle();

      final email = userData?['email'];
      if (email == null) {
        _showError('No email available');
        return;
      }

      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: email,
        query: 'subject=Skill Exchange Inquiry',
      );

      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        _showError('Cannot send email');
      }
    } catch (e) {
      _showError('Failed to get email');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_name ?? 'User Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_border),
            tooltip: 'Leave a Review',
            onPressed: () {
              // TODO: Navigate to review screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Review feature coming soon!')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            _buildProfileHeader(),

            const SizedBox(height: 16),

            // Contact Buttons
            if (_phoneNumber != null && _phoneNumber!.isNotEmpty)
              _buildContactButtons(),

            const SizedBox(height: 16),

            // Bio Section
            if (_bio != null && _bio!.isNotEmpty) _buildBioSection(),

            // Skills Section
            _buildSkillsSection(),

            // Availability Section
            _buildAvailabilitySection(),

            // Reviews Section (placeholder)
            _buildReviewsSection(),

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          // Profile Picture
          CircleAvatar(
            radius: 60,
            backgroundImage: _profilePictureUrl != null
                ? NetworkImage(_profilePictureUrl!)
                : null,
            child: _profilePictureUrl == null
                ? Text(
                    (_name ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(fontSize: 48, color: Colors.white),
                  )
                : null,
          ),
          const SizedBox(height: 16),

          // Name
          Text(
            _name ?? 'Unknown User',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Location
          if (_location != null && _location!.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 18),
                const SizedBox(width: 4),
                Text(
                  _location!,
                  style: const TextStyle(fontSize: 16, color: Colors.white70),
                ),
              ],
            ),
          const SizedBox(height: 12),

          // Rating
          if (_averageRating > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    _averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    ' / 5.0',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContactButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _startChat,
                  icon: const Icon(Icons.chat_bubble),
                  label: const Text('Message'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _writeReview,
                  icon: const Icon(Icons.star),
                  label: const Text('Review'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.amber[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (_phoneNumber != null && _phoneNumber!.isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _makePhoneCall,
                    icon: const Icon(Icons.phone),
                    label: const Text('Call'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sendSMS,
                    icon: const Icon(Icons.message),
                    label: const Text('SMS'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ] else
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _sendEmail,
                    icon: const Icon(Icons.email),
                    label: const Text('Email'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startChat() async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Get a skill from each user for the chat room
      final mySkills = await _supabase
          .from('user_skills')
          .select('skill_id')
          .eq('user_id', currentUserId)
          .eq('skill_level', 'TEACH')
          .limit(1)
          .maybeSingle();

      final theirSkills = await _supabase
          .from('user_skills')
          .select('skill_id')
          .eq('user_id', widget.userId)
          .eq('skill_level', 'LEARN')
          .limit(1)
          .maybeSingle();

      if (mySkills == null || theirSkills == null) {
        _showError('Cannot start chat: skill information missing');
        return;
      }

      // Get or create chat room
      final roomId =
          await _supabase.rpc(
                'get_or_create_chat_room',
                params: {
                  'p_user_1_id': currentUserId,
                  'p_user_2_id': widget.userId,
                  'p_skill_1_id': mySkills['skill_id'],
                  'p_skill_2_id': theirSkills['skill_id'],
                },
              )
              as int;

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatRoomScreen(
            chatRoomId: roomId,
            otherUserId: widget.userId,
            otherUserName: _name ?? 'User',
            otherUserProfilePic: _profilePictureUrl,
          ),
        ),
      );
    } catch (e) {
      _showError('Failed to start chat: $e');
    }
  }

  Future<void> _writeReview() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WriteReviewScreen(
          reviewedUserId: widget.userId,
          reviewedUserName: _name ?? 'User',
          reviewedUserProfilePic: _profilePictureUrl,
        ),
      ),
    );

    if (result == true) {
      // Reload profile to update rating
      _loadUserProfile();
    }
  }

  Widget _buildBioSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.person, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'About',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _bio!,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkillsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'Skills',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Skills to Teach
              if (_skillsToTeach.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(Icons.school, size: 20, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Can Teach',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _skillsToTeach.map((skill) {
                    return Chip(
                      label: Text(skill),
                      backgroundColor: Colors.green[50],
                      side: BorderSide(color: Colors.green[200]!),
                      labelStyle: TextStyle(color: Colors.green[700]),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // Skills to Learn
              if (_skillsToLearn.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 20,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Wants to Learn',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _skillsToLearn.map((skill) {
                    return Chip(
                      label: Text(skill),
                      backgroundColor: Colors.blue[50],
                      side: BorderSide(color: Colors.blue[200]!),
                      labelStyle: TextStyle(color: Colors.blue[700]),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilitySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Availability',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_availability.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No availability set',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else ...[
                TableCalendar(
                  firstDay: DateTime.now().subtract(const Duration(days: 30)),
                  lastDay: DateTime.now().add(const Duration(days: 365)),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  eventLoader: _getAvailabilityForDay,
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    outsideDaysVisible: false,
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },
                ),
                const SizedBox(height: 16),

                // Selected day details
                if (_selectedDay != null) _buildDayDetails(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDayDetails() {
    final availability = _getAvailabilityForDay(_selectedDay!);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event,
                color: Theme.of(context).primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (availability.isEmpty)
            const Text(
              'Not available on this day',
              style: TextStyle(color: Colors.grey),
            )
          else
            ...availability.map(
              (slot) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  children: [
                    Icon(
                      slot['is_recurring']
                          ? Icons.repeat
                          : Icons.event_available,
                      size: 16,
                      color: slot['is_recurring'] ? Colors.blue : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${slot['start_time']} - ${slot['end_time']}',
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: slot['is_recurring']
                            ? Colors.blue
                            : Colors.green,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        slot['is_recurring'] ? 'Weekly' : 'One-time',
                        style: TextStyle(
                          fontSize: 12,
                          color: slot['is_recurring']
                              ? Colors.blue[700]
                              : Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Reviews',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserReviewsScreen(
                            userId: widget.userId,
                            userName: _name ?? 'User',
                          ),
                        ),
                      );
                    },
                    child: const Text('See All'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_averageRating > 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber[200]!),
                  ),
                  child: Row(
                    children: [
                      Column(
                        children: [
                          Text(
                            _averageRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[700],
                            ),
                          ),
                          Row(
                            children: List.generate(5, (index) {
                              return Icon(
                                index < _averageRating.round()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber[700],
                                size: 20,
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Overall Rating',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Based on user reviews',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.rate_review,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No reviews yet',
                        style: TextStyle(color: Colors.grey[600]),
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
