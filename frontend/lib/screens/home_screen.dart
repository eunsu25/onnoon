import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
// import 'package:intl/intl.dart'; // Add if date formatting is needed later

/// 홈 화면
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// --- 여기가 State 클래스 시작 ---
class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final storage = const FlutterSecureStorage();
  bool _isLoggedIn = false;

  // API 결과 및 상태 변수
  bool _isLoadingLatestResult = true;
  String? _latestResultErrorMessage;
  double? _latestScore;
  String? _latestGrade;
  DateTime? _latestCreatedAt;
  String? _userName; // 사용자 이름
  String? _userEmail; // 사용자 이메일
  // TODO: 그래프용 데이터 리스트 변수도 추가 필요

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); // 로그인 상태 확인 후 API 호출 시작
  }

  void _checkLoginStatus() async {
    String? token = await storage.read(key: 'jwt_token');
    bool loggedIn = (token != null);

    // initState에서 setState 호출 시 mounted 확인 불필요 (항상 true)
    // 하지만 비동기 작업 후에는 필요
    if (!mounted) return;

    setState(() {
      _isLoggedIn = loggedIn;
    });

    if (loggedIn) {
      if (_userName == null) _fetchUserInfo(); // 사용자 정보 가져오기
      if (_isLoadingLatestResult || _latestScore == null) _fetchLatestResult();
    } else {
      // 로그인 안되어 있으면 로딩 상태 해제
      if (mounted) {
         setState(() {
          _isLoadingLatestResult = false;
         });
      }
    }
  }

  // 최신 결과 API 호출 함수
  Future<void> _fetchLatestResult() async {
    // 함수 시작 시 로딩 상태 재설정 (이미 로딩 중이면 건너뛰지 않음)
     if (mounted && !_isLoadingLatestResult) {
       setState(() {
         _isLoadingLatestResult = true;
         _latestResultErrorMessage = null;
       });
    } else if (!mounted) { return; }
     else if (mounted && _latestResultErrorMessage != null) {
       setState(() { _latestResultErrorMessage = null; });
     }


    String? token = await storage.read(key: 'jwt_token');

    if (token == null) {
      if (mounted) {
        setState(() { _isLoadingLatestResult = false; });
      }
      return;
    }

    final url = Uri.parse('https://onnoon.onrender.com/api/eye-fatigue/result');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _latestScore = (data['fatigue_score'] as num?)?.toDouble();
            _latestGrade = data['fatigue_grade'] as String?;
            _latestCreatedAt = DateTime.tryParse(data['created_at'] ?? '');
            _isLoadingLatestResult = false;
            _latestResultErrorMessage = null;
          });
        }
      } else if (response.statusCode == 404) {
         if (mounted) {
           setState(() {
            _isLoadingLatestResult = false;
            _latestResultErrorMessage = '최근 진단 기록이 없습니다.';
            _latestScore = null;
            _latestGrade = null;
           });
         }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await storage.delete(key: 'jwt_token');
        if (mounted) setState(() => _isLoggedIn = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if(mounted) Navigator.pushReplacementNamed(context, '/login');
         });
      } else {
         if (mounted) {
           setState(() {
            _isLoadingLatestResult = false;
            _latestResultErrorMessage = '데이터를 불러오는데 실패했습니다. (서버 오류 ${response.statusCode})';
           });
         }
      }
    } catch (e) {
       if (mounted) {
        setState(() {
          _isLoadingLatestResult = false;
          _latestResultErrorMessage = '서버에 연결할 수 없습니다.';
        });
      }
       print('Error fetching latest result: $e');
    }
  }

  // 내 정보 조회 API 호출 함수
  Future<void> _fetchUserInfo() async {
    String? token = await storage.read(key: 'jwt_token');
    if (token == null) return;

    final url = Uri.parse('https://onnoon.onrender.com/api/users/me');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _userName = data['name'] as String?;
            _userEmail = data['email'] as String?;
          });
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await storage.delete(key: 'jwt_token');
        if (mounted) setState(() => _isLoggedIn = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if(mounted) Navigator.pushReplacementNamed(context, '/login');
         });
      } else {
        print('내 정보 조회 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('내 정보 조회 중 네트워크 오류: $e');
    }
  }

  void _openMenu() => _scaffoldKey.currentState?.openEndDrawer();

  Future<void> _go(String route) async {
    if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
      Navigator.pop(context);
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (!mounted) return;

    // Avoid pushing the same route if already on it
    if (ModalRoute.of(context)?.settings.name == route) return;

    Navigator.pushNamed(context, route);
  }


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      appBar: AppBar(
         backgroundColor: Colors.white,
         surfaceTintColor: Colors.white,
         elevation: 0,
         titleSpacing: 0,
         title: Row(
           children: [
             const SizedBox(width: 16),
             Container(
               width: 32, height: 32,
               decoration: const BoxDecoration(color: Color(0xFF2F43FF), shape: BoxShape.circle,),
               alignment: Alignment.center,
               child: const Text('O', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),),
             ),
             const SizedBox(width: 8),
             const Text('onnoon', style: TextStyle(color: Color(0xFF2F43FF), fontSize: 20, fontWeight: FontWeight.bold,),),
           ],
         ),
         actions: [
           IconButton(icon: Icon(Icons.notifications_outlined, color: Colors.grey[600]), onPressed: () { /* 알림 */ },),
           IconButton(icon: Icon(Icons.menu, color: Colors.grey[600]), onPressed: _openMenu,),
         ],
      ),
      endDrawer: _AppMenuDrawer(
        isLoggedIn: _isLoggedIn,
        onGoLogin: () => _go('/login'),
        userName: _userName,
        userEmail: _userEmail,
        onGoHome:   () => _go('/'),
        onGoGuide:  () => _go('/guide'),
        onGoStats:  () => _go('/records'),
        onGoAnalysis: () => _go('/analysis'),
        onGoDiagnosis: () => _go('/diagnosis'),
        onGoSettings: () => _go('/settings')
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: size.height * 0.02),
              // 로딩/오류/데이터 상태에 따라 UI 표시
              _isLoadingLatestResult
                  ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 50.0), child: CircularProgressIndicator()))
                  : _latestResultErrorMessage != null
                      ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_latestResultErrorMessage!, textAlign: TextAlign.center,)))
                      : _latestScore != null
                          ? _buildMainFatigueSection(w, _latestScore!, _latestGrade ?? '')
                          : const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 50.0), child: Text('최근 진단 기록이 없습니다.'))),

              SizedBox(height: size.height * 0.04),
              _buildDiagnosisButton(w),
              SizedBox(height: size.height * 0.04),
              const _SectionDivider(),
              SizedBox(height: size.height * 0.03),
              _buildFatigueAlert(),
              SizedBox(height: size.height * 0.03),
              _buildFatigueChart(size), // TODO: 그래프 API 연동
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // --- 위젯 빌더 함수들 ---

  Widget _buildMainFatigueSection(double screenW, double score, String grade) {
    final ring = screenW * 0.55;
    final gradeText = grade.split(' ').first;
    final gradeEmoji = grade.contains(' ') && grade.split(' ').length > 1 ? grade.split(' ')[1] : '🤔';

    String statusMsg;
    if (score >= 80) statusMsg = '눈 상태가 매우 좋아요!';
    else if (score >= 50) statusMsg = '눈 상태가 양호해요!';
    else statusMsg = '눈이 많이 피곤해요.';

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: ring, height: ring,
              child: CircularProgressIndicator(
                value: score.clamp(0.0, 100.0) / 100,
                strokeWidth: 12, backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2F43FF)),
              ),
            ),
            CircleAvatar(
              radius: ring * 0.28, backgroundColor: Colors.orange[300], // TODO: 등급별 색상
              child: Text(gradeEmoji, style: TextStyle(fontSize: ring * 0.28)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('${score.toStringAsFixed(0)}점', style: const TextStyle(color: Colors.black, fontSize: 36, fontWeight: FontWeight.w600),),
        const SizedBox(height: 8),
        Text(gradeText.isNotEmpty ? '$gradeText $statusMsg' : statusMsg, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),),
      ],
    );
  }

  Widget _buildDiagnosisButton(double screenW) {
     return Center(
       child: SizedBox(
         width: screenW * 0.7, height: 56,
         child: ElevatedButton(
           onPressed: () => _go('/diagnosis'),
           style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2F43FF), shape: const StadiumBorder(), elevation: 0,),
           child: const Text('다시 진단하기', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),),
         ),
       ),
     );
   }

  Widget _buildFatigueAlert() {
    return Row(
       children: [
         Expanded(
           child: Text(
             '${_userName ?? '사용자'} 님의 피로도 수치가\n감소하고 있습니다.', // TODO: 실제 추세 반영
             style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
           ),
         ),
         InkWell(
           onTap: () => _go('/records'), // ✅ 경로 수정됨
           child: Container(
             width: 32, height: 32,
             decoration: BoxDecoration(color: const Color(0xFF2F43FF), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1),),
             child: const Icon(Icons.add, color: Colors.white, size: 20),
           ),
         ),
       ],
     );
   }

  Widget _buildFatigueChart(Size size) {
    // TODO: API 데이터(_recentSpots) 받아와서 사용
    final w = size.width * 0.9;
    final h = size.height * 0.28;
    const List<FlSpot> spots = [ FlSpot(0, 45), FlSpot(1, 60), FlSpot(2, 55), FlSpot(3, 70), FlSpot(4, 65), FlSpot(5, 80), FlSpot(6, 87), ];
    const List<String> labels = ['월', '화', '수', '목', '금', '토', '일'];

    return Container(
      width: w, height: h.clamp(200.0, 320.0),
      decoration: BoxDecoration(color: const Color(0xFFF6F7FA), borderRadius: BorderRadius.circular(12),),
      padding: const EdgeInsets.all(20),
      child: spots.isEmpty
        ? const Center(child: Text('표시할 데이터가 없습니다.'))
        : LineChart(
          LineChartData(
            minY: 0, maxY: 100,
            gridData: FlGridData(show: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true, reservedSize: 24, interval: 1,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= 0 && index < labels.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(labels[index], style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true, color: const Color(0xFF2F43FF), barWidth: 3,
                dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: const Color(0xFF2F43FF), strokeWidth: 2, strokeColor: Colors.white,),),
                belowBarData: BarAreaData(show: true, color: const Color(0xFF2F43FF).withOpacity(0.12),),
              ),
            ],
          ),
        ),
    );
   }
