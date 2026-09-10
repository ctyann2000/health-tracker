import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../services/gemini_service.dart';
import '../providers/health_provider.dart';
import '../models/health_record.dart';
import '../models/prescription_record.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isLoading = false;
  final List<Map<String, dynamic>> _messages = [
    {"text": "こんにちは！今日の体調や、服用したお薬、運動の記録などを教えてください。処方箋やQRコード、体重計の画面や測定アプリのスクショを添付することもできます。", "isUser": false}
  ];

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('画像の取得に失敗しました: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
                title: const Text('写真ライブラリ・アルバムから選択'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.teal),
                title: const Text('カメラで直接撮影'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendMessage() async {
    final messageText = _controller.text;
    final imageBytesToProcess = _selectedImageBytes;
    final imageToProcess = _selectedImage;
    
    if (messageText.trim().isEmpty && imageBytesToProcess == null) return;
    
    setState(() {
      _messages.add({
        "text": messageText.isNotEmpty ? messageText : "（画像送信）",
        "isUser": true,
        "hasImage": imageBytesToProcess != null,
        "imageBytes": imageBytesToProcess,
      });
      _isLoading = true;
      _selectedImage = null;
      _selectedImageBytes = null; // 送信後に選択をクリア
    });
    _controller.clear();

    try {
      Map<String, dynamic> result;
      if (imageBytesToProcess != null) {
        result = await _geminiService.extractHealthDataFromImage(
          imageBytesToProcess, 
          imageToProcess?.mimeType ?? 'image/jpeg', 
          extraInput: messageText
        );
      } else {
        result = await _geminiService.extractHealthData(messageText);
      }
      if (mounted) {
        if (result.containsKey('error')) {
          final detail = result['message'] != null ? "\n${result['message']}" : "";
          setState(() {
            _messages.add({"text": "エラーが発生しました: ${result['error']}$detail", "isUser": false});
          });
        } else {
          // AIが抽出した日付（YYYY-MM-DD）があれば採用、なければ現在日時
          DateTime targetDate = DateTime.now();
          if (result['date'] != null && (result['date'] as String).trim().isNotEmpty) {
            try {
              final parsed = DateTime.parse((result['date'] as String).trim());
              targetDate = DateTime(parsed.year, parsed.month, parsed.day, targetDate.hour, targetDate.minute);
            } catch (e) {
              debugPrint('Failed to parse date from AI: ${result['date']}');
            }
          }

          final record = HealthRecord(
            date: targetDate,
            conditionScore: result['condition_score'],
            symptoms: List<String>.from(result['symptoms'] ?? []),
            medications: (result['medications'] as List?)
                    ?.map((e) => e is String ? Medication(name: e) : Medication.fromJson(e as Map<String, dynamic>))
                    .toList() ??
                [],
            weight: result['weight'] != null ? (result['weight'] as num).toDouble() : null,
            steps: result['steps'] as int?,
            workouts: (result['workouts'] as List?)
                    ?.map((e) => Workout.fromJson(e))
                    .toList() ??
                [],
            bodyFat: result['bodyFat'] != null ? (result['bodyFat'] as num).toDouble() : null,
            bmi: result['bmi'] != null ? (result['bmi'] as num).toDouble() : null,
            bmr: result['bmr'] as int?,
            calories: result['calories'] as int?,
            sleepHours: result['sleepHours'] != null ? (result['sleepHours'] as num).toDouble() : null,
          );
          
          final removeSymptoms = List<String>.from(result['remove_symptoms'] ?? []);
          final bool clearAllSymptoms = result['clear_all_symptoms'] == true;
          final bool hasRemoval = removeSymptoms.isNotEmpty || clearAllSymptoms;

          final bool hasNewData = record.conditionScore != null ||
              record.symptoms.isNotEmpty ||
              record.medications.isNotEmpty ||
              record.workouts.isNotEmpty ||
              record.weight != null ||
              record.steps != null ||
              record.bodyFat != null ||
              record.bmi != null ||
              record.bmr != null ||
              record.calories != null ||
              record.sleepHours != null ||
              (result['prescription'] != null && result['prescription'] is Map);

          if (!hasNewData && !hasRemoval) {
            setState(() {
              _messages.add({"text": "AI: 画像やテキストから、健康の記録を見つけることができませんでした。", "isUser": false});
            });
          } else {
            final healthProvider = Provider.of<HealthProvider>(context, listen: false);

            // 1. 新規・追加データの反映
            if (hasNewData) {
              healthProvider.addRecord(record);
            }

            // 2. 症状の取り消し・否定の反映
            if (clearAllSymptoms) {
              healthProvider.clearSymptoms(targetDate);
            } else if (removeSymptoms.isNotEmpty) {
              healthProvider.removeSymptoms(targetDate, removeSymptoms);
            }
            
            // 3. 処方箋・お薬手帳データがあれば処方レコードとして登録
            if (result['prescription'] != null && result['prescription'] is Map) {
              try {
                final presMap = Map<String, dynamic>.from(result['prescription']);
                presMap['date'] = targetDate.toIso8601String();
                final presRecord = PrescriptionRecord.fromJson(presMap);
                if (presRecord.medications.isNotEmpty) {
                  healthProvider.addPrescription(presRecord);
                }
              } catch (e) {
                debugPrint('Prescription parse error: $e');
              }
            }

            final coachReply = (result['reply'] as String?)?.trim() ?? "";
            
            final List<String> summaryLines = [];
            final now = DateTime.now();
            final isToday = targetDate.year == now.year && targetDate.month == now.month && targetDate.day == now.day;
            if (!isToday) {
              final dateStr = DateFormat('yyyy年M月d日(E)', 'ja_JP').format(targetDate);
              summaryLines.add("対象日: $dateStr");
            }

            // 取り消された症状の明示
            if (clearAllSymptoms) {
              summaryLines.add("症状: すべて取り消し・解除");
            } else if (removeSymptoms.isNotEmpty) {
              summaryLines.add("取り消した症状: ${removeSymptoms.join(', ')}");
            }

            if (record.conditionScore != null && !hasRemoval) {
              summaryLines.add("体調スコア: ${record.conditionScore}/10");
            }
            if (record.symptoms.isNotEmpty) {
              summaryLines.add("症状: ${record.symptoms.join(', ')}");
            }
            if (result['prescription'] != null && result['prescription'] is Map) {
              final hName = result['prescription']['hospital_name'] ?? '医療機関';
              summaryLines.add("お薬手帳: $hNameの処方を登録");
            }
            if (record.medications.isNotEmpty) {
              final meds = record.medications.map((m) => m.time != null ? "${m.time} ${m.name}" : m.name).join(', ');
              summaryLines.add("お薬: $meds");
            }
            if (record.workouts.isNotEmpty) {
              final wText = record.workouts.map((w) {
                if (w.weight > 0 && w.reps > 0 && w.sets > 0) return "${w.name} (${w.weight}kg ${w.reps}回×${w.sets}set)";
                if (w.reps > 0 && w.sets > 0) return "${w.name} (${w.reps}回×${w.sets}set)";
                return w.name;
              }).join(', ');
              summaryLines.add("運動: $wText");
            }
            if (record.weight != null) summaryLines.add("体重: ${record.weight}kg");
            if (record.bodyFat != null) summaryLines.add("体脂肪率: ${record.bodyFat}%");
            if (record.sleepHours != null) summaryLines.add("睡眠: ${record.sleepHours}時間");
            if (record.steps != null && record.steps! > 0) summaryLines.add("歩数: ${record.steps}歩");
            if (record.calories != null) summaryLines.add("消費カロリー: ${record.calories}kcal");

            final summaryBlock = summaryLines.join('\n');
            final titleHeader = hasRemoval && record.medications.isEmpty && record.workouts.isEmpty && record.weight == null
                ? "【更新内容】"
                : "【記録内容】";
            final fullMessage = coachReply.isNotEmpty
                ? (summaryBlock.isNotEmpty ? "$coachReply\n\n$titleHeader\n$summaryBlock" : coachReply)
                : "記録を保存しました！\n$summaryBlock";

            setState(() {
              _messages.add({"text": fullMessage, "isUser": false});
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add({"text": "エラーが発生しました。", "isUser": false});
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'HealthApp',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Theme.of(context).colorScheme.primary,
            letterSpacing: 1.0,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.favorite_rounded, color: Colors.redAccent.shade200),
            tooltip: 'HealthApp Personal',
            onPressed: () {},
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFDFBFB), // Very clean white
              Color(0xFFEBEDEE), // Light silvery white
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Top Row: Date Scroller and Chart
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: _buildDateScroller(context).animate().fade(duration: 400.ms).slideY(begin: 0.1),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: _buildTrendChart(context).animate().fade(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Middle Row: Status Windows
                _buildStatusWindows(context).animate().fade(duration: 400.ms, delay: 150.ms).slideY(begin: 0.1),
                const SizedBox(height: 12),
                // Bottom: Integrated Chat
                Expanded(
                  child: _buildIntegratedChat(context).animate().fade(duration: 400.ms, delay: 200.ms).slideY(begin: 0.05),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassContainer(BuildContext context, {required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.85), // Whiter glass
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildDateScroller(BuildContext context) {
    final healthProvider = Provider.of<HealthProvider>(context);
    final now = DateTime.now();
    
    // Generate last 7 days
    final List<DateTime> dateList = List.generate(7, (index) => now.subtract(Duration(days: 6 - index)));
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    return _buildGlassContainer(
      context,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('直近一週間', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
          const SizedBox(height: 12),
          SizedBox(
            height: 85, // Increased height to prevent overflow
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              itemBuilder: (context, index) {
                final date = dateList[index];
                bool isSelected = index == 6; // Today is selected
                
                // Check if there's data for this day
                final record = healthProvider.getRecordForDate(date);
                final hasSymptom = record != null && record.symptoms.isNotEmpty;
                final hasMeds = record != null && record.medications.isNotEmpty;
                
                Color? dotColor;
                if (hasSymptom && hasMeds) dotColor = Colors.purple;
                else if (hasSymptom) dotColor = Colors.redAccent;
                else if (hasMeds) dotColor = Colors.cyan;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: _buildDateItem(context, days[date.weekday - 1], date.day.toString(), isSelected, dotColor),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateItem(BuildContext context, String day, String date, bool isSelected, Color? dotColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: isSelected
          ? BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.cyan, width: 2),
              boxShadow: [BoxShadow(color: Colors.cyan.withOpacity(0.2), blurRadius: 8)],
            )
          : null,
      child: Column(
        children: [
          Text(day, style: TextStyle(fontSize: 11, color: isSelected ? Colors.black : Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(date, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? Colors.black : Colors.black87)),
          const SizedBox(height: 4),
          if (dotColor != null) CircleAvatar(radius: 3, backgroundColor: dotColor)
          else const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildTrendChart(BuildContext context) {
    final healthProvider = Provider.of<HealthProvider>(context);
    final records = healthProvider.getRecentRecords(7);
    
    // Create mapping of past 7 days to scores
    final now = DateTime.now();
    final List<DateTime> dateList = List.generate(7, (index) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - index)));
    
    // Generate spots for line chart and bars
    List<FlSpot> spots = [];
    List<BarChartGroupData> bars = [];
    
    for (int i = 0; i < 7; i++) {
      final date = dateList[i];
      final record = records.where((r) => r.date.year == date.year && r.date.month == date.month && r.date.day == date.day).firstOrNull;
      
      // 体調スコア（記録がなければ0＝棒グラフなし）
      final score = record?.conditionScore?.toDouble() ?? 0.0; 
      // 薬の数（記録がなければ0＝折れ線グラフは一番下）
      final medCount = (record?.medications.length ?? 0).toDouble(); 
      
      spots.add(FlSpot(i.toDouble(), medCount));
      bars.add(_makeBarData(i, score, context));
    }

    return _buildGlassContainer(
      context,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('体調(棒)・薬(折れ線)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87)),
          const SizedBox(height: 12),
          SizedBox(
            height: 65,
            child: Stack(
              children: [
                // Bar Chart for Health Condition
                BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceBetween,
                    maxY: 10,
                    minY: 0,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: const FlTitlesData(show: false),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: bars,
                  ),
                ),
                // Line Chart for Medication/Health Score
                LineChart(
                  LineChartData(
                    minX: -0.2,
                    maxX: 6.2,
                    minY: 0,
                    maxY: 10,
                    lineTouchData: LineTouchData(enabled: false),
                    titlesData: const FlTitlesData(show: false),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: Colors.cyan,
                        barWidth: 2,
                        isStrokeCapRound: true,
                        dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 2, color: Colors.cyan, strokeWidth: 1, strokeColor: Colors.white)),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarData(int x, double y, BuildContext context) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: Colors.purpleAccent.withOpacity(0.5),
          width: 8,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 10,
            color: Colors.grey.withOpacity(0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusWindows(BuildContext context) {
    final healthProvider = Provider.of<HealthProvider>(context);
    final todayRecord = healthProvider.getRecordForDate(DateTime.now());

    return Row(
      children: [
        Expanded(child: _buildStatusCard(context, '服薬状況', _getMedicationSummary(todayRecord), Icons.medical_services, Colors.purple)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatusCard(context, '体重', todayRecord?.weight != null ? '${todayRecord!.weight} kg' : '-', Icons.monitor_weight, Colors.blue)),
        const SizedBox(width: 8),
        Expanded(child: _buildStatusCard(context, '運動状況', _getWorkoutSummary(todayRecord), Icons.directions_run, Colors.orange)),
      ],
    );
  }

  String _getMedicationSummary(HealthRecord? record) {
    if (record == null || record.medications.isEmpty) return '-';
    return record.medications.take(8).map((m) => m.time != null ? '${m.time} ${m.name}' : m.name).join('\n');
  }

  String _getWorkoutSummary(HealthRecord? record) {
    if (record == null) return '-';
    List<String> parts = [];
    if (record.steps != null) parts.add('${record.steps} 歩');
    if (record.workouts.isNotEmpty) {
      final names = record.workouts.take(8).map((w) {
        String detail = '';
        if (w.weight > 0 && w.reps > 0 && w.sets > 0) {
          detail = ' ${w.weight}kg (${w.reps}回×${w.sets})';
        } else if (w.reps > 0 && w.sets > 0) {
          detail = ' (${w.reps}回×${w.sets})';
        } else if (w.sets > 0) {
          detail = ' ×${w.sets}';
        }
        return '• ${w.name}$detail';
      }).join('\n');
      parts.add(names);
    }
    if (parts.isEmpty) return '-';
    return parts.join('\n');
  }

  Widget _buildStatusCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return _buildGlassContainer(
      context,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black87), overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54), maxLines: 8, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildIntegratedChat(BuildContext context) {
    return _buildGlassContainer(
      context,
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          // Chat Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black12, width: 1)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.cyan.shade100,
                  child: const FaIcon(FontAwesomeIcons.robot, color: Colors.cyan, size: 18),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Health Coach', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
                    Text('Online', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          // Messages list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg["isUser"] as bool;
                final hasImage = msg["hasImage"] == true;
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                    decoration: BoxDecoration(
                      color: isUser ? Theme.of(context).colorScheme.primary : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isUser ? const Radius.circular(16) : const Radius.circular(4),
                        bottomRight: isUser ? const Radius.circular(4) : const Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (msg["imageBytes"] != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              msg["imageBytes"] as Uint8List,
                              width: 180,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 6),
                        ] else if (hasImage) ...[
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.image, size: 14, color: Colors.white70),
                              SizedBox(width: 4),
                              Text("画像を添付しました", style: TextStyle(fontSize: 11, color: Colors.white70)),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          msg["text"] as String,
                          style: TextStyle(color: isUser ? Colors.white : Colors.black87, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack, alignment: isUser ? Alignment.centerRight : Alignment.centerLeft),
                );
              },
            ),
          ),
          // 選択中の画像プレビューバー（添付時に表示）
          if (_selectedImageBytes != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _selectedImageBytes!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
                            const SizedBox(width: 4),
                            const Text(
                              '画像添付完了（送信準備OK）',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                          ],
                        ),
                        Text(
                          _selectedImage?.name ?? 'image.jpg',
                          style: const TextStyle(fontSize: 11, color: Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, size: 20, color: Colors.black45),
                    onPressed: () {
                      setState(() {
                        _selectedImage = null;
                        _selectedImageBytes = null;
                      });
                    },
                    tooltip: '添付をキャンセル',
                  ),
                ],
              ),
            ).animate().fade(duration: 200.ms).slideY(begin: 0.1),
          // Input field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.black12, width: 1)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.camera_alt, 
                    color: _selectedImageBytes != null ? Theme.of(context).colorScheme.primary : Colors.black45
                  ),
                  onPressed: _showImageSourceActionSheet,
                  tooltip: "画像・写真・QRコードを添付",
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: '体調や運動を記録...',
                      hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.7),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.purple.shade300, Colors.purple.shade400]),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white, size: 18),
                          onPressed: _sendMessage,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
