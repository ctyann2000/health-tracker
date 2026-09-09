import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/health_provider.dart';
import '../models/prescription_record.dart';

/// 本格処方・お薬手帳画面
class MedicationNotebookScreen extends StatefulWidget {
  const MedicationNotebookScreen({super.key});

  @override
  State<MedicationNotebookScreen> createState() => _MedicationNotebookScreenState();
}

class _MedicationNotebookScreenState extends State<MedicationNotebookScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final healthProvider = Provider.of<HealthProvider>(context);
    final allPrescriptions = healthProvider.prescriptions;

    // 検索フィルター
    final filteredPrescriptions = allPrescriptions.where((p) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final inHospital = p.hospitalName.toLowerCase().contains(query);
      final inPharmacy = (p.pharmacyName ?? '').toLowerCase().contains(query);
      final inDept = (p.department ?? '').toLowerCase().contains(query);
      final inDoctor = (p.doctorName ?? '').toLowerCase().contains(query);
      final inMeds = p.medications.any((m) =>
          m.name.toLowerCase().contains(query) ||
          (m.efficacy ?? '').toLowerCase().contains(query) ||
          (m.sideEffects ?? '').toLowerCase().contains(query));
      return inHospital || inPharmacy || inDept || inDoctor || inMeds;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.menu_book, color: Color(0xFF00A86B), size: 24),
            SizedBox(width: 8),
            Text(
              'お薬手帳',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white.withOpacity(0.85),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            tooltip: 'サンプル処方データにリセット',
            onPressed: () {
              _showResetDialog(context, healthProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF00A86B)),
            tooltip: '処方箋を手動追加',
            onPressed: () {
              _showAddPrescriptionDialog(context, healthProvider);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 検索バー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '薬品名、病院名、効能、副作用で検索...',
                hintStyle: const TextStyle(fontSize: 13, color: Colors.black38),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF00A86B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
            ),
          ),

          // 処方箋リスト
          Expanded(
            child: filteredPrescriptions.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: filteredPrescriptions.length,
                    itemBuilder: (context, index) {
                      return _buildPrescriptionCard(
                        context,
                        filteredPrescriptions[index],
                        healthProvider,
                      ).animate().fade(delay: (index * 80).ms).slideY(begin: 0.05);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF00A86B),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('処方箋を追加', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          _showAddPrescriptionDialog(context, healthProvider);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medication_liquid_outlined, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'お薬手帳の履歴がありません',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const Text(
              'ホーム画面のチャットから処方箋や薬袋の写真を送るか、右下の「処方箋を追加」ボタンから手動で登録してください。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black45, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  /// 1回の調剤・処方単位のカード
  Widget _buildPrescriptionCard(
    BuildContext context,
    PrescriptionRecord prescription,
    HealthProvider provider,
  ) {
    final dateFormat = DateFormat('yyyy年M月d日 (E)', 'ja_JP');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日付バー
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 15, color: Color(0xFF00A86B)),
                    const SizedBox(width: 6),
                    Text(
                      dateFormat.format(prescription.date),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: Colors.black45, size: 20),
                  padding: EdgeInsets.zero,
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('この処方を削除', style: TextStyle(color: Colors.red, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (val) {
                    if (val == 'delete') {
                      provider.deletePrescription(prescription.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('処方記録を削除しました')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          // 病院・薬局情報セクション
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 病院名
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A86B).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_hospital, color: Color(0xFF00A86B), size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prescription.hospitalName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00A86B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 薬局名と医療費
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (prescription.pharmacyName != null && prescription.pharmacyName!.isNotEmpty)
                      Expanded(
                        child: Text(
                          '薬局名: ',
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (prescription.cost != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '医療費合計: 円',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // 診療科と医師名
                Row(
                  children: [
                    if (prescription.department != null && prescription.department!.isNotEmpty)
                      Text(
                        '診療科:   ',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    if (prescription.doctorName != null && prescription.doctorName!.isNotEmpty)
                      Text(
                        '医師: ',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // 処方薬リスト
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: prescription.medications.length,
            separatorBuilder: (context, idx) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, mIdx) {
              final med = prescription.medications[mIdx];
              return _buildMedicationRow(context, med);
            },
          ),
        ],
      ),
    );
  }

  /// 各薬品の行（タップで詳細モーダル表示）
  Widget _buildMedicationRow(BuildContext context, PrescriptionMedication med) {
    final isInternal = med.category == '内服' || med.dosage.contains('内服');

    return InkWell(
      onTap: () {
        _showMedicationDetailSheet(context, med);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 薬品アイコン・区分バッジ
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isInternal
                    ? const Color(0xFF3B82F6).withOpacity(0.12)
                    : const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isInternal ? Icons.medication : Icons.sanitizer,
                color: isInternal ? const Color(0xFF2563EB) : const Color(0xFF059669),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // 薬品名と用法
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    med.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    med.dosage,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      height: 1.3,
                    ),
                  ),
                  if (med.efficacy != null && med.efficacy!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '効用: ',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF0284C7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 詳細へ進む矢印
            const Icon(Icons.chevron_right, color: Colors.black26, size: 22),
          ],
        ),
      ),
    );
  }

  /// 薬品の詳細情報モーダル（効能・効果、副作用、注意事項を詳しく表示）
  void _showMedicationDetailSheet(BuildContext context, PrescriptionMedication med) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 上部ハンドル
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 薬品名
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (med.category == '内服' || med.dosage.contains('内服'))
                              ? Colors.blue.shade50
                              : Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          med.category ?? (med.dosage.contains('内服') ? '内服' : '外用'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: (med.category == '内服' || med.dosage.contains('内服'))
                                ? Colors.blue.shade700
                                : Colors.teal.shade700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          med.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 用法・用量
                  _buildDetailSection(
                    icon: Icons.access_time_filled,
                    iconColor: const Color(0xFF0284C7),
                    title: '用法・用量・処方量',
                    content: med.dosage,
                    bgColor: const Color(0xFFF0F9FF),
                  ),
                  const SizedBox(height: 12),

                  // 効能・効果（効用）
                  _buildDetailSection(
                    icon: Icons.health_and_safety,
                    iconColor: const Color(0xFF059669),
                    title: '効能・効果 (お薬の効用)',
                    content: (med.efficacy != null && med.efficacy!.isNotEmpty)
                        ? med.efficacy!
                        : '情報が登録されていません。医師や薬剤師にご相談ください。',
                    bgColor: const Color(0xFFF0FDF4),
                  ),
                  const SizedBox(height: 12),

                  // 主な副作用
                  _buildDetailSection(
                    icon: Icons.warning_amber_rounded,
                    iconColor: const Color(0xFFD97706),
                    title: '主な副作用',
                    content: (med.sideEffects != null && med.sideEffects!.isNotEmpty)
                        ? med.sideEffects!
                        : '一般的な使用において重大な副作用は報告されていませんが、異常を感じた際は直ちに医師または薬剤師にご相談ください。',
                    bgColor: const Color(0xFFFFFBEB),
                  ),
                  const SizedBox(height: 12),

                  // 注意事項
                  _buildDetailSection(
                    icon: Icons.info_outline,
                    iconColor: const Color(0xFF475569),
                    title: '注意事項・飲み合わせ',
                    content: (med.precautions != null && med.precautions!.isNotEmpty)
                        ? med.precautions!
                        : '直射日光・高温多湿を避け、乳幼児の手の届かない場所に保管してください。指示された用法・用量を守ってください。',
                    bgColor: const Color(0xFFF8FAFC),
                  ),
                  const SizedBox(height: 24),

                  // 閉じるボタン
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A86B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('閉じる', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
    required Color bgColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: iconColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF334155),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// サンプルリセットダイアログ
  void _showResetDialog(BuildContext context, HealthProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('サンプル処方にリセット'),
        content: const Text('栗田皮フ科（リンデロン、ヒルドイド、レボセチリジン等）のサンプル処方データを復元しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              provider.resetPrescriptionsToDefault();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('サンプル処方データを復元しました')),
              );
            },
            child: const Text('復元する', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// 手動追加ダイアログ
  void _showAddPrescriptionDialog(BuildContext context, HealthProvider provider) {
    final hospitalCtrl = TextEditingController();
    final pharmacyCtrl = TextEditingController();
    final deptCtrl = TextEditingController(text: '内科');
    final costCtrl = TextEditingController();
    final medNameCtrl = TextEditingController();
    final medDosageCtrl = TextEditingController(text: '1日1回 毎食後');
    final medEfficacyCtrl = TextEditingController();
    final medSideEffectsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('処方箋の手動登録', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: hospitalCtrl,
                decoration: const InputDecoration(labelText: '医療機関・病院名 (必須)', hintText: '例: 〇〇クリニック'),
              ),
              TextField(
                controller: deptCtrl,
                decoration: const InputDecoration(labelText: '診療科', hintText: '例: 内科, 皮膚科'),
              ),
              TextField(
                controller: pharmacyCtrl,
                decoration: const InputDecoration(labelText: '調剤薬局名', hintText: '例: 〇〇薬局'),
              ),
              TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '自己負担額 (円)', hintText: '例: 1200'),
              ),
              const Divider(height: 24),
              const Text('処方薬の情報', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF00A86B))),
              TextField(
                controller: medNameCtrl,
                decoration: const InputDecoration(labelText: '薬品名 (必須)', hintText: '例: ロキソプロフェン錠60mg'),
              ),
              TextField(
                controller: medDosageCtrl,
                decoration: const InputDecoration(labelText: '用法・用量', hintText: '例: 1日3回 毎食後 1回1錠'),
              ),
              TextField(
                controller: medEfficacyCtrl,
                decoration: const InputDecoration(labelText: '効能・効果 (効用)', hintText: '例: 痛みや炎症、熱を抑える薬'),
              ),
              TextField(
                controller: medSideEffectsCtrl,
                decoration: const InputDecoration(labelText: '主な副作用', hintText: '例: 胃の不快感、眠気'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00A86B), foregroundColor: Colors.white),
            onPressed: () {
              if (hospitalCtrl.text.trim().isEmpty || medNameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('病院名と薬品名を入力してください')),
                );
                return;
              }

              final newRecord = PrescriptionRecord(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                date: DateTime.now(),
                hospitalName: hospitalCtrl.text.trim(),
                department: deptCtrl.text.trim(),
                pharmacyName: pharmacyCtrl.text.trim(),
                cost: int.tryParse(costCtrl.text.trim()),
                medications: [
                  PrescriptionMedication(
                    name: medNameCtrl.text.trim(),
                    dosage: medDosageCtrl.text.trim(),
                    category: medDosageCtrl.text.contains('塗布') || medDosageCtrl.text.contains('軟膏') ? '外用' : '内服',
                    efficacy: medEfficacyCtrl.text.trim(),
                    sideEffects: medSideEffectsCtrl.text.trim(),
                  ),
                ],
              );

              provider.addPrescription(newRecord);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('処方記録を追加しました')),
              );
            },
            child: const Text('登録'),
          ),
        ],
      ),
    );
  }
}