// --- 여기가 State 클래스 끝 ---
}

// --- 여기서부터 헬퍼 클래스 시작 (State 클래스 밖에 있어야 함!) ---

/// 회색 굵은 구분선
class _SectionDivider extends StatelessWidget {
  const _SectionDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: 10, color: const Color(0xFFF3F3F3));
  }
}

/// 앱 공용 메뉴 드로어
class _AppMenuDrawer extends StatelessWidget {
  final bool isLoggedIn;
  final VoidCallback onGoLogin;

  final String? userName;
  final String? userEmail;

  final VoidCallback onGoHome;
  final VoidCallback onGoGuide;
  final VoidCallback onGoStats;
  final VoidCallback onGoAnalysis;
  final VoidCallback onGoDiagnosis;
  final VoidCallback onGoSettings;

  const _AppMenuDrawer({
    required this.isLoggedIn,
    required this.onGoLogin,
    this.userName,
    this.userEmail,
    required this.onGoHome,
    required this.onGoGuide,
    required this.onGoStats,
    required this.onGoAnalysis,
    required this.onGoDiagnosis,
    required this.onGoSettings,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
        elevation: 0,
        backgroundColor: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            isLoggedIn
                ? _buildProfileSection(name: userName, email: userEmail)
                : _buildLoginSection(),
            const Divider(),
            ListTile( leading: const Icon(Icons.home_outlined), title: const Text('홈'), onTap: onGoHome, ),
            ListTile( leading: const Icon(Icons.stacked_line_chart), title: const Text('기록 및 통계'), onTap: onGoStats, ),
            ListTile( leading: const Icon(Icons.analytics_outlined), title: const Text('분석 결과'), onTap: onGoStats, ),
            ListTile( leading: const Icon(Icons.self_improvement_outlined), title: const Text('맞춤형 회복 가이드'), onTap: onGoGuide, ),
            ListTile( leading: const Icon(Icons.health_and_safety_outlined), title: const Text('진단하기'), onTap: onGoDiagnosis, ),
            ListTile( leading: const Icon(Icons.settings_outlined), title: const Text('설정'), onTap: onGoSettings, ),
            // 로그아웃 버튼 없음
          ],
        ),
      ),
    );
  }

  // 로그인되지 않았을 때
  Widget _buildLoginSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Column(
        children: [
           const CircleAvatar( radius: 35, backgroundColor: Color(0xFFF3F3F3), child: Icon(Icons.person, size: 40, color: Colors.grey), ),
           const SizedBox(height: 16),
           const Text( '로그인이 필요한 서비스입니다.\n로그인/회원가입 후 이용해주세요.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey), ),
           const SizedBox(height: 16),
           ElevatedButton(
             onPressed: onGoLogin,
             style: ElevatedButton.styleFrom( backgroundColor: const Color(0xFF2F43FF), shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8), ), minimumSize: const Size(180, 44), ),
             child: const Text( '로그인 / 회원가입', style: TextStyle( color: Colors.white, fontWeight: FontWeight.bold, ), ),
           )
        ],
      ),
    );
  }

  // 로그인되었을 때
  Widget _buildProfileSection({String? name, String? email}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF2F43FF),
            child: Text(
              name != null && name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          const SizedBox(width: 16),
          Expanded( // Expanded 추가
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text( name ?? '사용자', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis, ),
                Text( email ?? '이메일 정보 없음', style: TextStyle(color: Colors.grey[600]), overflow: TextOverflow.ellipsis, ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} // --- 여기가 _AppMenuDrawer 클래스 끝 ---