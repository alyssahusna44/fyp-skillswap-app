import 'package:flutter/material.dart';
//import 'package:supabase_flutter/supabase_flutter.dart'; // ADDED: For Auth State Listening
import 'signin_screen.dart';
import 'signup_screen.dart';
//import '../home_screen.dart'; // ASSUMED: Path to your main app screen

class AuthWrapperScreen extends StatefulWidget {
  const AuthWrapperScreen({super.key});

  @override
  State<AuthWrapperScreen> createState() => _AuthWrapperScreenState();
}

class _AuthWrapperScreenState extends State<AuthWrapperScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    /*// CORE WRAPPER LOGIC: Listen for Supabase authentication state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;

      // If a valid session exists (user is signed in or successfully logged in)
      if (session != null) {
        // Use addPostFrameCallback to ensure navigation runs after the current build cycle
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Redirect to the HomeScreen and remove all authentication routes
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          }
        });
      }
      // If the session is null (e.g., after sign-out), the app remains on this screen.
    });*/
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    _tabController.animateTo(index);
  }

  // New method to switch pages/tabs
  void _switchToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // App Logo/Header
            Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // App Logo (you can replace with your app logo)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(Icons.school, size: 50, color: Colors.white),
                  ),
                  const SizedBox(height: 16),

                  // App Title
                  Text(
                    'SkillSwap',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Learn & Teach Skills Together',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Tab Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(25),
              ),
              child: TabBar(
                controller: _tabController,
                onTap: _onTabChanged,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: Theme.of(context).primaryColor,
                ),
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[600],
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Sign In'),
                  Tab(text: 'Sign Up'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Page View
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  // Pass the callback to LoginScreen to switch to Sign Up (index 1)
                  LoginScreen(onSwitchToSignup: () => _switchToPage(1)),
                  // Pass the callback to RegistrationScreen to switch to Sign In (index 0)
                  RegistrationScreen(onSwitchToLogin: () => _switchToPage(0)),
                ],
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Terms and Privacy
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text(
                        'By continuing, you agree to our ',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Navigate to Terms of Service
                          _showDialog(
                            context,
                            'Terms of Service',
                            'Terms of Service contents.',
                          );
                        },
                        child: Text(
                          'Terms of Service',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Text(
                        ' and ',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      GestureDetector(
                        onTap: () {
                          // Navigate to Privacy Policy
                          _showDialog(
                            context,
                            'Privacy Policy',
                            'Privacy Policy contents.',
                          );
                        },
                        child: Text(
                          'Privacy Policy',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // University branding
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Exclusively for UniKL Students',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
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

  void _showDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(content)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
