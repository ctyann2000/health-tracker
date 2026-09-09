import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/health_provider.dart';
import '../models/health_record.dart';
import '../widgets/edit_health_record_dialog.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _selectedFilter = 'すべて';
  final List<String> _filters = ['すべて', '体調不良', '服薬あり', '運動あり'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // 背景は親のグラデーションを透過
      appBar: AppBar(
        title: const Text('履歴・検索', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<HealthProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // 日付の降順でソート
          final records = List<HealthRecord>.from(provider.records)
            ..sort((a, b) => b.date.compareTo(a.date));

          // フィルター適用
          final filteredRecords = records.where((r) {
            if (_selectedFilter == '体調不良') return (r.conditionScore != null && r.conditionScore! < 5) || r.symptoms.isNotEmpty;
            if (_selectedFilter == '服薬あり') return r.medications.isNotEmpty;
            if (_selectedFilter == '運動あり') return r.workouts.isNotEmpty || (r.steps != null && r.steps! > 0);
            return true; // 'すべて'
          }).toList();

          return Column(
            children: [
              _buildFilterChips(),
              Expanded(
                child: filteredRecords.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredRecords.length,
                        itemBuilder: (context, index) {
                          return _buildHistoryCard(filteredRecords[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedFilter = filter);
                }
              },
              backgroundColor: Colors.white.withOpacity(0.3),
              selectedColor: Colors.white.withOpacity(0.8),
              labelStyle: TextStyle(
                color: isSelected ? Colors.black87 : Colors.black54,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.white.withOpacity(0.5)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded, size: 64, color: Colors.black26),
          const SizedBox(height: 16),
          const Text(
            'まだ記録がありません',
            style: TextStyle(color: Colors.black54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(HealthRecord record) {
    final dateFormat = DateFormat('yyyy/MM/dd (E)', 'ja_JP');
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), // すりガラス効果
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.5),
                  Colors.white.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                EditHealthRecordDialog.show(context, record.date, existingRecord: record);
              },
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 日付と体調スコア・アクションボタン
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          dateFormat.format(record.date),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (record.conditionScore != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getScoreColor(record.conditionScore!).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _getScoreColor(record.conditionScore!).withOpacity(0.3)),
                                ),
                                child: Text(
                                  'スコア: ${record.conditionScore}',
                                  style: TextStyle(
                                    color: _getScoreColor(record.conditionScore!),
                                    fontWeight: FontWeight.bold, 
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0072FF)),
                              tooltip: 'この記録を修正',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                EditHealthRecordDialog.show(context, record.date, existingRecord: record);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              tooltip: 'この記録を削除',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () {
                                _confirmDeleteRecord(context, record);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // サマリー情報
                    if (record.symptoms.isNotEmpty)
                      _buildDetailRow(Icons.sick_outlined, '症状: ${record.symptoms.join(", ")}'),
                    if (record.medications.isNotEmpty)
                      _buildDetailRow(Icons.medication_outlined, '薬: ${record.medications.map((m) => m.name).join(", ")}'),
                    if (record.workouts.isNotEmpty)
                      _buildDetailRow(Icons.fitness_center, '運動: ${record.workouts.map((w) => w.name).join(", ")}'),
                    if (record.steps != null && record.steps! > 0)
                      _buildDetailRow(Icons.directions_walk, '歩数: ${record.steps}歩'),
                    if (record.sleepHours != null)
                      _buildDetailRow(Icons.bedtime_outlined, '睡眠: ${record.sleepHours}時間'),
                    if (record.weight != null)
                      _buildDetailRow(Icons.monitor_weight_outlined, '体重: ${record.weight}kg${record.bodyFat != null ? " (体脂肪: ${record.bodyFat}%)" : ""}'),
                    
                    // なにもない場合
                    if (record.symptoms.isEmpty && 
                        record.medications.isEmpty && 
                        record.workouts.isEmpty && 
                        (record.steps == null || record.steps == 0) &&
                        record.sleepHours == null &&
                        record.weight == null)
                      const Text('詳細記録なし', style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteRecord(BuildContext context, HealthRecord record) {
    final dateFormat = DateFormat('yyyy年M月d日 (E)', 'ja_JP');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('記録の削除', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text(
          '${dateFormat.format(record.date)} の記録を本当に削除しますか？\nこの操作は取り消せません。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Provider.of<HealthProvider>(context, listen: false).deleteRecord(record.date);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${dateFormat.format(record.date)} の記録を削除しました')),
              );
            },
            child: const Text('削除する', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.black54),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 8) return Colors.green;
    if (score >= 5) return Colors.orange;
    return Colors.red;
  }
}
