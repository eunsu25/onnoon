import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// 분석 결과 데이터 모델
class AnalysisResult {
  final int score;               // 0~100
  final double blinkInterval;   // 초
  final int focusHoldSeconds;   // 초
  final Duration totalAnalysis; // 총 분석 시간
  final String status;

  const AnalysisResult({
    required this.score,
    required this.blinkInterval,
    required this.focusHoldSeconds,
    required this.totalAnalysis,
    required this.status,
  });

  // API 응답(JSON)을 AnalysisResult 모델로 변환하는 팩토리 생성자
  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final double scoreValue = (json['fatigue_score'] as num?)?.toDouble() ?? 0.0;
    //final double blinkValue = (json['blink_speed'] as num?)?.toDouble() ?? 0.0;
    final int focusValue = (json['iris_dilation'] as num?)?.toInt() ?? 0;

    final Duration totalDuration = Duration(seconds: focusValue);

    return AnalysisResult(
      score: scoreValue.toInt(),
      blinkInterval: (json['blink_speed'] as num?)?.toDouble() ?? 0.0,
      focusHoldSeconds: focusValue,
      totalAnalysis: Duration(seconds: focusValue),
      status: json['status'] as String? ?? '분석 중',
    );
  }
}

// StatefulWidget으로 변경
class AnalysisScreen extends StatefulWidget {
  final String? recordId;
  const AnalysisScreen({super.key, this.recordId});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final storage = const FlutterSecureStorage();
  AnalysisResult? _result; // API에서 받아올 결과 데이터
  bool _isLoading = true; // 로딩 상태
  String? _errorMessage; // 오류 메시지

  @override
  void initState() {
    super.initState();
    print('넘어온 ID: ${widget.recordId}');
    _fetchSpecificAnalysisData(widget.recordId);
  }

