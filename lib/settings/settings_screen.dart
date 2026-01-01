// lib/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/legal_texts.dart';
import '../auth/auth_wrapper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _supabase = Supabase.instance.client;
  bool _notificationsEnabled = true;
  bool _darkMode = false;

  User? get currentUser => _supabase.auth.currentUser;

  // Helper method to launch URLs safely
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e')),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    await _supabase.auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const AuthWrapperScreen()),
      (route) => false,
    );
  }

  void _showLegalDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Account'),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Email'),
            subtitle: Text(currentUser?.email ?? 'Not signed in'),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            onTap: () {
              // Logic for sending password reset email via Supabase
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password reset link sent to your email')),
              );
              _supabase.auth.resetPasswordForEmail(currentUser!.email!);
            },
          ),
          
          const Divider(),
          _buildSectionHeader('Preferences'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_none),
            title: const Text('Push Notifications'),
            value: _notificationsEnabled,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
            activeColor: Theme.of(context).primaryColor,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark Mode (Coming Soon)'),
            value: _darkMode,
            onChanged: (val) => setState(() => _darkMode = val),
            activeColor: Theme.of(context).primaryColor,
          ),

          const Divider(),
          _buildSectionHeader('Legal & Support'),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Service'),
            onTap: () => _showLegalDialog('Terms of Service', skillSwapTermsOfService),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () => _showLegalDialog('Privacy Policy', skillSwapPrivacyPolicy),
          ),
          const ListTile(
            leading: Icon(Icons.help_outline),
            title: Text('Contact Support'),
            subtitle: Text('Connect with the developers on LinkedIn'),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 56.0), // Indent to align with title
            child: Column(
              children: [
                ListTile(
                  dense: true,
                  title: const Text('Alyssa Husna', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                  onTap: () => _launchURL('https://www.linkedin.com/in/alyssahusna'),
                ),
                ListTile(
                  dense: true,
                  title: const Text('Alya Azwin Zamri', style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline)),
                  onTap: () => _launchURL('https://www.linkedin.com/in/alya-azwin-zamri/'),
                ),
              ],
            ),
          ),

          const Divider(),
          _buildSectionHeader('Danger Zone'),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Sign Out', style: TextStyle(color: Colors.red)),
            onTap: _handleSignOut,
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
            onTap: () {
              // Implementation would involve a database trigger or edge function
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contact admin to delete account')),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Version 1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}