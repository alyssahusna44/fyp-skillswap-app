// Replace lib/widgets/app_drawer.dart content with this updated version:

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_wrapper.dart';
import '../profile/profile_wrapper.dart';
import '../search/search_screen.dart';
import '../chat/chat_list_screen.dart';

class AppDrawer extends StatefulWidget {
  final VoidCallback? onProfileUpdate;

  const AppDrawer({super.key, this.onProfileUpdate});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String? _profilePictureUrl;
  String? _userName;
  bool _isLoadingProfile = true;
  int _unreadCount = 0;

  User? get currentUser => Supabase.instance.client.auth.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadUnreadCount();
  }

  Future<void> _loadProfile() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) {
        setState(() => _isLoadingProfile = false);
        return;
      }

      final profileData = await Supabase.instance.client
          .from('profiles')
          .select('profile_picture_url')
          .eq('id', userId)
          .maybeSingle();

      final userData = await Supabase.instance.client
          .from('users')
          .select('name')
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _profilePictureUrl = profileData?['profile_picture_url'];
          _userName = userData?['name'] ?? currentUser?.userMetadata?['name'];
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final userId = currentUser?.id;
      if (userId == null) return;

      final unreadData =
          await Supabase.instance.client.rpc(
                'get_unread_count',
                params: {'p_user_id': userId},
              )
              as List;

      int total = 0;
      for (var item in unreadData) {
        total += (item['unread_count'] as int);
      }

      if (mounted) {
        setState(() => _unreadCount = total);
      }
    } catch (e) {
      debugPrint('Error loading unread count: $e');
    }
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthWrapperScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSignOutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _signOut();
              },
              child: Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.red[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              _userName ?? currentUser?.userMetadata?['name'] ?? 'User',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            accountEmail: Text(
              currentUser?.email ?? '',
              style: const TextStyle(fontSize: 14),
            ),
            currentAccountPicture: _isLoadingProfile
                ? const CircleAvatar(
                    backgroundColor: Colors.white,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : CircleAvatar(
                    backgroundColor: Colors.white,
                    backgroundImage: _profilePictureUrl != null
                        ? NetworkImage(_profilePictureUrl!)
                        : null,
                    child: _profilePictureUrl == null
                        ? Text(
                            (_userName ??
                                    currentUser?.userMetadata?['name'] ??
                                    'U')[0]
                                .toUpperCase(),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          )
                        : null,
                  ),
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
          ),
          _buildDrawerItem(
            icon: Icons.home_outlined,
            title: 'Home',
            onTap: () => Navigator.pop(context),
          ),
          _buildDrawerItem(
            icon: Icons.person_outline,
            title: 'Profile',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              ).then((_) {
                _loadProfile();
                widget.onProfileUpdate?.call();
              });
            },
          ),
          _buildDrawerItem(
            icon: Icons.search,
            title: 'Search Skills',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.chat_bubble_outline,
            title: 'Messages',
            trailing: _unreadCount > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatListScreen()),
              ).then((_) => _loadUnreadCount());
            },
          ),
          const Divider(),
          _buildDrawerItem(
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings coming soon!')),
              );
            },
          ),
          _buildDrawerItem(
            icon: Icons.logout,
            title: 'Sign Out',
            onTap: () {
              Navigator.pop(context);
              _showSignOutConfirmation();
            },
            iconColor: Colors.red[600],
            textColor: Colors.red[600],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
    Widget? trailing,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.grey[700]),
      title: Text(
        title,
        style: TextStyle(
          color: textColor ?? Colors.grey[800],
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
