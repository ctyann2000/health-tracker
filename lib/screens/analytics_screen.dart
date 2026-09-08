import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/health_provider.dart';
import '../models/health_record.dart';
import '../utils/workout_analyzer.dart';

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
                      _buildChartCard(
                        context: context,
                        title: '体重・体脂肪率',
                        icon: Icons.monitor_weight,
                        color: const Color(0xFF9575CD),
                        child: _buildWeightChart(recentRecords),
                      ).animate().fade(delay: 400.ms).slideY(begin: 0.05),
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
                              Text('${DateTime.now().year}年 ${DateTime.now().month}月', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: const Color(0xFF7986CB).withOpacity(0.2),
              ),
            ),
          ],
          maxY: maxSleep > 10 ? maxSleep + 2 : 12,
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

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.toInt()}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              },
            ),
          ),
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
                color: Colors.grey.withOpacity(0.1),
              ),
            )
          ],
        )
      );
    }

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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

  // --- 体重グラフ ---
  Widget _buildWeightChart(List<HealthRecord> records) {
    List<FlSpot> weightSpots = [];
    List<FlSpot> fatSpots = [];
    double maxVal = 0, minVal = 1000;
    
    for (int i = 0; i < records.length; i++) {
      if (records[i].weight != null) {
        weightSpots.add(FlSpot(i.toDouble(), records[i].weight!));
        if (records[i].weight! > maxVal) maxVal = records[i].weight!;
        if (records[i].weight! < minVal) minVal = records[i].weight!;
      }
      if (records[i].bodyFat != null) {
        fatSpots.add(FlSpot(i.toDouble(), records[i].bodyFat!));
        if (records[i].bodyFat! > maxVal) maxVal = records[i].bodyFat!;
        if (records[i].bodyFat! < minVal) minVal = records[i].bodyFat!;
      }
    }
    if (minVal == 1000) minVal = 0;

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
            if (weightSpots.isNotEmpty)
              LineChartBarData(
                spots: weightSpots,
                isCurved: true,
                color: const Color(0xFF9575CD),
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: FlDotData(show: true),
              ),
            if (fatSpots.isNotEmpty)
              LineChartBarData(
                spots: fatSpots,
                isCurved: true,
                color: Colors.orange,
                barWidth: 4,
                isStrokeCapRound: true,
                dotData: FlDotData(show: true),
              ),
          ],
          maxY: maxVal + 5,
          minY: (minVal - 5 > 0) ? minVal - 5 : 0,
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

            return Container(
              decoration: BoxDecoration(
                color: isToday ? Theme.of(context).colorScheme.primary : Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (hasBadHealth || hasWorkout) ? Theme.of(context).colorScheme.secondary : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: isToday ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$day', style: TextStyle(fontSize: 14, fontWeight: isToday ? FontWeight.bold : FontWeight.normal, color: isToday ? Colors.white : Colors.black87)),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (hasBadHealth) Icon(Icons.sick, size: 10, color: isToday ? Colors.white : Colors.redAccent),
                        if (hasWorkout) Icon(Icons.fitness_center, size: 10, color: isToday ? Colors.white : Colors.cyan),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
