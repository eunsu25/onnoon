import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/guide_screen.dart';
import 'screens/records_screen.dart';
import 'screens/analysis_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/diagnosis_screen.dart'; // 진단 화면 import 추가 필요

void main() => runApp(const OnNoonApp());

class OnNoonApp extends StatelessWidget {
  const OnNoonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OnNoon',
      theme: ThemeData(useMaterial3: true, fontFamily: 'Inter'),
      initialRoute: '/login', // 앱 시작 시 첫 화면
      routes: {
        // --- routes에는 arguments가 필요 없는 화면들만 남깁니다 ---
        '/': (_) => const HomeScreen(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignupScreen(),
        '/guide': (_) => const GuideScreen(),
        '/records': (_) => const RecordsScreen(),
        // '/analysis': (_) => const AnalysisScreen(), // <-- 이 줄은 삭제
        '/settings': (_) => const SettingsScreen(),
        '/diagnosis': (_) => const DiagnosisScreen(), // 진단 화면 경로 추가 필요
      },
      // --- ✅ onGenerateRoute 추가 ---
      onGenerateRoute: (settings) {
        // '/analysis' 경로 요청이 오면
        if (settings.name == '/analysis') {
          // arguments로 전달된 데이터(recordId)를 추출합니다.
          final String? recordId = settings.arguments as String?; // 타입 캐스팅 (null일 수 있음)

          // AnalysisScreen 위젯을 생성하고 recordId를 전달합니다.
          return MaterialPageRoute(
            builder: (context) {
              // AnalysisScreen 생성자가 recordId를 받도록 수정해야 합니다.
              // 예: const AnalysisScreen({super.key, this.recordId});
              return AnalysisScreen(recordId: recordId); // recordId 전달
            },
          );
        }
        // 다른 경로들은 여기서 처리하지 않음 (routes에서 처리됨)
        // assert(false, 'Need to implement ${settings.name}'); // Optional: 정의되지 않은 경로 에러 처리
        return null;
      },
      // --- onGenerateRoute 끝 ---
    );
  }
}

// --- ⚠️ AnalysisScreen 수정 필요 ---
// analysis_screen.dart 파일을 열어서 생성자를 수정해야 합니다.
/*
// 예시: analysis_screen.dart 수정
class AnalysisScreen extends StatefulWidget {
  final String? recordId; // recordId를 받을 변수 추가

  const AnalysisScreen({super.key, this.recordId}); // 생성자 수정

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  @override
  void initState() {
    super.initState();
    // initState에서 recordId 사용 가능
    print('넘어온 ID: ${widget.recordId}');
    _fetchSpecificAnalysisData(widget.recordId); // ID를 사용하여 데이터 요청
  }
  // ... 나머지 코드 ...
}
*/