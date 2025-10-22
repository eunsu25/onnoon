import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // --- 1. 수정: 임포트 추가 ---
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // --- 2. 수정: storage 변수 추가 ---
  final storage = const FlutterSecureStorage();
  // ---------------------------------

  bool _notif = true;         // 알림
  bool _marketing = false;    // 마케팅 알림
  bool _darkMode = false;     // 다크모드
  double _textScale = 1.0;    // 글자 크기 배율
  String _language = '한국어';    // 언어

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    // initState에서 setState 호출 시 mounted 확인 (안전 조치)
    if (mounted) {
      setState(() {
        _notif     = p.getBool('notif') ?? true;
        _marketing = p.getBool('marketing') ?? false;
        _darkMode  = p.getBool('darkMode') ?? false;
        _textScale = p.getDouble('textScale') ?? 1.0;
        _language  = p.getString('language') ?? '한국어';
      });
    }
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('notif', _notif);
    await p.setBool('marketing', _marketing);
    await p.setBool('darkMode', _darkMode);
    await p.setDouble('textScale', _textScale);
    await p.setString('language', _language);
  }

  // --- 3. 수정: 로그아웃 함수 추가 ---
  void _logout() async {
    await storage.delete(key: 'jwt_token'); // 토큰 삭제

    if (!mounted) return;
    // 로그아웃 후 로그인 화면으로 이동 (현재 화면을 스택에서 제거하고 이동)
    // 앱의 모든 이전 경로를 제거하고 로그인 화면만 남김
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }
  // ----------------------------------

  void _toast(String msg) {
    if (!mounted) return; // async gap 이후 context 사용 전 확인
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('설정'),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF111111),
      ),
      body: ListView(
        children: [
          const _SectionHeader('일반'),
          SwitchListTile(
            title: const Text('알림 허용'),
            subtitle: const Text('앱 알림 수신'),
            value: _notif,
            onChanged: (v) async {
              setState(() => _notif = v);
              await _save();
            },
          ),
          SwitchListTile(
            title: const Text('마케팅 알림'),
            subtitle: const Text('이벤트·프로모션 소식 받기'),
            value: _marketing,
            onChanged: (v) async {
              setState(() => _marketing = v);
              await _save();
            },
          ),
          const Divider(),

          const _SectionHeader('디스플레이'),
          SwitchListTile(
            title: const Text('다크 모드'),
            subtitle: const Text('앱을 어두운 테마로'),
            value: _darkMode,
            onChanged: (v) async {
              setState(() => _darkMode = v);
              await _save();
              _toast('다크 모드를 적용하려면 앱 테마와 연결 필요');
            },
          ),
          ListTile(
            title: const Text('글자 크기'),
            subtitle: Text('배율: ${_textScale.toStringAsFixed(2)}x'),
          ),
          Slider(
            value: _textScale,
            min: 0.9,
            max: 1.3,
            divisions: 8,
            label: '${(_textScale * 100).round()}%',
            onChanged: (v) => setState(() => _textScale = v),
            onChangeEnd: (v) async {
              await _save();
              _toast('글자 크기 변경 저장됨');
            },
          ),
          const Divider(),

          const _SectionHeader('언어'),
          ListTile(
            title: const Text('앱 언어'),
            subtitle: Text(_language),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final selected = await showModalBottomSheet<String>(
                context: context,
                builder: (_) => _LangSheet(current: _language),
              );
              if (selected != null && selected != _language) {
                setState(() => _language = selected);
                await _save();
                _toast('언어가 "${_language}"로 설정됨');
              }
            },
          ),
          const Divider(),

          const _SectionHeader('개인정보 및 계정'),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('개인정보 처리방침'),
            onTap: () => _toast('정책 화면/URL로 연결하세요'),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('이용약관'),
            onTap: () => _toast('약관 화면/URL로 연결하세요'),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('데이터 내보내기'),
            onTap: () => _toast('CSV/JSON로 내보내기 구현 연결'),
          ),

          // --- 4. 수정: 로그아웃 버튼 추가 ---
          ListTile(
            leading: const Icon(Icons.logout), // 로그아웃 아이콘
            title: const Text('로그아웃'),
            onTap: _logout, // 탭하면 _logout 함수 실행
          ),
          // ----------------------------------

          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
            title: const Text('계정 삭제'),
            textColor: Colors.red,
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('정말 삭제할까요?'),
                  content: const Text('이 작업은 되돌릴 수 없습니다.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('삭제'),
                    ),
                  ],
                ),
              );
              if (ok == true) _toast('서버 연결 후 실제 삭제 API 호출');
            },
          ),

          const SizedBox(height: 12),
          const Center(child: Text('OnNoon v1.0.0', style: TextStyle(color: Colors.grey))),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// _SectionHeader, _LangSheet 클래스는 변경 없음
class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text, {super.key}); // Key 추가

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(text, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w700)),
    );
  }
}

class _LangSheet extends StatelessWidget {
  final String current;
  const _LangSheet({required this.current, super.key}); // Key 추가

  @override
  Widget build(BuildContext context) {
    final langs = ['한국어', 'English', '日本語'];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: langs.map((l) {
          final selected = l == current;
          return ListTile(
            title: Text(l),
            trailing: selected ? const Icon(Icons.check, color: Color(0xFF5A6BFF)) : null,
            onTap: () => Navigator.pop(context, l),
          );
        }).toList(),
      ),
    );
  }
}