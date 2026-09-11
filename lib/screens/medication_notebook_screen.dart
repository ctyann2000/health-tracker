import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/health_provider.dart';
import '../models/prescription_record.dart';
import '../models/health_record.dart';
import '../services/prescription_qr_service.dart';
import '../services/gemini_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/web_camera_cleaner.dart';

/// 本格処方・お薬手帳画面
class MedicationNotebookScreen extends StatefulWidget {
  const MedicationNotebookScreen({super.key});

  @override
  State<MedicationNotebookScreen> createState() => _MedicationNotebookScreenState();
}

class _MedicationNotebookScreenState extends State<MedicationNotebookScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final PrescriptionQrService _qrService = PrescriptionQrService();

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
            icon: const Icon(Icons.qr_code_scanner, color: Color(0xFF00A86B)),
            tooltip: '処方QRコードをスキャン',
            onPressed: () {
              _openQrScanner(context, healthProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Color(0xFF00A86B)),
            tooltip: '処方箋写真をAI解析',
            onPressed: () {
              _pickImageAndScanQr(context, healthProvider, source: ImageSource.camera);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFF00A86B)),
            tooltip: '処方箋を手動追加',
            onPressed: () {
              _showAddPrescriptionDialog(context, healthProvider);
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            tooltip: 'サンプル処方データにリセット',
            onPressed: () {
              _showResetDialog(context, healthProvider);
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
                ? _buildEmptyState(context, healthProvider)
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
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10, right: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 手動追加マーク (+)
            FloatingActionButton(
              heroTag: 'fab_manual_prescription',
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF00A86B),
              elevation: 5,
              shape: const CircleBorder(),
              tooltip: '処方箋を手動追加',
              onPressed: () {
                _showAddPrescriptionDialog(context, healthProvider);
              },
              child: const Icon(Icons.add, size: 28),
            ),
            const SizedBox(height: 12),
            // QRコードマーク
            FloatingActionButton(
              heroTag: 'fab_qr_prescription',
              backgroundColor: const Color(0xFF00A86B),
              foregroundColor: Colors.white,
              elevation: 6,
              shape: const CircleBorder(),
              tooltip: '処方QRコードをスキャン',
              onPressed: () {
                _openQrScanner(context, healthProvider);
              },
              child: const Icon(Icons.qr_code_scanner, size: 28),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, HealthProvider healthProvider) {
    return Center(
      child: SingleChildScrollView(
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
              '処方箋やお薬手帳のQRコードを読み取るか、\n手動またはチャットから登録できます。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black45, height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A86B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.qr_code_scanner, size: 20),
              label: const Text('処方QRコードを読み取る', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => _openQrScanner(context, healthProvider),
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

  /// 処方QRコードスキャナー（全画面）を開く
  void _openQrScanner(BuildContext context, HealthProvider healthProvider) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (scannerCtx) => _QrScannerScreen(
          healthProvider: healthProvider,
        ),
      ),
    );
  }

  /// 端末のカメラ撮影またはアルバムから画像を選択して処方QR・処方箋を解析
  Future<void> _pickImageAndScanQr(
    BuildContext context,
    HealthProvider healthProvider, {
    ImageSource source = ImageSource.camera,
  }) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (image == null) return;

    if (!context.mounted) return;

    bool isProgressShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF00A86B)),
                SizedBox(height: 16),
                Text('処方写真・QRコードをAI解析中...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                SizedBox(height: 6),
                Text('薬品名・用法用量・医療機関を自動認識しています', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => isProgressShowing = false);

    void hideProgress() {
      if (isProgressShowing && context.mounted) {
        Navigator.pop(context);
        isProgressShowing = false;
      }
    }

    try {
      // 1. 静止画からQRコード（複数・分割QR対応）の検出を試みる
      String? qrText = await _qrService.scanQrFromImagePath(image.path);

      // 2. QRコードが生テキストで取得できた場合はそれをパース
      if (qrText != null && qrText.trim().isNotEmpty) {
        hideProgress();
        if (context.mounted) {
          _processQrText(context, healthProvider, qrText);
        }
        return;
      }

      // 3. QRコードが画像から検出できなかった場合、画像そのものをGeminiマルチモーダルAIに送信して文字認識（OCR）
      final bytes = await image.readAsBytes();
      final geminiService = GeminiService();
      final result = await geminiService.extractHealthDataFromImage(
        bytes,
        image.mimeType ?? 'image/jpeg',
        extraInput: '処方箋・調剤明細書・お薬手帳のQRコード写真です。薬品名（ミグシス、エペリゾン、ロキソプロフェン等）、用法用量、病院名、薬局名、効能・副作用を確実に抽出してprescriptionフィールドに格納してください。',
      );

      hideProgress();

      if (result['prescription'] != null && result['prescription'] is Map) {
        final presMap = Map<String, dynamic>.from(result['prescription']);
        final record = PrescriptionRecord.fromJson(presMap);
        if (context.mounted && record.medications.isNotEmpty) {
          _showParsedPrescriptionConfirmDialog(context, healthProvider, record);
          return;
        }
      }

      // もしprescriptionが空でもmedicationsリストが抽出されていればPrescriptionRecordに変換
      final medsList = (result['medications'] as List?) ?? [];
      if (medsList.isNotEmpty) {
        final meds = medsList.map((m) {
          if (m is Map) {
            return PrescriptionMedication(
              name: m['name']?.toString() ?? '処方薬',
              dosage: m['dosage']?.toString() ?? '指示通り服用',
              category: '内服',
            );
          }
          return PrescriptionMedication(name: m.toString(), dosage: '指示通り服用');
        }).toList();
        final record = PrescriptionRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          date: DateTime.now(),
          hospitalName: '処方医療機関',
          medications: meds,
        );
        if (context.mounted) {
          _showParsedPrescriptionConfirmDialog(context, healthProvider, record);
          return;
        }
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('写真から処方情報を検出できませんでした。文字やQRコードがはっきり写るように撮影してください。'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      hideProgress();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('処方写真の解析に失敗しました: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// QRコードテキストをローカル最優先／AIフォールバックで解析し、確認ダイアログを表示
  Future<void> _processQrText(
    BuildContext context,
    HealthProvider healthProvider,
    String qrText,
  ) async {
    // 1. まず内蔵JAHISローカルパーサーで解析（所要時間0.001秒）
    final localRecord = PrescriptionQrService.parseLocalJahisOrText(qrText);
    final hasValidMeds = localRecord.medications.any(
      (m) => m.name.isNotEmpty && m.name != '処方薬',
    );

    // 処方箋QR（JAHIS規格）等で薬品名が取得できた場合は、待機時間0秒で即座に確認ダイアログを表示！
    if (hasValidMeds) {
      if (context.mounted) {
        _showParsedPrescriptionConfirmDialog(context, healthProvider, localRecord);
      }
      return;
    }

    // 2. ローカル解析で薬品名が不十分な場合のみ、AI解析ローディングを表示してGeminiを呼ぶ
    if (!context.mounted) return;

    bool isProgressShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF00A86B)),
                SizedBox(height: 16),
                Text('処方内容をAI解析中...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 8),
                Text('医療機関・薬品名・用法・効能・副作用を整理しています', style: TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => isProgressShowing = false);

    void hideProgress() {
      if (isProgressShowing && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isProgressShowing = false;
      }
    }

    try {
      final record = await _qrService.parsePrescriptionText(qrText);
      hideProgress();
      if (context.mounted) {
        _showParsedPrescriptionConfirmDialog(context, healthProvider, record);
      }
    } catch (e) {
      hideProgress();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('処方QRコードの解析に失敗しました: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// 読み取り結果の確認・編集プレビューダイアログ
  void _showParsedPrescriptionConfirmDialog(
    BuildContext context,
    HealthProvider healthProvider,
    PrescriptionRecord record,
  ) {
    bool addToTodayMeds = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          final dateStr = DateFormat('yyyy年M月d日').format(record.date);

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A86B).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline, color: Color(0xFF00A86B), size: 24),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    '処方QRの読取結果',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '以下の処方内容がお薬手帳に登録されます。内容をご確認ください。',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 14),

                    // 基本情報ヘッダ
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black.withOpacity(0.06)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_hospital, size: 16, color: Color(0xFF00A86B)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  record.hospitalName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          if (record.department != null && record.department!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text('診療科: ${record.department}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          ],
                          if (record.pharmacyName != null && record.pharmacyName!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.storefront, size: 15, color: Colors.blueGrey),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text('薬局: ${record.pharmacyName}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text('処方日: $dateStr', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),
                    Text(
                      '処方薬リスト (${record.medications.length}件)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 8),

                    // 薬品リスト
                    ...record.medications.map((med) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF00A86B).withOpacity(0.25)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (med.category == '外用' ? Colors.teal : const Color(0xFF00A86B)).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    med.category ?? '内服',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: med.category == '外用' ? Colors.teal : const Color(0xFF00A86B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    med.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('用法: ${med.dosage}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            if (med.efficacy != null && med.efficacy!.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text('効能: ${med.efficacy}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                            ],
                            if (med.sideEffects != null && med.sideEffects!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text('副作用: ${med.sideEffects}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                            ],
                          ],
                        ),
                      );
                    }),

                    const Divider(height: 24),

                    // 今日の服薬記録にも連動追加するチェックボックス
                    InkWell(
                      onTap: () {
                        setState(() {
                          addToTodayMeds = !addToTodayMeds;
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Checkbox(
                              value: addToTodayMeds,
                              activeColor: const Color(0xFF00A86B),
                              onChanged: (val) {
                                setState(() {
                                  addToTodayMeds = val ?? true;
                                });
                              },
                            ),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '今日の服薬記録（ホーム）にも追加する',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '本日の健康記録にお薬データが自動反映されます',
                                    style: TextStyle(fontSize: 11, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('キャンセル', style: TextStyle(color: Colors.black54)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A86B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('お薬手帳に登録', style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () {
                  // お薬手帳に追加
                  healthProvider.addPrescription(record);

                  // 今日の服薬記録にも反映
                  if (addToTodayMeds && record.medications.isNotEmpty) {
                    final today = DateTime.now();
                    final todayMeds = record.medications.map((m) {
                      return Medication(name: m.name, time: '処方');
                    }).toList();
                    healthProvider.addRecord(
                      HealthRecord(
                        date: today,
                        medications: todayMeds,
                      ),
                    );
                  }

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('「${record.hospitalName}」の処方データをお薬手帳に登録しました！'),
                      backgroundColor: const Color(0xFF00A86B),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 処方QRコード・処方箋スキャナー（1画面完結型・カメラ完全解放対応）
class _QrScannerScreen extends StatefulWidget {
  final HealthProvider healthProvider;

  const _QrScannerScreen({
    required this.healthProvider,
  });

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  MobileScannerController? _controller;
  final Set<String> _scannedQrs = {};
  final PrescriptionQrService _qrService = PrescriptionQrService();

  bool _isParsing = false;
  PrescriptionRecord? _scannedRecord;
  bool _addToTodayMeds = true;
  Timer? _autoFinishTimer;
  String _debugStatus = 'カメラ起動中...';
  final List<String> _debugLogs = [];

  void _addLog(String msg) {
    final timeStr = DateFormat('HH:mm:ss').format(DateTime.now());
    _debugLogs.insert(0, '[$timeStr] $msg');
    if (_debugLogs.length > 8) {
      _debugLogs.removeLast();
    }
    // コンソールにも出力
    debugPrint('[QrScanner] $msg');
  }

  @override
  void initState() {
    super.initState();
    _addLog('スキャナー画面初期化');
    _startScanner();
  }

  void _startScanner() {
    _debugStatus = 'カメラ準備完了・QR認識待機中';
    _addLog('カメラ起動（モバイル/Web両対応）');
    _controller = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
      returnImage: false,
    );
  }

  Future<void> _stopScanner() async {
    _autoFinishTimer?.cancel();
    final ctrl = _controller;
    // 1. 即座にコントローラ参照をnullにしてUIツリーからMobileScannerをアンマウント
    _controller = null;

    // 2. Web環境においてDOM上の<video>要素 & WebRTCメディアストリームを先行物理停止
    WebCameraCleaner.forceCleanup();
    _addLog('カメラDOM物理停止を実行');

    if (ctrl != null) {
      try {
        // Webブラウザ環境で stop() が Future を完了させずハングするのを防止（150msタイムアウト保護）
        await ctrl.stop().timeout(
          const Duration(milliseconds: 150),
          onTimeout: () => null,
        );
      } catch (_) {}
      try {
        ctrl.dispose();
      } catch (_) {}
    }

    // 3. 念押しで再度クリーンアップ
    WebCameraCleaner.forceCleanup();
  }

  @override
  void dispose() {
    _autoFinishTimer?.cancel();
    _stopScanner();
    super.dispose();
  }

  /// QRコードのスキャン完了処理（カメラを完全に破棄してその場で結果カードを表示）
  Future<void> _finishScanning() async {
    if (_scannedQrs.isEmpty || _isParsing) return;
    _autoFinishTimer?.cancel();

    _addLog('QR確定処理開始（検知: ${_scannedQrs.length}件）');
    setState(() {
      _isParsing = true;
      _debugStatus = 'QRコード検知完了（${_scannedQrs.length}件）。カメラ停止中...';
    });

    // カメラストリームを完全停止・破棄し、Webのビデオ要素が画面に残るのを完全防止
    await _stopScanner();
    if (mounted) {
      setState(() {
        _debugStatus = '処方データを解析・展開中...';
      });
    }

    final combined = _scannedQrs.join('\n');
    try {
      _addLog('処方テキスト解析開始 (${combined.length}文字)');
      // 4秒タイムアウト保護：AIや正規表現が遅い場合も確実にローカルパーサーで展開して進行
      final record = await _qrService.parsePrescriptionText(combined).timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          _addLog('タイムアウト検知：内蔵パーサーで即時フォールバック');
          return PrescriptionQrService.parseLocalJahisOrText(combined);
        },
      );
      if (mounted) {
        setState(() {
          _isParsing = false;
          _scannedRecord = record;
          _debugStatus = '処方解析完了（薬品数: ${record.medications.length}件）';
        });
        _addLog('解析成功: ${record.hospitalName} / 薬品${record.medications.length}件');
      }
    } catch (e) {
      if (mounted) {
        _addLog('解析エラー: $e');
        setState(() {
          _isParsing = false;
          _debugStatus = '解析失敗: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('解析に失敗しました: $e'), backgroundColor: Colors.redAccent),
        );
        _restartScanning();
      }
    }
  }

  /// 写真撮影またはアルバム選択からの処方解析
  Future<void> _pickImageAndParse(ImageSource source) async {
    _addLog('画像選択開始（ソース: ${source == ImageSource.camera ? "カメラ撮影" : "アルバム"}）');
    await _stopScanner();
    if (mounted) {
      setState(() {});
    }

    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );

    if (image == null) {
      _addLog('画像選択がキャンセルされました');
      _restartScanning();
      return;
    }

    if (!mounted) return;

    _addLog('画像取得完了。処方解析中...');
    setState(() {
      _isParsing = true;
      _debugStatus = '写真から処方箋・QRコードをAI解析中...';
    });

    try {
      // 1. 静止画からQRコードの抽出を試みる
      _addLog('画像内のQRコードを走査中...');
      String? qrText = await _qrService.scanQrFromImagePath(image.path);
      if (qrText != null && qrText.trim().isNotEmpty) {
        _addLog('画像内QRコード検出成功 (${qrText.length}文字)');
        final record = await _qrService.parsePrescriptionText(qrText);
        if (mounted) {
          setState(() {
            _isParsing = false;
            _scannedRecord = record;
            _debugStatus = '処方解析完了（薬品数: ${record.medications.length}件）';
          });
          _addLog('処方解析完了: ${record.hospitalName}');
          return;
        }
      }

      // 2. QRコードが読めなくても写真全体をGemini画像認識でOCR文字解析
      final bytes = await image.readAsBytes();
      final geminiService = GeminiService();
      final result = await geminiService.extractHealthDataFromImage(
        bytes,
        image.mimeType ?? 'image/jpeg',
        extraInput: '処方箋・調剤明細書・お薬手帳のQRコード写真です。薬品名（ミグシス、エペリゾン、ロキソプロフェン等）、用法用量、病院名、薬局名、効能・副作用を確実に抽出してprescriptionフィールドに格納してください。',
      );

      if (result['prescription'] != null && result['prescription'] is Map) {
        final presMap = Map<String, dynamic>.from(result['prescription']);
        final record = PrescriptionRecord.fromJson(presMap);
        if (mounted && record.medications.isNotEmpty) {
          setState(() {
            _isParsing = false;
            _scannedRecord = record;
          });
          return;
        }
      }

      // medications リストから復元
      final medsList = (result['medications'] as List?) ?? [];
      if (medsList.isNotEmpty) {
        final meds = medsList.map((m) {
          if (m is Map) {
            return PrescriptionMedication(
              name: m['name']?.toString() ?? '処方薬',
              dosage: m['dosage']?.toString() ?? '指示通り服用',
              category: '内服',
            );
          }
          return PrescriptionMedication(name: m.toString(), dosage: '指示通り服用');
        }).toList();

        final record = PrescriptionRecord(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          date: DateTime.now(),
          hospitalName: '処方医療機関',
          medications: meds,
        );
        if (mounted) {
          setState(() {
            _isParsing = false;
            _scannedRecord = record;
          });
          return;
        }
      }

      if (mounted) {
        setState(() {
          _isParsing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('写真から処方情報を検出できませんでした。文字やQRコードがはっきり写るように撮影してください。'),
            backgroundColor: Colors.redAccent,
          ),
        );
        _restartScanning();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isParsing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('処方写真の解析に失敗しました: $e'), backgroundColor: Colors.redAccent),
        );
        _restartScanning();
      }
    }
  }

  void _restartScanning() {
    _scannedQrs.clear();
    _scannedRecord = null;
    _isParsing = false;
    _startScanner();
    setState(() {});
  }

  void _commitAndClose() {
    if (_scannedRecord == null) return;
    final record = _scannedRecord!;

    // お薬手帳に登録
    widget.healthProvider.addPrescription(record);

    // 今日の服薬記録にも反映
    if (_addToTodayMeds && record.medications.isNotEmpty) {
      final today = DateTime.now();
      final todayMeds = record.medications.map((m) {
        return Medication(name: m.name, time: '処方');
      }).toList();
      widget.healthProvider.addRecord(
        HealthRecord(
          date: today,
          medications: todayMeds,
        ),
      );
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${record.hospitalName}」の処方データをお薬手帳に登録しました！'),
        backgroundColor: const Color(0xFF00A86B),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          _scannedRecord != null ? '処方データの確認' : '処方QRコード読取',
          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          tooltip: '閉じる',
          onPressed: () async {
            _addLog('ユーザーが閉じるをタップ');
            await _stopScanner();
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          if (_scannedRecord == null && _controller != null) ...[
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
              tooltip: 'カメラ切り替え',
              onPressed: () => _controller?.switchCamera(),
            ),
            IconButton(
              icon: const Icon(Icons.flash_on, color: Colors.white),
              tooltip: 'ライト切替',
              onPressed: () => _controller?.toggleTorch(),
            ),
          ],
        ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    // 1. 結果確認・登録画面（カメラ完全非表示で安全表示）
    if (_scannedRecord != null) {
      return _buildResultView(context, _scannedRecord!);
    }

    // 2. 解析中ローディング表示（DOMビデオ完全除去済みの安全画面）
    if (_isParsing) {
      return Container(
        color: const Color(0xFF0F172A),
        width: double.infinity,
        height: double.infinity,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              color: Colors.white,
              elevation: 8,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        color: Color(0xFF00A86B),
                        strokeWidth: 3.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '処方内容を展開中...',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _debugStatus,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 24),
                    // 万が一進行しない場合のフォールバック安全ボタン
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Colors.black26),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('戻って撮影や手動入力に切替', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        _addLog('ローディングから手動復帰');
                        _restartScanning();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // 3. カメラプレビュー＆スキャナーUI
    final screenSize = MediaQuery.of(context).size;
    final targetSize = (screenSize.width * 0.65).clamp(210.0, 260.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        // カメラプレビュー（_controller が存在し、かつ非パース時のみビルド）
        if (_controller != null && !_isParsing && _scannedRecord == null)
          MobileScanner(
            key: const ValueKey('active_scanner'),
            controller: _controller!,
            onDetect: (BarcodeCapture capture) {
              if (_isParsing || _scannedRecord != null) return;
              bool hasNew = false;
              for (final barcode in capture.barcodes) {
                final raw = barcode.rawValue;
                if (raw != null && raw.trim().isNotEmpty) {
                  final trimmed = raw.trim();
                  if (!_scannedQrs.contains(trimmed)) {
                    _scannedQrs.add(trimmed);
                    hasNew = true;
                    final preview = trimmed.length > 25 ? '${trimmed.substring(0, 25)}...' : trimmed;
                    _addLog('QR検知[#${_scannedQrs.length}]: $preview');
                  }
                }
              }
              if (hasNew) {
                _debugStatus = 'QRコード検知: ${_scannedQrs.length}件（1秒後に自動解析）';
                setState(() {});
                // 1個検知されたらタイマーをリセットし1秒後に自動完了
                _autoFinishTimer?.cancel();
                _autoFinishTimer = Timer(const Duration(milliseconds: 1000), () {
                  if (mounted && !_isParsing && _scannedRecord == null && _scannedQrs.isNotEmpty) {
                    _finishScanning();
                  }
                });
              }
            },
            errorBuilder: (context, error) {
              _addLog('カメラエラー: ${error.errorDetails?.message ?? error.toString()}');
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.videocam_off, size: 56, color: Colors.white54),
                      const SizedBox(height: 16),
                      Text(
                        'カメラがご利用いただけません\n${error.errorDetails?.message ?? error.toString()}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A86B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('写真を撮影して解析', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () => _pickImageAndParse(ImageSource.camera),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
        else
          Container(color: Colors.black),

        // 上部ガイドバー
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.85),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _scannedQrs.isNotEmpty ? const Color(0xFF00E676) : const Color(0xFF00A86B),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _scannedQrs.isNotEmpty ? Icons.check_circle : Icons.center_focus_strong,
                      color: const Color(0xFF00E676),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _scannedQrs.isEmpty
                            ? '💡 QRコード1個にカメラをグッと近づけてください'
                            : '✓ ${_scannedQrs.length}個 検知完了！',
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _scannedQrs.isEmpty
                      ? '※ 離れるとQRコードが小さすぎて認識できません（枠いっぱいに拡大）'
                      : '続けて他のQRコードを近づけるか、下のボタンで確定してください',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // リアルタイムステータスバッジ
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _scannedQrs.isNotEmpty ? const Color(0xFF00E676) : Colors.amberAccent,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _debugStatus,
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_debugLogs.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _debugLogs.take(3).map((log) {
                        return Text(
                          log,
                          style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'monospace'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // スキャンターゲットフレーム（1つのQRコードを大きく写す正方形枠）
        Center(
          child: Container(
            width: targetSize,
            height: targetSize,
            decoration: BoxDecoration(
              border: Border.all(
                color: _scannedQrs.isNotEmpty ? const Color(0xFF00E676) : Colors.white,
                width: _scannedQrs.isNotEmpty ? 4.0 : 2.5,
              ),
              borderRadius: BorderRadius.circular(20),
              color: _scannedQrs.isNotEmpty ? const Color(0xFF00E676).withOpacity(0.12) : Colors.transparent,
            ),
            child: Stack(
              children: [
                if (_scannedQrs.isEmpty)
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'QRコードを1つ\n枠いっぱいに近づける',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
                        ),
                      ),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check, color: Color(0xFF0F172A), size: 20),
                          const SizedBox(width: 6),
                          Text(
                            '${_scannedQrs.length}件 認識！',
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 下部操作パネル
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // QRが検知されたら即座にタップして進める大ボタン
              if (_scannedQrs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 8,
                      ),
                      icon: const Icon(Icons.check_circle, size: 22, color: Color(0xFF0F172A)),
                      label: Text(
                        'このデータで今すぐ登録に進む (${_scannedQrs.length}件)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      onPressed: _finishScanning,
                    ),
                  ),
                ),

              // 写真撮影で一発解析ボタン（最も確実・超大型メインボタン）
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                  ),
                  icon: const Icon(Icons.camera_alt, color: Color(0xFF00A86B), size: 22),
                  label: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '📸 写真を撮影して一発解析（推奨）',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        'QRコードが小さくても処方箋の文字を直接AIが読み取ります',
                        style: TextStyle(color: Colors.black54, fontSize: 10),
                      ),
                    ],
                  ),
                  onPressed: () => _pickImageAndParse(ImageSource.camera),
                ),
              ),

              const SizedBox(height: 8),

              // アルバムから選択
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.photo_library, size: 18),
                label: const Text('アルバムから写真を選択', style: TextStyle(fontSize: 13)),
                onPressed: () => _pickImageAndParse(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// スキャン完了後に表示する結果確認・登録カード
  Widget _buildResultView(BuildContext context, PrescriptionRecord record) {
    final dateStr = DateFormat('yyyy年M月d日').format(record.date);

    return Container(
      color: const Color(0xFFF8FAFC),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ヘッダー成功バナー
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00A86B).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00A86B).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Color(0xFF00A86B), size: 26),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '処方情報の解析に成功しました！',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF00A86B)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '以下の内容でお薬手帳に登録します',
                                  style: TextStyle(fontSize: 12, color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 基本情報カード
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.local_hospital, color: Color(0xFF00A86B), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  record.hospitalName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                          if (record.department != null && record.department!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('診療科: ${record.department}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                          ],
                          if (record.pharmacyName != null && record.pharmacyName!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.storefront, size: 16, color: Colors.blueGrey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('薬局: ${record.pharmacyName}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text('処方日: $dateStr', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 処方薬一覧
                    Text(
                      '処方薬リスト (${record.medications.length}件)',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 8),

                    ...record.medications.map((med) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00A86B).withOpacity(0.2)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (med.category == '外用' ? Colors.teal : const Color(0xFF00A86B)).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    med.category ?? '内服',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: med.category == '外用' ? Colors.teal : const Color(0xFF00A86B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    med.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('用法: ${med.dosage}', style: const TextStyle(fontSize: 13, color: Colors.black87)),
                            if (med.efficacy != null && med.efficacy!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('効能: ${med.efficacy}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                            ],
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 10),

                    // 今日の服薬記録にも反映チェックボックス
                    CheckboxListTile(
                      value: _addToTodayMeds,
                      onChanged: (val) {
                        setState(() {
                          _addToTodayMeds = val ?? true;
                        });
                      },
                      title: const Text('今日の服薬記録にも同時に反映する', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: const Text('ホーム画面の今日の服薬リストに登録されます', style: TextStyle(fontSize: 11, color: Colors.black54)),
                      activeColor: const Color(0xFF00A86B),
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
            ),

            // 下部決定バー
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A86B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                      ),
                      icon: const Icon(Icons.check, size: 22),
                      label: const Text(
                        'お薬手帳に登録する',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: _commitAndClose,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.black54,
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('もう一度読み取る', style: TextStyle(fontSize: 13)),
                    onPressed: _restartScanning,
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
