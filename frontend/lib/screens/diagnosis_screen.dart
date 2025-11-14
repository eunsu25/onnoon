import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; // 카메라 패키지 사용
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// API 명세의 EyeData 스키마(blink_speed, iris_dilation 등)를 반영
class DiagnosisData {
  final double blinkSpeed;
  final double irisDilation;
  // 백엔드가 요구하는 필드에 맞게 추가/수정 필요

  DiagnosisData({required this.blinkSpeed, required this.irisDilation});

  Map<String, dynamic> toJson() => {
    'blink_speed': blinkSpeed,
    'iris_dilation': irisDilation,
    // 'eye_movement_pattern': eyeMovementPattern,
  };
}

class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({super.key});

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  // 카메라 관련 상태 변수
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isCameraReady = false;
  
  final storage = const FlutterSecureStorage();
  bool _isAnalyzing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera(); // 카메라 초기화 시작
  }

  // --- 1. 카메라 초기화 로직 ---
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _errorMessage = "카메라를 찾을 수 없습니다.");
        return;
      }
      
      // 전면 카메라를 기본으로 사용 (셀카 모드)
      final frontCamera = _cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras.first, // 전면 카메라 없으면 첫 번째 카메라 사용
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.medium, // 해상도 설정
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "카메라 초기화 중 오류 발생: $e";
        });
      }
      print("Camera initialization failed: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose(); // 위젯이 파괴될 때 카메라 컨트롤러 해제
    super.dispose();
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('진단 오류'),
        content: Text(message),
        actions: <Widget>[
          TextButton(child: const Text('확인'), onPressed: () => Navigator.of(ctx).pop()),
        ],
      ),
    );
  }

  // --- 2. 진단 시작 및 데이터 전송 함수 ---
  Future<void> _startDiagnosisAndSend(DiagnosisData results) async {
    if (!mounted) return;
    setState(() { _isAnalyzing = true; }); // 로딩 시작

    String? token = await storage.read(key: 'jwt_token');

    if (token == null) {
       if (mounted) Navigator.pushReplacementNamed(context, '/login');
       return;
    }

    final url = Uri.parse('https://onnoon.onrender.com/api/fatigue/'); // API 명세: POST /api/eye-fatigue/

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(results.toJson()), // 측정 데이터를 JSON으로 변환하여 전송
      );

      if (!mounted) return;
      setState(() { _isAnalyzing = false; }); // 로딩 종료

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 성공: 응답에서 생성된 record ID를 추출하여 분석 결과 화면으로 이동
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final String? newRecordId = data['id']?.toString(); // 새 기록 ID 추출 (API 응답 확인 필요)

        if (newRecordId != null) {
          // 화면 교체 (새로 생성된 ID를 넘겨줌)
          Navigator.pushReplacementNamed(context, '/analysis', arguments: newRecordId);
        } else {
           _showErrorDialog('진단 성공, 하지만 기록 ID를 받지 못했습니다.');
        }
      } else {
        // 실패 (서버 오류)
        final errorData = jsonDecode(utf8.decode(response.bodyBytes));
        _showErrorDialog(errorData['detail'] ?? '진단 데이터 전송 실패. (서버 오류)');
      }

    } catch (e) {
      if (mounted) setState(() { _isAnalyzing = false; });
      _showErrorDialog('서버에 연결할 수 없습니다. 네트워크 문제일 수 있습니다.');
      print('Network/Server Error during diagnosis POST: $e');
    }
  }


  // --- 3. UI 구성 (카메라, 버튼) ---
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    Widget bodyContent;

    if (_errorMessage != null) {
      bodyContent = Center(child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
      ));
    } else if (!_isCameraReady || _controller == null || !_controller!.value.isInitialized) {
      bodyContent = const Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("카메라 초기화 중...", style: TextStyle(color: Colors.grey)),
        ],
      ));
    } else {
      // 카메라 준비 완료 및 일반 진단 UI
      bodyContent = Stack(
        alignment: Alignment.center,
        children: [
          // 카메라 미리보기 영역
          SizedBox(
            width: size.width,
            height: size.height,
            child: CameraPreview(_controller!),
          ),

          // 진단 안내 및 버튼
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text("눈을 화면 중앙에 맞춰주세요.", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(
                _isAnalyzing ? "분석 중입니다..." : "준비 완료!", 
                style: TextStyle(color: _isAnalyzing ? Colors.yellow : Colors.white),
              ),
              
              SizedBox(height: size.height * 0.1),

              // 진단 시작 버튼
              Container(
                margin: const EdgeInsets.only(bottom: 40),
                width: size.width * 0.7,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAnalyzing ? Colors.grey : const Color(0xFF2F43FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isAnalyzing ? null : () {
                    // TODO: AI/Vision API로 실제 측정을 시작하고, 결과가 나오면
                    // 아래 dummyData 대신 실제 측정 데이터를 넘겨야 합니다.
                    final dummyData = DiagnosisData(blinkSpeed: 1.5, irisDilation: 5.5);
                    _startDiagnosisAndSend(dummyData); // 더미 데이터로 전송 시작
                  },
                  child: Text(
                    _isAnalyzing ? '분석 중...' : '진단 시작', 
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      );

      // 카메라 미리보기 화면이 회전할 경우를 대비한 Transform 위젯 추가 (선택 사항)
      // bodyContent = Transform.scale(
      //   scale: 1 / (_controller!.value.aspectRatio * size.aspectRatio),
      //   child: Center(
      //     child: AspectRatio(
      //       aspectRatio: _controller!.value.aspectRatio,
      //       child: bodyContent,
      //     ),
      //   ),
      // );
    }

    return Scaffold(
      backgroundColor: Colors.black, // 카메라 배경이 검정이므로
      appBar: AppBar(
        title: const Text('눈 피로도 진단', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: bodyContent,
    );
  }
}