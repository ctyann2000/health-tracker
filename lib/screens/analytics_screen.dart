import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/health_provider.dart';
import '../models/health_record.dart';
import '../utils/workout_analyzer.dart';
import '../widgets/edit_health_record_dialog.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('ダッシュボード', style: TextStyle(fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary, letterSpacing: 1.0)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFFFDFBFB), 
              Color(0xFFEBEDEE), 
            ],
          ),
        ),
        child: SafeArea(
          child: Consumer<HealthProvider>(
            builder: (context, provider, child) {
              if (provider.isLoading) return const Center(child: CircularProgressIndicator());
              
              // 直近7日間のデータを取得し、古い順（グラフの左から右）にソート
              final recentRecords = List<HealthRecord>.from(provider.getRecentRecords(7))
                ..sort((a, b) => a.date.compareTo(b.date));

              if (recentRecords.isEmpty) {
                return const Center(child: Text('直近のデータがありません', style: TextStyle(color: Colors.black54)));
              }

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(
                  top: kToolbarHeight + 16.0,
                  left: 16.0,
                  right: 16.0,
                  bottom: 8.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text('直近7日間のトレンド', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)).animate().fade().slideY(begin: 0.1),
                    const SizedBox(height: 16),
                    
                    // --- 睡眠グラフ ---
                    if (recentRecords.any((r) => r.sleepHours != null)) ...[
                      _buildChartCard(
                        context: context,
                        title: '睡眠時間',
                        icon: Icons.bedtime,
                        color: const Color(0xFF7986CB),
                        child: _buildSleepChart(recentRecords),
                      ).animate().fade(delay: 100.ms).slideY(begin: 0.05),
                      const SizedBox(height: 16),
                    ],

                    // --- トレーニング推移 ---
                    if (recentRecords.any((r) => r.workouts.isNotEmpty)) ...[
                      _buildChartCard(
                        context: context,
                        title: '総負荷量 (ボリューム)',
                        icon: Icons.fitness_center,
                        color: Colors.amber.shade700,
                        child: _buildVolumeChart(recentRecords),
                      ).animate().fade(delay: 150.ms).slideY(begin: 0.05),
                      const SizedBox(height: 16),
                      _buildChartCard(
                        context: context,
                        title: '鍛えた部位バランス',
                        icon: Icons.accessibility_new,
                        color: Colors.deepOrange,
                        child: _buildMuscleRadarChart(recentRecords),
                      ).animate().fade(delay: 175.ms).slideY(begin: 0.05),
                      const SizedBox(height: 16),
                    ],

                    // --- 歩数グラフ ---
                    if (recentRecords.any((r) => r.steps != null && r.steps! > 0)) ...[
                      _buildChartCard(
                        context: context,
                        title: '歩数・運動量',
                        icon: Icons.directions_walk,
                        color: const Color(0xFF4DB6AC),
                        child: _buildStepsChart(recentRecords),
                      ).animate().fade(delay: 200.ms).slideY(begin: 0.05),
                      const SizedBox(height: 16),
                    ],

                    // --- お薬手帳 ---
                    if (recentRecords.any((r) => r.medications.isNotEmpty)) ...[
                      _buildChartCard(
                        context: context,
                        title: 'お薬手帳 (服薬記録)',
                        icon: Icons.medication,
                        color: const Color(0xFFF06292),
                        child: _buildMedicationAdherence(recentRecords),
                      ).animate().fade(delay: 300.ms).slideY(begin: 0.05),
                      const SizedBox(height: 16),
                    ],

                    // --- 体重・体脂肪率グラフ ---
                    if (recentRecords.any((r) => r.weight != null || r.bodyFat != null)) ...[
                      WeightFatChartCard(records: recentRecords)
                          .animate()
                          .fade(delay: 400.ms)
                          .slideY(begin: 0.05),
                      const SizedBox(height: 16),
                    ],

                    const SizedBox(height: 24),
                    const Text('カレンダー', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)).animate().fade(delay: 500.ms).slideY(begin: 0.1),
                    const SizedBox(height: 16),
                    _buildGlassContainer(
                      context,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${DateTime.now().year}年 ${DateTime.now().month}月', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  const Text('日付をタップして記録の確認・修正・削除', style: TextStyle(fontSize: 11, color: Colors.black45)),
                                ],
                              ),
                              const Icon(Icons.calendar_month, color: Colors.black54),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildCalendarGrid(context, provider),
                        ],
                      ),
                    ).animate().fade(delay: 600.ms).slideY(begin: 0.05),
                    const SizedBox(height: 100),
                  ],
                ),
              );
            }
          ),
        ),
      ),
    );
  }

  // --- お薬手帳ウィジェット ---
  Widget _buildMedicationAdherence(List<HealthRecord> records) {
    // 過去7日間の全薬種を抽出
    final Set<String> uniqueMeds = {};
    for (var r in records) {
      for (var m in r.medications) {
        uniqueMeds.add(m.name.trim());
      }
    }

    final dateFormats = records.map((r) => DateFormat('M/d').format(r.date)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: uniqueMeds.map((medName) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(medName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: records.asMap().entries.map((entry) {
                  int idx = entry.key;
                  HealthRecord r = entry.value;
                  bool taken = r.medications.any((m) => m.name.trim() == medName);
                  
                  return Column(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: taken ? const Color(0xFFF06292) : Colors.grey.withOpacity(0.2),
                        ),
                        child: taken ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                      ),
                      const SizedBox(height: 4),
                      Text(dateFormats[idx], style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    ],
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // --- 睡眠時間グラフ ---
  Widget _buildSleepChart(List<HealthRecord> records) {
    List<FlSpot> spots = [];
    double maxSleep = 0;
    
    for (int i = 0; i < records.length; i++) {
      if (records[i].sleepHours != null) {
        double val = records[i].sleepHours!;
        spots.add(FlSpot(i.toDouble(), val));
        if (val > maxSleep) maxSleep = val;
      }
    }

    double chartMaxY = maxSleep > 10 ? (maxSleep + 2).ceilToDouble() : 12.0;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 3,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.black.withValues(alpha: 0.05),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => const Color(0xFF1E293B),
              getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                int idx = s.x.toInt();
                return LineTooltipItem(
                  '${DateFormat('M/d').format(records[idx].date)}\n睡眠: ${s.y.toStringAsFixed(1)} 時間',
                  const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                );
              }).toList(),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: 3,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      '${value.toInt()}h',
                      style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.right,
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  int idx = value.toInt();
                  if (idx >= 0 && idx < records.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(DateFormat('M/d').format(records[idx].date), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF7986CB),
              barWidth: 3.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: const Color(0xFF7986CB),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF7986CB).withValues(alpha: 0.15),
              ),
            ),
          ],
          maxY: chartMaxY,
          minY: 0,
        ),
      ),
    );
  }

  // --- トレーニングボリュームグラフ ---
  Widget _buildVolumeChart(List<HealthRecord> records) {
    double maxVolume = 0;

    // 先に全体の最大値を計算
    for (var r in records) {
      double volume = r.workouts.fold(0.0, (sum, w) => sum + (w.weight * w.reps * w.sets));
      if (volume > maxVolume) maxVolume = volume;
    }
    // チャートの最大値を確定させる
    double chartMaxY = maxVolume > 5000 ? maxVolume * 1.1 : 5000.0;

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < records.length; i++) {
      double volume = records[i].workouts.fold(0.0, (sum, w) => sum + (w.weight * w.reps * w.sets));
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: volume,
              color: Colors.amber.shade700,
              width: 16,
              borderRadius: BorderRadius.circular(8), // ピル状により丸く
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: chartMaxY,
                color: Colors.amber.withOpacity(0.1), // グラスモーフィズムに合う同系色
              ),
            )
          ],
        )
      );
    }

    double interval = chartMaxY / 4;
    if (interval < 500) interval = 1000;

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => const Color(0xFF1E293B),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                int idx = group.x;
                String dateStr = (idx >= 0 && idx < records.length) ? DateFormat('M/d').format(records[idx].date) : '';
                return BarTooltipItem(
                  '$dateStr\n負荷: ${rod.toY.toInt()} kg',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.black.withValues(alpha: 0.05),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == 0) return const SizedBox.shrink();
                  String text = value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}k' : '${value.toInt()}';
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      text,
                      style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.right,
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  int idx = value.toInt();
                  if (idx >= 0 && idx < records.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(DateFormat('M/d').format(records[idx].date), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
          maxY: chartMaxY,
        ),
      ),
    );
  }

  // --- 鍛えた部位バランス（レーダーチャート） ---
  Widget _buildMuscleRadarChart(List<HealthRecord> records) {
    // 部位ごとの合計セット数
    Map<String, double> muscleSets = {
      WorkoutAnalyzer.chest: 0,
      WorkoutAnalyzer.back: 0,
      WorkoutAnalyzer.legs: 0,
      WorkoutAnalyzer.shoulders: 0,
      WorkoutAnalyzer.arms: 0,
      WorkoutAnalyzer.core: 0,
    };

    for (var r in records) {
      for (var w in r.workouts) {
        final muscle = WorkoutAnalyzer.getMuscleGroup(w.name);
        if (muscleSets.containsKey(muscle)) {
          muscleSets[muscle] = muscleSets[muscle]! + w.sets.toDouble();
        }
      }
    }

    final titles = [WorkoutAnalyzer.chest, WorkoutAnalyzer.back, WorkoutAnalyzer.legs, WorkoutAnalyzer.shoulders, WorkoutAnalyzer.arms, WorkoutAnalyzer.core];
    final values = titles.map((t) => muscleSets[t]!).toList();

    // 全て0かどうかのチェック
    if (values.every((v) => v == 0)) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('部位ごとのデータがありません', style: TextStyle(color: Colors.black54))),
      );
    }

    return SizedBox(
      height: 200,
      child: RadarChart(
        RadarChartData(
          dataSets: [
            RadarDataSet(
              fillColor: Colors.deepOrange.withOpacity(0.2),
              borderColor: Colors.deepOrange,
              entryRadius: 3,
              dataEntries: values.map((v) => RadarEntry(value: v)).toList(),
              borderWidth: 2,
            )
          ],
          radarBackgroundColor: Colors.transparent,
          borderData: FlBorderData(show: false),
          radarBorderData: const BorderSide(color: Colors.black12),
          titlePositionPercentageOffset: 0.15,
          titleTextStyle: const TextStyle(fontSize: 10, color: Colors.black87, fontWeight: FontWeight.bold),
          getTitle: (index, angle) {
            return RadarChartTitle(text: titles[index]);
          },
          tickCount: 3,
          ticksTextStyle: const TextStyle(color: Colors.transparent),
          tickBorderData: const BorderSide(color: Colors.black12),
          gridBorderData: const BorderSide(color: Colors.black12, width: 1.5),
        ),
        swapAnimationDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  // --- 歩数グラフ ---
  Widget _buildStepsChart(List<HealthRecord> records) {
    double maxSteps = 0;
    
    for (var r in records) {
      double steps = (r.steps ?? 0).toDouble();
      if (steps > maxSteps) maxSteps = steps;
    }
    
    double chartMaxY = maxSteps > 10000 ? maxSteps : 10000.0;

    List<BarChartGroupData> barGroups = [];
    for (int i = 0; i < records.length; i++) {
      double steps = (records[i].steps ?? 0).toDouble();
      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: steps,
              color: const Color(0xFF4DB6AC),
              width: 16,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: chartMaxY,
                color: Colors.black.withValues(alpha: 0.04),
              ),
            )
          ],
        )
      );
    }

    double interval = chartMaxY / 4;
    if (interval < 2000) interval = 2500;

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (group) => const Color(0xFF1E293B),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                int idx = group.x;
                String dateStr = (idx >= 0 && idx < records.length) ? DateFormat('M/d').format(records[idx].date) : '';
                return BarTooltipItem(
                  '$dateStr\n歩数: ${rod.toY.toInt()} 歩',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.black.withValues(alpha: 0.05),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  if (value == meta.max || value == 0) return const SizedBox.shrink();
                  String text = value >= 1000 ? '${(value / 1000).toStringAsFixed(0)}k' : '${value.toInt()}';
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      text,
                      style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.right,
                    ),
                  );
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  int idx = value.toInt();
                  if (idx >= 0 && idx < records.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(DateFormat('M/d').format(records[idx].date), style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: barGroups,
        ),
      ),
    );
  }





  Widget _buildChartCard({required BuildContext context, required String title, required IconData icon, required Color color, required Widget child}) {
    return _buildGlassContainer(
      context,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildGlassContainer(BuildContext context, {required Widget child, EdgeInsetsGeometry? padding}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.6),
                Colors.white.withOpacity(0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
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

  Widget _buildCalendarGrid(BuildContext context, HealthProvider healthProvider) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final offset = firstDayOfMonth.weekday == 7 ? 0 : firstDayOfMonth.weekday;
    
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['日', '月', '火', '水', '木', '金', '土']
              .map((day) => Text(day, style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.bold)))
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1.0,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: daysInMonth + offset,
          itemBuilder: (context, index) {
            if (index < offset) return const SizedBox.shrink();
            
            final day = index - offset + 1;
            final date = DateTime(now.year, now.month, day);
            final record = healthProvider.getRecordForDate(date);
            
            bool hasBadHealth = record != null && (record.symptoms.isNotEmpty || record.medications.isNotEmpty || (record.conditionScore != null && record.conditionScore! < 5));
            bool hasWorkout = record != null && record.workouts.isNotEmpty;
            bool isToday = day == now.day && now.month == date.month && now.year == date.year;

            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                EditHealthRecordDialog.show(context, date, existingRecord: record);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isToday
                      ? Theme.of(context).colorScheme.primary
                      : (record != null
                          ? Colors.white.withOpacity(0.85)
                          : Colors.white.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (hasBadHealth || hasWorkout)
                        ? Theme.of(context).colorScheme.secondary
                        : (record != null ? Colors.grey.withOpacity(0.3) : Colors.transparent),
                    width: 1.5,
                  ),
                  boxShadow: isToday
                      ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                      : (record != null
                          ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))]
                          : []),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('$day', style: TextStyle(fontSize: 14, fontWeight: isToday || record != null ? FontWeight.bold : FontWeight.normal, color: isToday ? Colors.white : Colors.black87)),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasBadHealth) Icon(Icons.sick, size: 10, color: isToday ? Colors.white : Colors.redAccent),
                          if (hasWorkout) Icon(Icons.fitness_center, size: 10, color: isToday ? Colors.white : Colors.cyan),
                          if (record != null && !hasBadHealth && !hasWorkout)
                            Icon(Icons.check_circle, size: 9, color: isToday ? Colors.white70 : Colors.teal),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ============================================================================
