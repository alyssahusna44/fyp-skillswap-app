// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'auth/auth_wrapper.dart';
import 'home_screen.dart';
import 'widgets/splash_screen.dart';
import 'auth/update_password_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // load env
  await dotenv.load();
  // initialize supabase
  String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  String supabaseKey = dotenv.env['SUPABASE_KEY'] ?? '';
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define the custom colors
    const Color mainColor = Color(0xFF114A99);
    const Color accentColor = Color(0xFFFEBD59);

    return MaterialApp(
      title: 'SkillSwap',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: mainColor,
        colorScheme: ColorScheme.fromSeed(
          seedColor: mainColor,
          secondary: accentColor,
          brightness: Brightness.light,
        ),

        // Update Input decoration
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[50],
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: mainColor, width: 2),
          ),
          // ... (keep other borders consistent)
        ),

        // Update Button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: mainColor,
            foregroundColor: Colors.white,
            // Use accent color for shadows or highlights if desired
            shadowColor: mainColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Update App bar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: mainColor,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class AuthStateWrapper extends StatelessWidget {
  const AuthStateWrapper({super.key});

  @override
  Widget build(BuildContext context) {

    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
  if (data.event == AuthChangeEvent.passwordRecovery) {
    Navigator.push(
      // ignore: use_build_context_synchronously
      context,
      MaterialPageRoute(builder: (context) => const UpdatePasswordScreen()),
    );
  }
});
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Show loading while checking auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.hasData ? snapshot.data!.session : null;

        if (session != null) {
          // User is logged in, check if email is verified
          if (session.user.emailConfirmedAt != null) {
            return const HomeScreen();
          } else {
            // Email not verified, show auth screen with message
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Please verify your email to continue. Check your inbox.',
                  ),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 5),
                ),
              );
            });
            return const AuthWrapperScreen();
          }
        } else {
          // User is not logged in
          return const AuthWrapperScreen();
        }
      },
    );
  }
}
