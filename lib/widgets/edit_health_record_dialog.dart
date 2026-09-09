import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/health_record.dart';
import '../providers/health_provider.dart';

/// 過去の健康記録・トレーニング記録の編集・削除ダイアログ
class EditHealthRecordDialog extends StatefulWidget {
  final DateTime targetDate;
  final HealthRecord? existingRecord;

  const EditHealthRecordDialog({
    super.key,
    required this.targetDate,
    this.existingRecord,
  });

  static Future<void> show(BuildContext context, DateTime targetDate, {HealthRecord? existingRecord}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => EditHealthRecordDialog(
        targetDate: targetDate,
        existingRecord: existingRecord,
      ),
    );
  }

  @override
  State<EditHealthRecordDialog> createState() => _EditHealthRecordDialogState();
}

class _EditHealthRecordDialogState extends State<EditHealthRecordDialog> {
  late double _conditionScore;
  late bool _hasScore;
  late TextEditingController _symptomsController;
  late TextEditingController _medicationsController;
  late TextEditingController _weightController;
  late TextEditingController _bodyFatController;
  late TextEditingController _sleepController;
  late TextEditingController _stepsController;
  late TextEditingController _caloriesController;

  late List<Workout> _workouts;

  @override
  void initState() {
    super.initState();
    final r = widget.existingRecord;
    _hasScore = r?.conditionScore != null;
    _conditionScore = (r?.conditionScore ?? 7).toDouble();
    _symptomsController = TextEditingController(text: r?.symptoms.join(', ') ?? '');
    _medicationsController = TextEditingController(
      text: r?.medications.map((m) => m.name).join(', ') ?? '',
    );
    _weightController = TextEditingController(text: r?.weight != null ? '${r!.weight}' : '');
    _bodyFatController = TextEditingController(text: r?.bodyFat != null ? '${r!.bodyFat}' : '');
    _sleepController = TextEditingController(text: r?.sleepHours != null ? '${r!.sleepHours}' : '');
    _stepsController = TextEditingController(text: r?.steps != null ? '${r!.steps}' : '');
    _caloriesController = TextEditingController(text: r?.calories != null ? '${r!.calories}' : '');

    _workouts = r != null ? List<Workout>.from(r.workouts) : [];
  }

