import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 텍스트 필드의 값을 가져오기 위한 컨트롤러
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // 로그인 버튼을 눌렀을 때 실행될 함수
  void _login() {
    final email = _emailController.text;
    final password = _passwordController.text;

    // TODO: 여기에 백엔드 API 연동 로직을 추가합니다.
    // 1. email, password를 서버로 보냅니다.
    // 2. 응답으로 토큰(token)을 받습니다.
    // 3. 성공하면 홈 화면('/home')으로 이동합니다.
    // 4. 실패하면 에러 메시지를 팝업으로 보여줍니다.
    print('Email: $email, Password: $password');

    // 임시로 홈 화면으로 이동
    if (email.isNotEmpty && password.isNotEmpty) {
      Navigator.pushReplacementNamed(context, '/'); // 성공 시 홈으로
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('로그인', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
              const Text(
                'onnoon에 오신 것을\n환영합니다!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),

              // 이메일 입력 필드
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: '이메일',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // 비밀번호 입력 필드
              TextField(
                controller: _passwordController,
                obscureText: true, // 비밀번호 가리기
                decoration: const InputDecoration(
                  labelText: '비밀번호',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 32),

              // 로그인 버튼
              ElevatedButton(
                onPressed: _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F43FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '로그인',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              
              // 회원가입 화면으로 이동하는 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('계정이 없으신가요?'),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                    child: const Text(
                      '회원가입',
                      style: TextStyle(
                        color: Color(0xFF2F43FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}