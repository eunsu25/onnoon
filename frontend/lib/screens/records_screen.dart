import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; // 날짜 포맷팅을 위해 추가

enum Period { daily, weekly, monthly }

// API 응답 모델 클래스 정의
class FatigueRecord {
  final String id; // 각 기록을 식별할 ID (API 응답에 따라 타입 변경 가능, 예: int)
  final DateTime date;
  final int score;
  final String status;
  // TODO: API 응답에 따라 필요한 다른 필드 추가 (예: condition 문자열)

  FatigueRecord({
    required this.id, 
    required this.date, 
    required this.score,
    required this.status
  });

  factory FatigueRecord.fromJson(Map<String, dynamic> json) {
    return FatigueRecord(
      id: json['id']?.toString() ?? 'unknown_id', // ID를 String으로 변환
      date: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(), // 파싱 실패 시 현재 시간
      score: (json['fatigue_score'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '분석 중',
    );
  }
}

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  Period _period = Period.daily;

  // 상태 변수 추가
  final storage = const FlutterSecureStorage();
  bool _isLoading = true;
  String? _errorMessage;
  List<FatigueRecord> _historyList = []; // API 결과를 담을 리스트

  @override
  void initState() {
    super.initState();
    _fetchHistory(); // 화면 시작 시 데이터 요청
  }

  // API 호출 함수 구현
  Future<void> _fetchHistory() async {
    // 이미 로딩 중이면 중복 호출 방지
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
        _errorMessage = null; // 이전 오류 메시지 초기화
      });
    }

    String? token = await storage.read(key: 'jwt_token');

    if (token == null) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      });
      return;
    }

    // TODO: API 경로 확인 필요
    // TODO: _period 값에 따라 다른 API를 호출하거나 파라미터를 넘겨야 할 수 있음
    final url = Uri.parse('https://onnoon.onrender.com/api/eye-fatigue/history');

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
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        // TODO: API 응답 구조가 리스트가 아니라면 파싱 로직 수정 필요 (예: data['results'])
        setState(() {
          _historyList = data.map((item) => FatigueRecord.fromJson(item)).toList();
          // 데이터를 날짜 내림차순으로 정렬 (최신순)
          _historyList.sort((a, b) => b.date.compareTo(a.date));
          _isLoading = false;
        });
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        await storage.delete(key: 'jwt_token');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        });
      } else {
        setState(() {
          _errorMessage = '기록을 불러오는데 실패했습니다. (서버 오류 ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = '서버에 연결할 수 없습니다.';
          _isLoading = false;
        });
      }
    }
  }

  // --- 그래프/요약 데이터 계산 로직 (API 데이터 기반으로 수정) ---

  // 선택된 기간(_period)에 맞는 _historyList 필터링 함수 (예시)
  List<FatigueRecord> get _filteredHistory {
    // TODO: 실제 날짜 기준으로 필터링 로직 구현 필요
    return _historyList; // 지금은 전체 리스트 반환
  }

  // 필터링된 기록으로 FlSpot 리스트 생성
  List<FlSpot> get _series {
    final filtered = _filteredHistory;
    if (filtered.isEmpty) return [];
    // TODO: x축 값을 날짜/시간 기준으로 적절히 매핑해야 함 (예: 0~6 인덱스)
    // 지금은 그냥 index 사용
    return List.generate(
        filtered.length,
        (index) => FlSpot(index.toDouble(), filtered[index].score.toDouble()),
      ).reversed.toList(); // reversed() 추가하여 오래된 데이터부터 표시
  }

 // 필터링된 기록으로 x축 라벨 생성
 List<String> get _xLabels {
   final filtered = _filteredHistory;
   if (filtered.isEmpty) return [];
   // TODO: 선택된 _period에 따라 다른 라벨 형식 반환 (예: 'MM/DD', 'W주차', 'M월')
   // 지금은 날짜의 '일'만 표시 (예시)
   final formatter = DateFormat('d'); // '일'만 표시
   return filtered.map((record) => formatter.format(record.date)).toList().reversed.toList();
 }


 // 필터링된 기록 중 최소값 찾기
 ({int index, double value}) get _minPoint {
   final filtered = _filteredHistory;
   if (filtered.isEmpty) return (index: 0, value: 0);
   int idx = 0;
   double v = filtered.first.score.toDouble();
   for (var i = 1; i < filtered.length; i++) {
     if (filtered[i].score < v) {
       v = filtered[i].score.toDouble();
       idx = i;
     }
   }
   // _series가 reverse되었으므로 인덱스 보정
   return (index: filtered.length - 1 - idx, value: v);
 }


 // 필터링된 기록 중 최대값 찾기
 ({int index, double value}) get _maxPoint {
   final filtered = _filteredHistory;
   if (filtered.isEmpty) return (index: 0, value: 0);
   int idx = 0;
   double v = filtered.first.score.toDouble();
   for (var i = 1; i < filtered.length; i++) {
     if (filtered[i].score > v) {
       v = filtered[i].score.toDouble();
       idx = i;
     }
   }
    // _series가 reverse되었으므로 인덱스 보정
   return (index: filtered.length - 1 - idx, value: v);
 }

 // 필터링된 기록의 평균값 계산
 double get _averageScore {
    final filtered = _filteredHistory;
    if (filtered.isEmpty) return 0;
    return filtered.map((e) => e.score).reduce((a, b) => a + b) / filtered.length;
 }


 // --- build 메서드 ---
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    // 그래프 및 요약에 사용할 데이터 (API 호출 후 계산됨)
    final currentSeries = _series;
    final currentLabels = _xLabels;
    final avgScore = _averageScore;
    final maxPt = _maxPoint;
    final minPt = _minPoint;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('기록 및 통계'),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF111111),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Padding( // 오류 메시지에 패딩 추가
                  padding: const EdgeInsets.all(20.0),
                  child: Text(_errorMessage!, textAlign: TextAlign.center),
                ))
              : ListView( // 데이터 로드 성공 시 ListView 표시
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    _PeriodSelector(
                      period: _period,
                      // TODO: onChanged 시 _fetchHistory(period) 호출하여 해당 기간 데이터 다시 로드
                      onChanged: (p) {
                         setState(() => _period = p);
                         // _fetchHistory(); // 기간 변경 시 데이터 다시 로드 (API 수정 후)
                      }
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('평균 피로도',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 12),
                        Text(
                          avgScore.toStringAsFixed(0), // 계산된 평균 사용
                          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(width: 6),
                        const Text('점', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 그래프 데이터 전달
                    _ChartCard(width: w, series: currentSeries, labels: currentLabels),
                    const SizedBox(height: 16),
                    // 요약 데이터 전달
                    _SummaryRow(
                      bestLabel: '가장 편안했던 날',
                      bestValue: maxPt.value.toInt(),
                      bestWhen: currentLabels.isNotEmpty && maxPt.index < currentLabels.length ? currentLabels[maxPt.index] : '-', // index 범위 체크
                      worstLabel: '가장 피로했던 날',
                      worstValue: minPt.value.toInt(),
                      worstWhen: currentLabels.isNotEmpty && minPt.index < currentLabels.length ? currentLabels[minPt.index] : '-', // index 범위 체크
                    ),
                    const SizedBox(height: 24),
                    const Divider(thickness: 10, color: Color(0xFFF3F3F3)),
                    const SizedBox(height: 16),
                    const Text('이전 진단 기록 요약',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),

                    // ListView.builder로 실제 데이터 표시
                    if (_historyList.isEmpty)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text('진단 기록이 없습니다.'),
                      ))
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _historyList.length,
                        itemBuilder: (context, index) {
                          final record = _historyList[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: _RecordItem(
                              record: record,
                              onTapRecord: () {
                                Navigator.pushNamed(
                                  context,
                                  '/analysis',
                                  arguments: record.id, // ID 전달
                                );
                              },
                            ),
                          );
                        },
                      ),
                  ],
                ),
    );
  }
}

