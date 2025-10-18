import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/guide_screen.dart';
import 'screens/records_screen.dart';
import 'screens/analysis_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';

void main() => runApp(const OnNoonApp());

class OnNoonApp extends StatelessWidget {
  const OnNoonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OnNoon',
      theme: ThemeData(useMaterial3: true, fontFamily: 'Inter'),
      initialRoute: '/login', 
      routes: {
        '/': (_) => const HomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/guide': (_) => const GuideScreen(),
        '/records': (_) => const RecordsScreen(),
        '/analysis': (_) => const AnalysisScreen(), // or AnalysisDetailScreen(args)
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