  @override
  void dispose() {
    _symptomsController.dispose();
    _medicationsController.dispose();
    _weightController.dispose();
    _bodyFatController.dispose();
    _sleepController.dispose();
    _stepsController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  void _addWorkoutItem() {
    final nameCtrl = TextEditingController();
    final weightCtrl = TextEditingController(text: '0');
    final repsCtrl = TextEditingController(text: '10');
    final setsCtrl = TextEditingController(text: '3');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('トレーニング種目を追加', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '種目名 (例: ベンチプレス)'),
              autofocus: true,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: weightCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '重量 (kg)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: repsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '回数 (回)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: setsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'セット数'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _workouts.add(
                    Workout(
                      name: nameCtrl.text.trim(),
                      weight: double.tryParse(weightCtrl.text.trim()) ?? 0,
                      reps: int.tryParse(repsCtrl.text.trim()) ?? 10,
                      sets: int.tryParse(setsCtrl.text.trim()) ?? 3,
                    ),
                  );
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('追加'),
          ),
        ],
      ),
    );
  }

  void _saveRecord() {
    final symptoms = _symptomsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final medications = _medicationsController.text
        .split(',')
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .map((name) => Medication(name: name))
        .toList();

    final updated = HealthRecord(
      date: widget.targetDate,
      conditionScore: _hasScore ? _conditionScore.toInt() : null,
      symptoms: symptoms,
      medications: medications,
      workouts: _workouts,
      weight: double.tryParse(_weightController.text.trim()),
      bodyFat: double.tryParse(_bodyFatController.text.trim()),
      sleepHours: double.tryParse(_sleepController.text.trim()),
      steps: int.tryParse(_stepsController.text.trim()),
      calories: int.tryParse(_caloriesController.text.trim()),
    );

    Provider.of<HealthProvider>(context, listen: false).updateRecord(updated);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${DateFormat("yyyy年M月d日").format(widget.targetDate)} の記録を更新しました')),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('記録の削除', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(
          '${DateFormat("yyyy年M月d日 (E)", "ja_JP").format(widget.targetDate)} の記録を本当に削除しますか？\nこの操作は取り消せません。',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Provider.of<HealthProvider>(context, listen: false).deleteRecord(widget.targetDate);
              Navigator.pop(ctx); // 確認ダイアログを閉じる
              Navigator.pop(context); // 編集ダイアログを閉じる
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${DateFormat("yyyy年M月d日").format(widget.targetDate)} の記録を削除しました')),
              );
            },
            child: const Text('削除する', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy年M月d日 (E)', 'ja_JP');

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
            maxWidth: 500,
          ),
          child: Column(
            children: [
              // ヘッダー
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existingRecord != null ? '記録の修正・削除' : '記録の新規作成',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFormat.format(widget.targetDate),
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black54),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // 入力フィールド（スクロール可能）
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 体調スコア
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('体調スコア (1-10)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Row(
                            children: [
                              Checkbox(
                                value: _hasScore,
                                onChanged: (v) => setState(() => _hasScore = v ?? false),
                              ),
                              const Text('設定する', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      if (_hasScore) ...[
                        Row(
                          children: [
                            Text(
                              '${_conditionScore.toInt()}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _getScoreColor(_conditionScore.toInt()),
                              ),
                            ),
                            Expanded(
                              child: Slider(
                                value: _conditionScore,
                                min: 1,
                                max: 10,
                                divisions: 9,
                                activeColor: _getScoreColor(_conditionScore.toInt()),
                                label: '${_conditionScore.toInt()}',
                                onChanged: (v) => setState(() => _conditionScore = v),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),

                      // 症状
                      TextField(
                        controller: _symptomsController,
                        decoration: const InputDecoration(
                          labelText: '症状 (カンマ区切り)',
                          hintText: '例: 頭痛, 肩こり, 倦怠感',
                          prefixIcon: Icon(Icons.sick_outlined, size: 20),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 服用したお薬
                      TextField(
                        controller: _medicationsController,
                        decoration: const InputDecoration(
                          labelText: 'お薬 (カンマ区切り)',
                          hintText: '例: ロキソプロフェン, エペリゾン',
                          prefixIcon: Icon(Icons.medication_outlined, size: 20),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 筋トレ・運動セクション
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.fitness_center, size: 20, color: Color(0xFF0072FF)),
                              SizedBox(width: 8),
                              Text('筋トレ・運動記録', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            ],
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('種目追加'),
                            onPressed: _addWorkoutItem,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_workouts.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Center(
                            child: Text('運動記録はありません', style: TextStyle(fontSize: 12, color: Colors.black45)),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _workouts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (context, idx) {
                            final w = _workouts[idx];
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${w.name}: ${w.weight > 0 ? "${w.weight}kg " : ""}${w.reps}回 × ${w.sets}set',
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      setState(() {
                                        _workouts.removeAt(idx);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 20),

                      // バイタル・計測値
                      const Row(
                        children: [
                          Icon(Icons.monitor_weight_outlined, size: 20, color: Colors.teal),
                          SizedBox(width: 8),
                          Text('体重・健康計測値', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _weightController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: '体重 (kg)', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _bodyFatController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: '体脂肪率 (%)', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _sleepController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: '睡眠 (時間)', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _stepsController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: '歩数 (歩)', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _caloriesController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '消費カロリー (kcal)', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              ),

              // フッター（アクションボタン）
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    if (widget.existingRecord != null) ...[
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        tooltip: 'この日の記録を削除',
                        onPressed: _confirmDelete,
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('キャンセル'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0072FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onPressed: _saveRecord,
                      child: const Text('保存する', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 8) return Colors.green;
    if (score >= 5) return Colors.orange;
    return Colors.redAccent;
  }
}