// --- 하위 위젯 정의 (수정 완료) ---

class _PeriodSelector extends StatelessWidget {
  final Period period;
  final ValueChanged<Period> onChanged;

  const _PeriodSelector({
    required this.period,
    required this.onChanged,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    const items = {
      Period.daily: '일간',
      Period.weekly: '주간',
      Period.monthly: '월간',
    };
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FF),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(6),
      child: Row(
        children: items.entries.map((e) {
          final selected = period == e.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(e.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF5A6BFF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF111111),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final double width;
  final List<FlSpot> series;
  final List<String> labels;
  const _ChartCard({required this.width, required this.series, required this.labels, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 260,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FF),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: series.isEmpty // 시리즈가 비어있으면 차트 대신 메시지 표시
        ? const Center(child: Text('표시할 데이터가 없습니다.'))
        : LineChart(
            LineChartData(
              minY: 0,
              maxY: 100,
              gridData: FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1, // 모든 라벨 표시
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i >= 0 && i < labels.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            labels[i],
                            style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: series,
                  isCurved: true,
                  barWidth: 3,
                  color: const Color(0xFF5A6BFF),
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (s, p, b, i) => FlDotCirclePainter(
                      radius: 4,
                      color: const Color(0xFF5A6BFF),
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF5A6BFF).withOpacity(0.18),
                        const Color(0xFF5A6BFF).withOpacity(0.02),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String bestLabel;
  final int bestValue;
  final String bestWhen;
  final String worstLabel;
  final int worstValue;
  final String worstWhen;
  const _SummaryRow({
    required this.bestLabel,
    required this.bestValue,
    required this.bestWhen,
    required this.worstLabel,
    required this.worstValue,
    required this.worstWhen,
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            title: bestLabel, value: bestValue, sub: bestWhen,
            icon: Icons.trending_up_rounded, color: const Color(0xFF12B886),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            title: worstLabel, value: worstValue, sub: worstWhen,
            icon: Icons.trending_down_rounded, color: const Color(0xFFFA5252),
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String title; final int value; final String sub;
  final IconData icon; final Color color;
  const _SummaryTile({required this.title, required this.value, required this.sub, required this.icon, required this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white, borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withOpacity(0.15),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(color: Colors.grey[700])),
                ],
              ),
            ),
            Text('$value점', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _RecordItem extends StatelessWidget {
  final FatigueRecord record;
  final VoidCallback onTapRecord;
  const _RecordItem({required this.record, required this.onTapRecord, super.key});

  String _statusOf(int v) {
    if (v >= 80) return '매우 좋음';
    if (v >= 60) return '양호';
    if (v >= 40) return '주의';
    return '위험';
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusOf(record.score);
    final dateText = DateFormat('yyyy년 M월 d일').format(record.date);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x3F656565), blurRadius: 5, offset: Offset(2, 1), spreadRadius: 1)],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFEFF1FF),
              child: Icon(Icons.health_and_safety_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateText,
                      style: const TextStyle(color: Color(0xFFBDB6B6), fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Text('눈 건강 테스트', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text('($status, ${record.score}점)',
                          style: const TextStyle(color: Color(0xFF515151), fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: onTapRecord,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4548FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  foregroundColor: Colors.white,
                ),
                child: const Text('진단 기록',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}