import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/health_record.dart';
import '../models/workout_exercise.dart';
import '../providers/health_provider.dart';
import '../widgets/exercise_detail_modal.dart';

/// ワークアウトセッション中の種目データ保持用モデル
class ActiveSessionExercise {
  final WorkoutExerciseDefinition definition;
  String memo;
  int restSeconds;
  List<WorkoutSet> sets;
  List<WorkoutSet>? previousSets;

  ActiveSessionExercise({
    required this.definition,
    this.memo = '',
    int? restSeconds,
    List<WorkoutSet>? sets,
    this.previousSets,
  })  : restSeconds = restSeconds ?? definition.defaultRestSeconds,
        sets = sets ??
            [
              WorkoutSet(setNumber: 1, weight: 40.0, reps: 10, isCompleted: false),
            ];

  double get completedVolume => sets
      .where((s) => s.isCompleted)
      .fold(0.0, (sum, s) => sum + (s.weight * s.reps));

  int get completedSetsCount => sets.where((s) => s.isCompleted).length;
}

/// Hevyスタイルのライブワークアウト直接記録画面
class WorkoutSessionScreen extends StatefulWidget {
  final DateTime? initialDate;

  const WorkoutSessionScreen({super.key, this.initialDate});

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  late DateTime _sessionDate;
  final List<ActiveSessionExercise> _exercises = [];

  // セッション経過時間タイマー
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;

  // レストタイマー（インターバル）
  Timer? _restTimer;
  int _restTotalSeconds = 0;
  int _restRemainingSeconds = 0;
  bool _isRestTimerActive = false;
  String _activeRestExerciseName = '';

