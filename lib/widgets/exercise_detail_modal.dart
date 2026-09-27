import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/workout_exercise.dart';
import '../providers/health_provider.dart';

/// Hevyスタイルの種目詳細・解説・1RM推移モーダル
class ExerciseDetailModal extends StatefulWidget {
  final String exerciseName;
  final double? currentWeight;

  const ExerciseDetailModal({
    super.key,
    required this.exerciseName,
    this.currentWeight,
  });

  static void show(BuildContext context, String exerciseName, {double? currentWeight}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExerciseDetailModal(
        exerciseName: exerciseName,
        currentWeight: currentWeight,
      ),
    );
  }

  @override
  State<ExerciseDetailModal> createState() => _ExerciseDetailModalState();
}

class _ExerciseDetailModalState extends State<ExerciseDetailModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late WorkoutExerciseDefinition _definition;

  // グラフ切り替え: 0: 最重量, 1: 1RM, 2: ベストセットボリューム
  int _selectedMetricIndex = 0;
  String _selectedRange = '過去3ヶ月間';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _definition = WorkoutExerciseDefinition.findByName(widget.exerciseName) ??
        WorkoutExerciseDefinition(
          id: 'custom_${widget.exerciseName}',
          name: widget.exerciseName,
          category: 'マシン',
          primaryMuscle: '全身',
          secondaryMuscle: '体幹',
          instructions: '1. 正しい姿勢を作り、体幹を意識して動作を開始します。\n2. 反動を使わずにゆっくりと対象筋肉を収縮させます。\n3. 息を止めずにコントロールしながら元の位置へ戻します。',
          tips: ['無理のない重量から始め、フォームを最優先しましょう。', '痛みや違和感がある場合は直ちに中止してください。'],
        );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<HealthProvider>(context);
    final history = provider.getExerciseHistory(widget.exerciseName);

    // 個人記録（PR）の計算
    double allTimeMaxWeight = 0;
    double allTimeBest1RM = 0;
    double allTimeBestVol = 0;
    String bestVolText = '-';

    for (var point in history) {
      if (point.maxWeight > allTimeMaxWeight) allTimeMaxWeight = point.maxWeight;
      if (point.best1RM > allTimeBest1RM) allTimeBest1RM = point.best1RM;
      for (var s in point.sets) {
        final vol = s.weight * s.reps;
        if (vol > allTimeBestVol) {
          allTimeBestVol = vol;
          bestVolText = '${s.weight.toStringAsFixed(s.weight % 1 == 0 ? 0 : 1)}kg x ${s.reps}';
        }
      }
    }

    if (widget.currentWeight != null && widget.currentWeight! > allTimeMaxWeight) {
      allTimeMaxWeight = widget.currentWeight!;
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF121212), // Hevyダーク背景
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 上部ドラッグハンドル
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ヘッダーバー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Text(
                    _definition.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: Colors.white70),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // タブバー（概要 / 履歴 / 方法）
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF0072FF), // Hevyブルー
              indicatorWeight: 3,
              labelColor: const Color(0xFF0072FF),
              unselectedLabelColor: Colors.white60,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              tabs: const [
                Tab(text: '概要'),
                Tab(text: '履歴'),
                Tab(text: '方法'),
              ],
            ),
          ),

          // タブコンテンツ
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(history, allTimeMaxWeight, allTimeBest1RM, bestVolText),
                _buildHistoryTab(history),
                _buildInstructionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. 概要タブ ---
  Widget _buildOverviewTab(
    List<ExerciseHistoryPoint> history,
    double maxWeight,
    double best1RM,
    String bestVolText,
  ) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 種目イラスト・ピクトグラムプレビュー
          _buildExerciseIllustration(),

          const SizedBox(height: 16),

          // 種目名 & 部位情報
          Text(
            _definition.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'メイン : ${_definition.primaryMuscle}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(width: 14),
              Text(
                '二次 : ${_definition.secondaryMuscle}',
                style: const TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 現在重量 & 期間切り替え
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    widget.currentWeight != null
                        ? '${widget.currentWeight!.toStringAsFixed(widget.currentWeight! % 1 == 0 ? 0 : 1)} kg'
                        : (maxWeight > 0 ? '${maxWeight.toStringAsFixed(maxWeight % 1 == 0 ? 0 : 1)} kg' : '0 kg'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '(進行中)',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
              DropdownButton<String>(
                value: _selectedRange,
                dropdownColor: const Color(0xFF1E1E1E),
                underline: const SizedBox(),
                style: const TextStyle(color: Color(0xFF0072FF), fontSize: 13, fontWeight: FontWeight.bold),
                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF0072FF), size: 18),
                items: ['過去1ヶ月間', '過去3ヶ月間', '全期間'].map((String val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(val),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedRange = val);
                },
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 折れ線グラフエリア
          _buildProgressChart(history),

          const SizedBox(height: 12),

          // メトリクス切り替えピルボタン（最重量 / 1RM / ベストセットボリューム）
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMetricPill(0, '最重量'),
                const SizedBox(width: 8),
                _buildMetricPill(1, '1RM'),
                const SizedBox(width: 8),
                _buildMetricPill(2, 'ベストセットボリューム'),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),

          // 個人記録（PR）サマリー
          Row(
            children: const [
              Text('🥇', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                '個人記録',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Spacer(),
              Icon(Icons.help_outline, color: Colors.white38, size: 18),
            ],
          ),
          const SizedBox(height: 12),

          _buildPrRow('最重量', maxWeight > 0 ? '${maxWeight.toStringAsFixed(maxWeight % 1 == 0 ? 0 : 1)}kg' : '-'),
          const Divider(color: Colors.white12, height: 16),
          _buildPrRow(
            'ベスト1RM',
            best1RM > 0 ? '${best1RM.toStringAsFixed(2)}kg' : '-',
          ),
          const Divider(color: Colors.white12, height: 16),
          _buildPrRow('ベストセットボリューム', bestVolText),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // --- イラスト / 部位ピクトグラム表示 ---
  Widget _buildExerciseIllustration() {
    IconData iconData = Icons.fitness_center;
    Color accentColor = const Color(0xFFFF5252);

    switch (_definition.primaryMuscle) {
      case '肩':
        iconData = Icons.accessibility_new;
        accentColor = const Color(0xFFFF7043);
        break;
      case '胸':
        iconData = Icons.shield_outlined;
        accentColor = const Color(0xFFEF5350);
        break;
      case '背中':
        iconData = Icons.airline_seat_recline_extra;
        accentColor = const Color(0xFF42A5F5);
        break;
      case '脚':
        iconData = Icons.directions_walk;
        accentColor = const Color(0xFF66BB6A);
        break;
      case '腕':
        iconData = Icons.sports_kabaddi;
        accentColor = const Color(0xFFAB47BC);
        break;
      case '腹・体幹':
        iconData = Icons.self_improvement;
        accentColor = const Color(0xFFFFA726);
        break;
    }

    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景サークル
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accentColor.withOpacity(0.12),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(iconData, size: 72, color: accentColor),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.withOpacity(0.5)),
                ),
                child: Text(
                  '${_definition.category} • ${_definition.primaryMuscle}',
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 折れ線グラフ ---
  Widget _buildProgressChart(List<ExerciseHistoryPoint> history) {
    if (history.isEmpty) {
      return Container(
        height: 160,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          '過去のトレーニングデータがまだありません\nこの種目を記録すると成長推移グラフが表示されます',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12, height: 1.5),
        ),
      );
    }

    // 選択された指標に応じたデータポイントの抽出
    final spots = <FlSpot>[];
    double minY = double.infinity;
    double maxY = 0;

    for (int i = 0; i < history.length; i++) {
      double val = 0;
      if (_selectedMetricIndex == 0) {
        val = history[i].maxWeight;
      } else if (_selectedMetricIndex == 1) {
        val = history[i].best1RM;
      } else {
        val = history[i].bestSetVolume;
      }

      if (val < minY) minY = val;
      if (val > maxY) maxY = val;
      spots.add(FlSpot(i.toDouble(), val));
    }

    if (minY == double.infinity) minY = 0;
    if (maxY <= minY) maxY = minY + 10;
    final paddingY = (maxY - minY) * 0.2;

    return Container(
      height: 180,
      padding: const EdgeInsets.only(right: 16, top: 12, bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white10, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}kg',
                    style: const TextStyle(color: Colors.white38, fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx >= 0 && idx < history.length) {
                    final d = history[idx].date;
                    return Text(
                      '${d.month}/${d.day}',
                      style: const TextStyle(color: Colors.white38, fontSize: 10),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minY: (minY - paddingY).clamp(0, double.infinity),
          maxY: maxY + paddingY,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: const Color(0xFF0072FF),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 4,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: const Color(0xFF0072FF),
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF0072FF).withOpacity(0.3),
                    const Color(0xFF0072FF).withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricPill(int index, String label) {
    final isSelected = _selectedMetricIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedMetricIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0072FF) : const Color(0xFF262626),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white70,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildPrRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF0072FF),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. 履歴タブ ---
  Widget _buildHistoryTab(List<ExerciseHistoryPoint> history) {
    if (history.isEmpty) {
      return const Center(
        child: Text('まだ履歴がありません', style: TextStyle(color: Colors.white38)),
      );
    }

    final reversed = history.reversed.toList();
    final f = DateFormat('yyyy年M月d日 (E)', 'ja_JP');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reversed.length,
      itemBuilder: (ctx, idx) {
        final point = reversed[idx];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    f.format(point.date),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'MAX ${point.maxWeight.toStringAsFixed(point.maxWeight % 1 == 0 ? 0 : 1)}kg',
                    style: const TextStyle(color: Color(0xFF0072FF), fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: point.sets.map((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C2C),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${s.setNumber}: ${s.weight.toStringAsFixed(s.weight % 1 == 0 ? 0 : 1)}kg × ${s.reps}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 3. 方法（フォーム解説）タブ ---
  Widget _buildInstructionsTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '動作手順・ステップ解説',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Text(
              _definition.instructions,
              style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.6),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'フォームのコツ・注意点',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ..._definition.tips.map((tip) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A261E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade800.withOpacity(0.5)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tip,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