  // Part 4의 API 호출 로직
  Future<void> _fetchSpecificAnalysisData(String? recordId) async {
    if (recordId == null) {
      if (mounted) {
        setState(() {
          _errorMessage = '잘못된 접근입니다. (기록 ID 누락)';
          _isLoading = false;
        });
      }
      return;
    }

    // 1. 토큰 읽어오기
    String? token = await storage.read(key: 'jwt_token');

    if (token == null) {
      // 토큰이 없으면 로그인 화면으로 이동
      if (!mounted) return;
      // 현재 context가 유효한지 확인 후 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
           Navigator.pushReplacementNamed(context, '/login');
        }
      });
      return;
    }

    // 2. API 호출
    final url = Uri.parse('https://onnoon.onrender.com/api/eye-fatigue/$recordId');

    try{
      final response = await http.get(
        url,
        // 3. 헤더에 토큰 포함!
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        // 성공
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          // TODO: API 응답 JSON 구조에 맞게 fromJson을 수정해야 합니다.
          _result = AnalysisResult.fromJson(data);
          _isLoading = false;
        });
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        // 인증 실패 (토큰 만료 등) -> 로그인 화면으로
        await storage.delete(key: 'jwt_token');
         // 현재 context가 유효한지 확인 후 이동
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        });
      } else {
        // 기타 서버 오류
        setState(() {
          _errorMessage = '데이터를 불러오는데 실패했습니다. (서버 오류 ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      // 네트워크 오류 등
       if (mounted) {
        setState(() {
          _errorMessage = '서버에 연결할 수 없습니다.';
          _isLoading = false;
        });
      }
    }
  }

  (String, Color) _statusOf(int score) {
    if (score >= 80) return ('매우 좋음', const Color(0xFF12B886));
    if (score >= 60) return ('양호', const Color(0xFF5A6AFF));
    if (score >= 40) return ('주의', const Color(0xFFFF9500));
    return ('위험', const Color(0xFFFA5252));
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m > 0 && s == 0) return '$m 분';
    if (m > 0) return '$m 분 ${s}초';
    return '${s}초';
  }

  String _adviceText(int score) {
    if (score >= 80) return '지금 페이스를 유지하세요. 20-20-20 수칙으로 눈을 보호하세요.';
    if (score >= 60) return '양호한 상태예요. 가벼운 눈 스트레칭을 추천합니다.';
    if (score >= 40) return '주의 단계예요. 5분 휴식을 취하고 인공눈물을 사용해보세요.';
    return '피로도가 높아요. 화면 사용을 줄이고 충분한 휴식을 취하세요.';
  }

  @override
  Widget build(BuildContext context) {
    // 로딩 및 오류 상태 처리
    if (_isLoading) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(_errorMessage!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (_result == null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: Text('데이터가 없습니다.')),
      );
    }

    // 'result' 변수가 API에서 온 '_result'를 사용하도록 변경
    final result = _result!;
    final (statusText, statusColor) = _statusOf(result.score);
    final size = MediaQuery.of(context).size;
    final ringSize = size.width * 0.6;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(), // AppBar를 별도 함수로 분리
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 상단 요약 박스
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF5A6AFF),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
              child: Column(
                children: [
                  SizedBox(
                    width: ringSize,
                    height: ringSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: (result.score.clamp(0, 100)) / 100,
                          strokeWidth: 14,
                          backgroundColor: Colors.white.withOpacity(0.25),
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${result.score}점',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              '눈 분석 완료',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 상태 배지
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 18, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          '진단 결과 : $statusText',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _adviceText(result.score),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: 260,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, '/diagnosis'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF111111),
                        shape: const StadiumBorder(),
                        elevation: 0,
                      ),
                      child: const Text('다시 진단하기',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            _MetricCard(
              leadingColor: const Color(0xFF5A6AFF),
              title: '깜빡임 속도',
              // --- ✅ 1. 수정: 이름 있는 인자로 올바르게 전달 ---
              value: '${result.blinkInterval.toStringAsFixed(1)}초 간격',
              icon: Icons.remove_red_eye_outlined,
            ),
            const SizedBox(height: 12),
            _MetricCard(
              leadingColor: const Color(0xFFFF8989),
              title: '초점 유지 시간',
              value: '${result.focusHoldSeconds}초',
              icon: Icons.center_focus_strong,
            ),
            const SizedBox(height: 12),
            _MetricCard(
              leadingColor: const Color(0xFF1C2574),
              title: '총 분석 시간',
              value: _formatDuration(result.totalAnalysis),
              icon: Icons.timer_outlined,
            ),

            const SizedBox(height: 16),

            const _AdviceBanner(
              title: '눈이 조금 피로한 상태입니다. 잠시 쉬어주세요!',
              color: Color(0xFFFFFAE2),
              icon: Icons.tips_and_updates_outlined,
            ),
          ],
        ),
      ),
    );
  }

  // 로딩/오류 시에도 AppBar를 보여주기 위해 헬퍼 함수로 분리
  AppBar _buildAppBar() {
    return AppBar(
      title: const Text('눈 건강 분석 결과'),
      centerTitle: true,
      backgroundColor: const Color(0xFF5A6AFF),
      foregroundColor: Colors.white,
      elevation: 0,
    );
  }
}

class _MetricCard extends StatelessWidget {
  final Color leadingColor;
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({
    required this.leadingColor,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: const [
            BoxShadow(
              color: Color(0x3F656565),
              blurRadius: 5,
              offset: Offset(2, 1),
              spreadRadius: 1,
            ),
          ],
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: leadingColor,
            radius: 26,
            child: Icon(icon, color: Colors.white),
          ),
          title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          subtitle: Text(
            value,
            style: const TextStyle(fontSize: 15, color: Color(0xFF616161), fontWeight: FontWeight.w600),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }
}

class _AdviceBanner extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;

  const _AdviceBanner({required this.title, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3F000000),
            blurRadius: 5,
            offset: Offset(2, 1),
            spreadRadius: 1,
          )
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, size: 28, color: const Color(0xFF111111)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                  fontSize: 16, color: Color(0xFF111111), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}