  @override
  void initState() {
    super.initState();
    _sessionDate = widget.initialDate ?? DateTime.now();

    // 経過時間タイマースタート
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });

    // 初期種目のセットアップ（ユーザーがすぐ記録できるようHevy実例の2種目をプリセット）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initInitialExercises();
    });
  }

  void _initInitialExercises() {
    final provider = Provider.of<HealthProvider>(context, listen: false);

    final shoulderPress = WorkoutExerciseDefinition.findByName('シーテッドショルダープレス (マシン)') ??
        WorkoutExerciseDefinition.defaultExercises.first;
    final chestPress = WorkoutExerciseDefinition.findByName('チェストプレス (マシン)') ??
        WorkoutExerciseDefinition.defaultExercises[3];

    final prevShoulder = provider.getPreviousSets(shoulderPress.name, _sessionDate);
    final prevChest = provider.getPreviousSets(chestPress.name, _sessionDate);

    setState(() {
      _exercises.add(
        ActiveSessionExercise(
          definition: shoulderPress,
          previousSets: prevShoulder ??
              [
                WorkoutSet(setNumber: 1, weight: 45, reps: 12),
                WorkoutSet(setNumber: 2, weight: 40, reps: 10),
                WorkoutSet(setNumber: 3, weight: 35, reps: 7),
              ],
          sets: prevShoulder != null && prevShoulder.isNotEmpty
              ? prevShoulder.map((s) => s.copyWith(isCompleted: false)).toList()
              : [
                  WorkoutSet(setNumber: 1, weight: 45, reps: 12),
                  WorkoutSet(setNumber: 2, weight: 45, reps: 9),
                  WorkoutSet(setNumber: 3, weight: 40, reps: 3),
                ],
        ),
      );

      _exercises.add(
        ActiveSessionExercise(
          definition: chestPress,
          previousSets: prevChest ??
              [
                WorkoutSet(setNumber: 1, weight: 42, reps: 15),
                WorkoutSet(setNumber: 2, weight: 42, reps: 10),
                WorkoutSet(setNumber: 3, weight: 42, reps: 6),
              ],
          sets: prevChest != null && prevChest.isNotEmpty
              ? prevChest.map((s) => s.copyWith(isCompleted: false)).toList()
              : [
                  WorkoutSet(setNumber: 1, weight: 42, reps: 15),
                  WorkoutSet(setNumber: 2, weight: 42, reps: 10),
                  WorkoutSet(setNumber: 3, weight: 42, reps: 6),
                ],
        ),
      );
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  // レストタイマーの開始
  void _startRestTimer(int durationSeconds, String exerciseName) {
    _restTimer?.cancel();
    setState(() {
      _restTotalSeconds = durationSeconds;
      _restRemainingSeconds = durationSeconds;
      _isRestTimerActive = true;
      _activeRestExerciseName = exerciseName;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_restRemainingSeconds > 1) {
        setState(() {
          _restRemainingSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _restRemainingSeconds = 0;
          _isRestTimerActive = false;
        });
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏱ $_activeRestExerciseName の休憩時間が終了しました！次のセットへ！'),
            backgroundColor: const Color(0xFF0072FF),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
  }

  void _adjustRestTimer(int seconds) {
    setState(() {
      _restRemainingSeconds = (_restRemainingSeconds + seconds).clamp(0, 3600);
      if (_restRemainingSeconds == 0) {
        _stopRestTimer();
      }
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    setState(() {
      _isRestTimerActive = false;
      _restRemainingSeconds = 0;
    });
  }

  String _formatTime(int totalSec) {
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '${m}min ${s}s';
  }

  String _formatDigitalTime(int totalSec) {
    final m = (totalSec ~/ 60).toString().padLeft(2, '0');
    final s = (totalSec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  double get _totalVolume =>
      _exercises.fold(0.0, (sum, ex) => sum + ex.completedVolume);

  int get _totalCompletedSets =>
      _exercises.fold(0, (sum, ex) => sum + ex.completedSetsCount);

  // セッション終了とデータ保存
  Future<void> _finishWorkout() async {
    if (_totalCompletedSets == 0) {
      final shouldFinish = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('完了セットがありません', style: TextStyle(color: Colors.white)),
          content: const Text(
            'まだチェック完了したセットがありません。セッションを終了して保存しますか？',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('キャンセル', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0072FF)),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('終了する', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (shouldFinish != true) return;
    }

    if (!mounted) return;
    final provider = Provider.of<HealthProvider>(context, listen: false);

    // 有効な種目を Workout モデルに変換
    final List<Workout> sessionWorkouts = [];
    for (var ex in _exercises) {
      // 完了したセット、または未完了でも入力されたセット
      final completedSets = ex.sets.where((s) => s.isCompleted).toList();
      final targetSets = completedSets.isNotEmpty ? completedSets : ex.sets;

      if (targetSets.isNotEmpty) {
        // 代表値の算出 (MAX重量と平均レップ数)
        double maxWeight = 0;
        int totalReps = 0;
        for (var s in targetSets) {
          if (s.weight > maxWeight) maxWeight = s.weight;
          totalReps += s.reps;
        }
        final avgReps = (totalReps / targetSets.length).round();

        sessionWorkouts.add(
          Workout(
            name: ex.definition.name,
            weight: maxWeight,
            reps: avgReps > 0 ? avgReps : 10,
            sets: targetSets.length,
            setDetails: ex.sets,
            memo: ex.memo.isNotEmpty ? ex.memo : null,
            restSeconds: ex.restSeconds,
          ),
        );
      }
    }

    if (sessionWorkouts.isNotEmpty) {
      await provider.saveWorkoutSession(_sessionDate, sessionWorkouts);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🎉 トレーニング完了！ 総負荷量: ${_totalVolume.toStringAsFixed(0)}kg (${sessionWorkouts.length}種目 / $_totalCompletedSetsセット)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF00C853),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Hevyのピュアブラック背景
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'トレーニング記録',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer_outlined, color: Colors.white70),
            onPressed: () {
              if (!_isRestTimerActive) {
                _startRestTimer(120, 'インターバル');
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0072FF), // Hevy鮮やかブルー
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                elevation: 0,
              ),
              onPressed: _finishWorkout,
              child: const Text('終了', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. サマリーバー（時間、ボリューム、セット、部位ピクトグラム）
          _buildSummaryBar(),

          // 2. 種目・セットリスト
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 120),
              itemCount: _exercises.length + 1,
              itemBuilder: (ctx, idx) {
                if (idx == _exercises.length) {
                  return _buildAddExerciseButton();
                }
                return _buildExerciseCard(_exercises[idx], idx);
              },
            ),
          ),
        ],
      ),
      // 3. 画面下部固定レストタイマーバー
      bottomSheet: _isRestTimerActive ? _buildBottomRestTimer() : null,
    );
  }

  // --- サマリーバー ---
  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        border: Border(bottom: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildSummaryItem('時間', _formatTime(_elapsedSeconds), isBlue: true),
          _buildSummaryItem('ボリューム', '${_totalVolume.toStringAsFixed(0)} kg'),
          _buildSummaryItem('セット', '$_totalCompletedSets'),
          // 筋肉ピクトグラム（ターゲット部位）
          Row(
            children: const [
              Icon(Icons.accessibility_new, color: Color(0xFF0072FF), size: 22),
              Icon(Icons.accessibility, color: Colors.white38, size: 22),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isBlue = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: isBlue ? const Color(0xFF00C6FF) : Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --- 種目カードブロック ---
  Widget _buildExerciseCard(ActiveSessionExercise exercise, int exIndex) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        border: Border(bottom: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 種目ヘッダー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // アイコン
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.fitness_center, color: Colors.black, size: 20),
                ),
                const SizedBox(width: 12),
                // 種目名リンク（タップで解説モーダル！）
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final currentW = exercise.sets.isNotEmpty ? exercise.sets.first.weight : null;
                      ExerciseDetailModal.show(context, exercise.definition.name, currentWeight: currentW);
                    },
                    child: Text(
                      exercise.definition.name,
                      style: const TextStyle(
                        color: Color(0xFF0072FF), // Hevyブルースタイルリンク
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                // 3点メニュー
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  color: const Color(0xFF1E1E1E),
                  onSelected: (val) {
                    if (val == 'delete') {
                      setState(() => _exercises.removeAt(exIndex));
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('種目を削除', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // メモ欄
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'ここにメモを追加...',
                hintStyle: TextStyle(color: Colors.white30, fontSize: 13),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (val) => exercise.memo = val,
            ),
          ),

          // 休憩タイマー設定表示
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: GestureDetector(
              onTap: () => _showRestTimerPicker(exercise),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Color(0xFF0072FF), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '休憩タイマー: ${_formatTime(exercise.restSeconds)}',
                    style: const TextStyle(
                      color: Color(0xFF0072FF),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // セットテーブルヘッダー
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: const [
                SizedBox(width: 36, child: Text('セット', style: TextStyle(color: Colors.white54, fontSize: 12))),
                Expanded(flex: 3, child: Text('前回', style: TextStyle(color: Colors.white54, fontSize: 12))),
                Expanded(flex: 3, child: Center(child: Text('↔ KG', style: TextStyle(color: Colors.white54, fontSize: 12)))),
                Expanded(flex: 3, child: Center(child: Text('レップ数', style: TextStyle(color: Colors.white54, fontSize: 12)))),
                SizedBox(width: 44, child: Center(child: Icon(Icons.check, color: Colors.white54, size: 18))),
              ],
            ),
          ),

          // セットテーブル各行
          ...exercise.sets.asMap().entries.map((entry) {
            final setIdx = entry.key;
            final set = entry.value;
            final prevSet = exercise.previousSets != null && setIdx < exercise.previousSets!.length
                ? exercise.previousSets![setIdx]
                : null;
            return _buildSetRow(exercise, set, setIdx, prevSet);
          }),

          // 「＋ セット追加」ボタン
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E1E1E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                onPressed: () {
                  setState(() {
                    final lastSet = exercise.sets.isNotEmpty ? exercise.sets.last : null;
                    exercise.sets.add(
                      WorkoutSet(
                        setNumber: exercise.sets.length + 1,
                        weight: lastSet?.weight ?? 40.0,
                        reps: lastSet?.reps ?? 10,
                        isCompleted: false,
                      ),
                    );
                  });
                },
                child: const Text('＋ セット追加', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // --- セット行（完了時にシックな濃い緑色ハイライト！） ---
  Widget _buildSetRow(
    ActiveSessionExercise exercise,
    WorkoutSet set,
    int setIndex,
    WorkoutSet? prevSet,
  ) {
    final isDone = set.isCompleted;
    // Hevy実物通りのシックな濃いグリーン (#122E15)
    final rowBg = isDone ? const Color(0xFF122E15) : Colors.transparent;

    return Container(
      color: rowBg,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // セット番号
          SizedBox(
            width: 36,
            child: Text(
              '${set.setNumber}',
              style: TextStyle(
                color: isDone ? Colors.green.shade300 : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),

          // 前回記録（例: 45kg x 12）
          Expanded(
            flex: 3,
            child: Text(
              prevSet != null
                  ? '${prevSet.weight.toStringAsFixed(prevSet.weight % 1 == 0 ? 0 : 1)}kg x ${prevSet.reps}'
                  : '-',
              style: TextStyle(
                color: isDone ? Colors.green.shade200.withOpacity(0.8) : Colors.white38,
                fontSize: 13,
              ),
            ),
          ),

          // 重量(KG)入力
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 34,
              decoration: BoxDecoration(
                color: isDone ? Colors.transparent : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: TextFormField(
                initialValue: set.weight > 0 ? set.weight.toStringAsFixed(set.weight % 1 == 0 ? 0 : 1) : '',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.only(top: 8)),
                onChanged: (val) {
                  final parsed = double.tryParse(val);
                  if (parsed != null) {
                    exercise.sets[setIndex] = set.copyWith(weight: parsed);
                    setState(() {});
                  }
                },
              ),
            ),
          ),

          // レップ数入力
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 34,
              decoration: BoxDecoration(
                color: isDone ? Colors.transparent : const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(6),
              ),
              child: TextFormField(
                initialValue: set.reps > 0 ? '${set.reps}' : '',
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.only(top: 8)),
                onChanged: (val) {
                  final parsed = int.tryParse(val);
                  if (parsed != null) {
                    exercise.sets[setIndex] = set.copyWith(reps: parsed);
                    setState(() {});
                  }
                },
              ),
            ),
          ),

          // 完了チェックボタン（タップでタイマー起動！）
          SizedBox(
            width: 44,
            child: GestureDetector(
              onTap: () {
                final newCompleted = !set.isCompleted;
                setState(() {
                  exercise.sets[setIndex] = set.copyWith(isCompleted: newCompleted);
                });
                HapticFeedback.lightImpact();

                // 完了チェック時、自動でレストタイマー起動！
                if (newCompleted) {
                  _startRestTimer(exercise.restSeconds, exercise.definition.name);
                }
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDone ? const Color(0xFF4CAF50) : const Color(0xFF242424),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.check,
                  size: 20,
                  color: isDone ? Colors.white : Colors.white24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 種目追加ボタン ---
  Widget _buildAddExerciseButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFF0072FF), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onPressed: _showAddExerciseSheet,
        icon: const Icon(Icons.add, color: Color(0xFF0072FF)),
        label: const Text(
          '種目を追加',
          style: TextStyle(color: Color(0xFF0072FF), fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  // --- 種目選択シート（部位別） ---
  void _showAddExerciseSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        String filter = 'すべて';
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final categories = ['すべて', '肩', '胸', '背中', '脚', '腕', '腹・体幹'];
            final filtered = filter == 'すべて'
                ? WorkoutExerciseDefinition.defaultExercises
                : WorkoutExerciseDefinition.defaultExercises.where((e) => e.primaryMuscle == filter).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '種目を選択',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 部位フィルターピル
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categories.map((cat) {
                        final isSel = filter == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat),
                            selected: isSel,
                            selectedColor: const Color(0xFF0072FF),
                            backgroundColor: const Color(0xFF2A2A2A),
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : Colors.white70,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (val) {
                              if (val) setSheetState(() => filter = cat);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 種目リスト
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final def = filtered[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(color: Colors.white12, shape: BoxShape.circle),
                            child: const Icon(Icons.fitness_center, color: Colors.white, size: 18),
                          ),
                          title: Text(def.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          subtitle: Text('${def.category} • ${def.primaryMuscle}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: const Icon(Icons.add_circle_outline, color: Color(0xFF0072FF)),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            final provider = Provider.of<HealthProvider>(this.context, listen: false);
                            final prev = provider.getPreviousSets(def.name, _sessionDate);
                            setState(() {
                              _exercises.add(
                                ActiveSessionExercise(
                                  definition: def,
                                  previousSets: prev,
                                  sets: prev != null && prev.isNotEmpty
                                      ? prev.map((s) => s.copyWith(isCompleted: false)).toList()
                                      : [
                                          WorkoutSet(setNumber: 1, weight: 40, reps: 10),
                                          WorkoutSet(setNumber: 2, weight: 40, reps: 10),
                                          WorkoutSet(setNumber: 3, weight: 40, reps: 8),
                                        ],
                                ),
                              );
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- 休憩時間変更ダイアログ ---
  void _showRestTimerPicker(ActiveSessionExercise exercise) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final options = [30, 60, 90, 120, 150, 180, 240, 300];
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('休憩タイマーの時間を設定', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              ...options.map((sec) {
                final isCurrent = exercise.restSeconds == sec;
                return ListTile(
                  title: Text(_formatTime(sec), style: TextStyle(color: isCurrent ? const Color(0xFF0072FF) : Colors.white, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                  trailing: isCurrent ? const Icon(Icons.check, color: Color(0xFF0072FF)) : null,
                  onTap: () {
                    setState(() => exercise.restSeconds = sec);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // --- 画面下部固定レストタイマーバー (画像1準拠) ---
  Widget _buildBottomRestTimer() {
    final progress = _restTotalSeconds > 0
        ? (_restRemainingSeconds / _restTotalSeconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      color: const Color(0xFF1E1E1E),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 上部青プログレスバー
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0072FF)),
              minHeight: 3,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // -15s ボタン
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C2C2C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      elevation: 0,
                    ),
                    onPressed: () => _adjustRestTimer(-15),
                    child: const Text('-15', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),

                  // デジタル残り時間表示
                  Text(
                    _formatDigitalTime(_restRemainingSeconds),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),

                  // +15s ボタン
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C2C2C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      elevation: 0,
                    ),
                    onPressed: () => _adjustRestTimer(15),
                    child: const Text('+15', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),

                  // スキップボタン
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0072FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 0,
                    ),
                    onPressed: _stopRestTimer,
                    child: const Text('スキップ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