// 体重・体脂肪率グラフ専用カード (洗練されたスケール・目盛り・タブ切り替え対応)
// ============================================================================
class WeightFatChartCard extends StatefulWidget {
  final List<HealthRecord> records;

  const WeightFatChartCard({super.key, required this.records});

  @override
  State<WeightFatChartCard> createState() => _WeightFatChartCardState();
}

class _WeightFatChartCardState extends State<WeightFatChartCard> {
  // 0: 体重, 1: 体脂肪率, 2: 両方
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    final hasWeight = widget.records.any((r) => r.weight != null);
    final hasFat = widget.records.any((r) => r.bodyFat != null);
    if (!hasWeight && hasFat) {
      _selectedTab = 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.records;

    // 最新値と前回値の取得
    HealthRecord? latestWRecord;
    HealthRecord? prevWRecord;
    HealthRecord? latestFRecord;
    HealthRecord? prevFRecord;

    for (int i = records.length - 1; i >= 0; i--) {
      if (records[i].weight != null) {
        if (latestWRecord == null) {
          latestWRecord = records[i];
        } else {
          prevWRecord ??= records[i];
        }
      }
      if (records[i].bodyFat != null) {
        if (latestFRecord == null) {
          latestFRecord = records[i];
        } else {
          prevFRecord ??= records[i];
        }
      }
    }

    final double? latestWeight = latestWRecord?.weight;
    final double? weightDiff = (latestWRecord != null && prevWRecord != null)
        ? (latestWRecord.weight! - prevWRecord.weight!)
        : null;

    final double? latestFat = latestFRecord?.bodyFat;
    final double? fatDiff = (latestFRecord != null && prevFRecord != null)
        ? (latestFRecord.bodyFat! - prevFRecord.bodyFat!)
        : null;

    final bool hasWeight = records.any((r) => r.weight != null);
    final bool hasFat = records.any((r) => r.bodyFat != null);

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.6),
                Colors.white.withValues(alpha: 0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ヘッダー部
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9575CD).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.monitor_weight, size: 20, color: Color(0xFF7C4DFF)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '体重・体脂肪率',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                  ),
                  const Spacer(),
                  // 最新値サマリーバッジ
                  if (latestWeight != null)
                    _buildValueBadge(
                      label: '体重',
                      value: '${latestWeight.toStringAsFixed(1)}kg',
                      diff: weightDiff,
                      color: const Color(0xFF7C4DFF),
                    ),
                  if (latestWeight != null && latestFat != null)
                    const SizedBox(width: 6),
                  if (latestFat != null)
                    _buildValueBadge(
                      label: '体脂肪',
                      value: '${latestFat.toStringAsFixed(1)}%',
                      diff: fatDiff,
                      color: Colors.orange.shade800,
                    ),
                ],
              ),
              const SizedBox(height: 14),

              // タブ切り替え（体重・体脂肪率・両方）
              if (hasWeight && hasFat) ...[
                Container(
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.all(2.5),
                  child: Row(
                    children: [
                      _buildTabButton(0, '体重 (kg)', const Color(0xFF7C4DFF)),
                      _buildTabButton(1, '体脂肪率 (%)', Colors.orange.shade800),
                      _buildTabButton(2, '両方 (2軸)', Colors.teal.shade700),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // グラフ本体
              SizedBox(
                height: 190,
                child: _buildChart(records, hasWeight, hasFat),
              ),

              // 両方モードのときの凡例
              if (_selectedTab == 2 && hasWeight && hasFat) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildLegendItem('体重 (kg) [左軸]', const Color(0xFF7C4DFF)),
                    const SizedBox(width: 16),
                    _buildLegendItem('体脂肪率 (%) [右軸]', Colors.orange.shade800),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTabButton(int index, String label, Color activeColor) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? activeColor : Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildValueBadge({
    required String label,
    required String value,
    required double? diff,
    required Color color,
  }) {
    String diffText = '';
    if (diff != null) {
      if (diff > 0) {
        diffText = '+${diff.toStringAsFixed(1)}';
      } else if (diff < 0) {
        diffText = diff.toStringAsFixed(1);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
          if (diffText.isNotEmpty) ...[
            const SizedBox(width: 2),
            Text(
              diffText,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: diff != null && diff > 0 ? Colors.red.shade400 : Colors.blue.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChart(List<HealthRecord> records, bool hasWeight, bool hasFat) {
    if (_selectedTab == 0 || (!hasFat && hasWeight)) {
      return _buildSingleLineChart(
        records: records,
        getValue: (r) => r.weight,
        unit: 'kg',
        color: const Color(0xFF7C4DFF),
        label: '体重',
      );
    } else if (_selectedTab == 1 || (!hasWeight && hasFat)) {
      return _buildSingleLineChart(
        records: records,
        getValue: (r) => r.bodyFat,
        unit: '%',
        color: Colors.orange.shade800,
        label: '体脂肪率',
      );
    } else {
      return _buildDualLineChart(records);
    }
  }

  Widget _buildSingleLineChart({
    required List<HealthRecord> records,
    required double? Function(HealthRecord) getValue,
    required String unit,
    required Color color,
    required String label,
  }) {
    List<FlSpot> spots = [];
    double minVal = double.infinity;
    double maxVal = -double.infinity;

    for (int i = 0; i < records.length; i++) {
      final val = getValue(records[i]);
      if (val != null) {
        spots.add(FlSpot(i.toDouble(), val));
        if (val < minVal) minVal = val;
        if (val > maxVal) maxVal = val;
      }
    }

    if (spots.isEmpty) {
      return const Center(child: Text('データがありません', style: TextStyle(color: Colors.black45, fontSize: 12)));
    }

    // スケール計算
    double range = maxVal - minVal;
    double pad = range < 1.0 ? 1.5 : range * 0.25;
    double minY = (minVal - pad).floorToDouble();
    double maxY = (maxVal + pad).ceilToDouble();
    if (maxY - minY < 3) maxY = minY + 3;
    if (minY < 0) minY = 0;

    double interval = ((maxY - minY) / 3).clamp(0.5, 10.0);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.black.withValues(alpha: 0.05),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => const Color(0xFF1E293B),
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              int idx = s.x.toInt();
              String dateStr = (idx >= 0 && idx < records.length)
                  ? DateFormat('M/d').format(records[idx].date)
                  : '';
              return LineTooltipItem(
                '$dateStr\n$label: ${s.y.toStringAsFixed(1)} $unit',
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              );
            }).toList(),
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                int idx = value.toInt();
                if (idx >= 0 && idx < records.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('M/d').format(records[idx].date),
                      style: const TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: -0.25,
        maxX: records.length <= 1 ? 0.25 : (records.length - 1).toDouble() + 0.25,
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: spots.length > 2,
            curveSmoothness: 0.3,
            color: color,
            barWidth: 3.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 4.5,
                color: Colors.white,
                strokeWidth: 2.5,
                strokeColor: color,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDualLineChart(List<HealthRecord> records) {
    List<FlSpot> weightSpots = [];
    List<FlSpot> fatSpots = [];
    double minW = double.infinity, maxW = -double.infinity;
    double minF = double.infinity, maxF = -double.infinity;

    for (int i = 0; i < records.length; i++) {
      if (records[i].weight != null) {
        final w = records[i].weight!;
        weightSpots.add(FlSpot(i.toDouble(), w));
        if (w < minW) minW = w;
        if (w > maxW) maxW = w;
      }
      if (records[i].bodyFat != null) {
        final f = records[i].bodyFat!;
        if (f < minF) minF = f;
        if (f > maxF) maxF = f;
      }
    }

    if (weightSpots.isEmpty && fatSpots.isEmpty) {
      return const Center(child: Text('データがありません', style: TextStyle(color: Colors.black45, fontSize: 12)));
    }

    // 体重スケール
    double rangeW = maxW - minW;
    double padW = rangeW < 1.0 ? 1.5 : rangeW * 0.25;
    double minY = (minW - padW).floorToDouble();
    double maxY = (maxW + padW).ceilToDouble();
    if (maxY - minY < 3) maxY = minY + 3;
    if (minY < 0) minY = 0;

    // 体脂肪率スケール
    double rangeF = maxF - minF;
    double padF = rangeF < 1.0 ? 1.5 : rangeF * 0.25;
    double minFatY = (minF - padF).floorToDouble();
    double maxFatY = (maxF + padF).ceilToDouble();
    if (maxFatY - minFatY < 3) maxFatY = minFatY + 3;
    if (minFatY < 0) minFatY = 0;

    // 体脂肪率を体重の [minY, maxY] に正規化マッピング
    for (int i = 0; i < records.length; i++) {
      if (records[i].bodyFat != null) {
        double f = records[i].bodyFat!;
        double normY = (maxFatY == minFatY)
            ? (minY + maxY) / 2
            : minY + ((f - minFatY) / (maxFatY - minFatY)) * (maxY - minY);
        fatSpots.add(FlSpot(i.toDouble(), normY));
      }
    }

    double interval = ((maxY - minY) / 3).clamp(0.5, 10.0);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.black.withValues(alpha: 0.05),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (spot) => const Color(0xFF1E293B),
            getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
              int idx = s.x.toInt();
              String dateStr = (idx >= 0 && idx < records.length)
                  ? DateFormat('M/d').format(records[idx].date)
                  : '';
              String info = dateStr;
              if (idx >= 0 && idx < records.length) {
                if (records[idx].weight != null) {
                  info += '\n体重: ${records[idx].weight!.toStringAsFixed(1)} kg';
                }
                if (records[idx].bodyFat != null) {
                  info += '\n体脂肪: ${records[idx].bodyFat!.toStringAsFixed(1)} %';
                }
              }
              return LineTooltipItem(
                info,
                const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              );
            }).toList(),
          ),
        ),
        titlesData: FlTitlesData(
          // 左軸: 体重 (kg)
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    value.toStringAsFixed(1),
                    style: const TextStyle(fontSize: 10, color: Color(0xFF7C4DFF), fontWeight: FontWeight.bold),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          // 右軸: 体脂肪率 (%)
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                double origFat = (maxY == minY)
                    ? minFatY
                    : minFatY + ((value - minY) / (maxY - minY)) * (maxFatY - minFatY);
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Text(
                    '${origFat.toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 10, color: Colors.orange.shade800, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.left,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                int idx = value.toInt();
                if (idx >= 0 && idx < records.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('M/d').format(records[idx].date),
                      style: const TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: -0.25,
        maxX: records.length <= 1 ? 0.25 : (records.length - 1).toDouble() + 0.25,
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          // 体重ライン
          if (weightSpots.isNotEmpty)
            LineChartBarData(
              spots: weightSpots,
              isCurved: weightSpots.length > 2,
              curveSmoothness: 0.3,
              color: const Color(0xFF7C4DFF),
              barWidth: 3.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4.5,
                  color: Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: const Color(0xFF7C4DFF),
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF7C4DFF).withValues(alpha: 0.08),
              ),
            ),
          // 体脂肪率ライン
          if (fatSpots.isNotEmpty)
            LineChartBarData(
              spots: fatSpots,
              isCurved: fatSpots.length > 2,
              curveSmoothness: 0.3,
              color: Colors.orange.shade800,
              barWidth: 3.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4.5,
                  color: Colors.white,
                  strokeWidth: 2.5,
                  strokeColor: Colors.orange.shade800,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.orange.withValues(alpha: 0.08),
              ),
            ),
        ],
      ),
    );
  }
}
