// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'search/search_screen.dart';
import 'widgets/app_drawer.dart';
import 'profile/profile_wrapper.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _availabilityMap = {};
  bool _isLoadingAvailability = true;

  User? get currentUser => Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('availability')
          .select(
            'day_of_week, start_time, end_time, is_recurring, date_specific',
          )
          .eq('user_id', userId);

      final availabilityList = response as List;

      // Build availability map
      Map<DateTime, List<Map<String, dynamic>>> tempMap = {};

      // Get next 60 days for recurring events
      final today = DateTime.now();
      final endDate = today.add(const Duration(days: 60));

      for (var avail in availabilityList) {
        if (avail['is_recurring'] == true) {
          // Add recurring availability for next 60 days
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
          // Add specific date availability
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

      setState(() {
        _availabilityMap = tempMap;
        _isLoadingAvailability = false;
      });
    } catch (e) {
      debugPrint('Error loading availability: $e');
      setState(() => _isLoadingAvailability = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text(
          'SkillSwap',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      // Use the separated drawer widget with callback
      drawer: AppDrawer(onProfileUpdate: _loadAvailability),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Section
              _buildWelcomeCard(),
              const SizedBox(height: 24),

              // Calendar Section
              Text(
                'Your Availability',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              if (_isLoadingAvailability)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                _buildCalendar(),

              const SizedBox(height: 16),

              // Selected day availability details
              if (_selectedDay != null) _buildDayDetails(),

              const SizedBox(height: 24),

              // Quick Actions
              Text(
                'Quick Actions',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildQuickActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).primaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome back!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ready to learn and share your skills?',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TableCalendar(
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
      ),
    );
  }

  Widget _buildDayDetails() {
    final availability = _getAvailabilityForDay(_selectedDay!);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  '${_selectedDay!.day}/${_selectedDay!.month}/${_selectedDay!.year}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (availability.isEmpty)
              const Text(
                'No availability set for this day',
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
                        color: slot['is_recurring']
                            ? Colors.blue
                            : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${slot['start_time']} - ${slot['end_time']}',
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: slot['is_recurring']
                              ? Colors.blue.withOpacity(0.1)
                              : Colors.green.withOpacity(0.1),
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
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionCard(
            icon: Icons.search,
            title: 'Find Skills',
            subtitle: 'Discover learners',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildQuickActionCard(
            icon: Icons.schedule,
            title: 'Edit Schedule',
            subtitle: 'Update availability',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              ).then((_) => _loadAvailability());
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
