import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lojistik/config/app_theme.dart';
import 'package:lojistik/widgets/animated/animated_widgets.dart';
import 'package:lojistik/screens/dispatch/dispatch_job_detail/widgets/storage_helper.dart';
import '../job_service.dart';

class ManagerJobDetailPage extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> data;
  final String driverName;
  final String vehiclePlate;

  const ManagerJobDetailPage({
    super.key,
    required this.jobId,
    required this.data,
    required this.driverName,
    required this.vehiclePlate,
  });

  @override
  State<ManagerJobDetailPage> createState() => _ManagerJobDetailPageState();
}

class _ManagerJobDetailPageState extends State<ManagerJobDetailPage> {
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _showRejectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppTheme.errorColor),
            const SizedBox(width: 12),
            const Text("İşi Reddet"),
          ],
        ),
        content: TextField(
          controller: _reasonController,
          decoration: const InputDecoration(
            labelText: "Red Nedeni *",
            hintText: "Lütfen red sebebini yazın...",
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Lütfen red nedeni belirtin")),
                );
                return;
              }
              Navigator.pop(context);
              _handleReject(_reasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text("Reddet"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprove() async {
    setState(() => _isLoading = true);
    try {
      await JobService.approveJob(widget.jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("İş onaylandı"), backgroundColor: AppTheme.successColor),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleReject(String reason) async {
    setState(() => _isLoading = true);
    try {
      await JobService.rejectJob(widget.jobId, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("İş reddedildi"), backgroundColor: AppTheme.errorColor),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.data['status'] ?? 'pending';
    final cargo = widget.data['cargo'] as Map<String, dynamic>?;
    final route = widget.data['route'] as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "İş Detayı",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18,color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(child: _buildStatusChip(status)),
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReferenceCard(),
                const SizedBox(height: 20),
                _buildInfoGrid(cargo, route),
                const SizedBox(height: 20),
                if (status == "rejected" && widget.data['rejectionReason'] != null)
                  _buildRejectionReasonCard(widget.data['rejectionReason']),
                const SizedBox(height: 20),
                if (widget.data['documents'] != null && (widget.data['documents'] as List).isNotEmpty)
                  _buildDocumentsSection(widget.data['documents'] as List),
                const SizedBox(height: 24),
                _buildLogsSection(),
                const SizedBox(height: 100), // Spacing for bottom buttons
              ],
            ),
          ),
          if (status == "pending")
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildActionButtons(),
            ),
          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    switch (status) {
      case "pending": color = Colors.amber; label = "Bekliyor"; break;
      case "approved": color = Colors.blue; label = "Onaylandı"; break;
      case "approve": color = Colors.blue; label = "Onaylandı"; break;
      case "completed": color = Colors.green; label = "Tamamlandı"; break;
      case "rejected": color = Colors.red; label = "Reddedildi"; break;
      default: color = Colors.grey; label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildReferenceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A5F).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.tag_rounded, color: Color(0xFF1E3A5F)),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "REFERANS NUMARASI",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.data['referenceNo'] ?? "-",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(Map<String, dynamic>? cargo, Map<String, dynamic>? route) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildDetailCard("Şoför", widget.driverName, Icons.person_rounded)),
            const SizedBox(width: 16),
            Expanded(child: _buildDetailCard("Araç Plaza", widget.vehiclePlate, Icons.local_shipping_rounded)),
          ],
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          "Güzergah",
          "${route?['loadPort'] ?? '-'} \u2192 ${route?['unloadPort'] ?? '-'}",
          Icons.route_rounded,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildDetailCard("Yük Tipi", cargo?['type'] ?? "-", Icons.inventory_2_rounded)),
            const SizedBox(width: 16),
            Expanded(child: _buildDetailCard("Ağırlık", "${cargo?['weightKg'] ?? 0} kg", Icons.scale_rounded)),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: AppTheme.textTertiary, fontWeight: FontWeight.w500),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRejectionReasonCard(String reason) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_rounded, color: AppTheme.errorColor, size: 20),
              const SizedBox(width: 8),
              Text(
                "RED NEDENİ",
                style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reason,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "İşlem Geçmişi",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: JobService.getJobLogs(widget.jobId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final logs = snapshot.data!.docs;
            if (logs.isEmpty) {
              return const Text("Henüz işlem kaydı yok", style: TextStyle(color: AppTheme.textSecondary));
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final log = logs[index].data() as Map<String, dynamic>;
                return _buildLogItem(log);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildDocumentsSection(List documents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "Ekli Belgeler",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                documents.length.toString(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...documents.asMap().entries.map((entry) {
          final doc = entry.value;
          final index = entry.key;
          final docMap = doc is String
              ? {'url': doc, 'documentNo': 'Belge ${index + 1}'}
              : (doc as Map<String, dynamic>);
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ManagerDocumentItem(
              document: docMap,
              referenceNo: widget.data['referenceNo'] ?? "REF",
              index: index + 1,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final action = log['action'] as String?;
    final timestamp = log['performedAt'] as Timestamp?;
    final note = log['note'] as String?;

    IconData icon;
    Color color;

    switch (action) {
      case 'created': icon = Icons.add_circle_outline; color = Colors.blue; break;
      case 'approved': icon = Icons.check_circle_outline; color = Colors.green; break;
      case 'rejected': icon = Icons.cancel_outlined; color = Colors.red; break;
      default: icon = Icons.info_outline; color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _getActionLabel(action),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    if (timestamp != null)
                      Text(
                        _formatDate(timestamp),
                        style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                      ),
                  ],
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(note, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getActionLabel(String? action) {
    switch (action) {
      case 'created': return "İş Oluşturuldu";
      case 'approved': return "İş Onaylandı";
      case 'rejected': return "İş Reddedildi";
      case 'updated': return "İş Güncellendi";
      case 'completed': return "İş Tamamlandı";
      default: return action ?? "İşlem";
    }
  }

  String _formatDate(Timestamp ts) {
    final d = ts.toDate();
    return "${d.day}.${d.month}.${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}";
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: ScaleButton(
                onTap: _showRejectDialog,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Text(
                      "İşlemi Reddet",
                      style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ScaleButton(
                onTap: _handleApprove,
                child: Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      "İşlemi Onayla",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagerDocumentItem extends StatefulWidget {
  final Map<String, dynamic> document;
  final String referenceNo;
  final int index;

  const _ManagerDocumentItem({
    required this.document,
    required this.referenceNo,
    required this.index,
  });

  @override
  State<_ManagerDocumentItem> createState() => _ManagerDocumentItemState();
}

class _ManagerDocumentItemState extends State<_ManagerDocumentItem> {
  bool _loading = false;
  bool _downloading = false;
  String? _downloadUrl;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  String? _getUrlFromDocument() {
    final urlData = widget.document['url'];
    if (urlData is String) return urlData;
    if (urlData is Map) {
      return urlData['url'] ?? urlData['downloadUrl'] ?? urlData['path'];
    }
    return null;
  }

  Future<void> _loadUrl() async {
    final storageUrl = _getUrlFromDocument();
    if (storageUrl == null) return;

    setState(() => _loading = true);
    try {
      final url = await StorageHelper.getDownloadUrl(storageUrl);
      if (mounted) setState(() => _downloadUrl = url);
    } catch (e) {
      debugPrint("URL load error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download() async {
    if (_downloadUrl == null || _downloading) return;
    setState(() => _downloading = true);
    try {
      final fileName = '${widget.referenceNo}_${widget.index}';
      await StorageHelper.downloadFile(_downloadUrl!, fileName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Belge indirildi"), backgroundColor: AppTheme.successColor),
        );
      }
    } catch (e) {
      if (mounted && !e.toString().contains('iptal')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Hata: $e"), backgroundColor: AppTheme.errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  void _showFullScreen() {
    if (_downloadUrl == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  _downloadUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isImage = _downloadUrl?.toLowerCase().contains(RegExp(r'\.(jpg|jpeg|png|gif|webp)')) ?? false;
    final isPdf = _downloadUrl?.toLowerCase().contains('.pdf') ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isPdf ? Colors.red : Colors.blue).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf_rounded : (isImage ? Icons.image_rounded : Icons.insert_drive_file_rounded),
              color: isPdf ? Colors.red : Colors.blue,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.document['documentNo'] ?? "Belge ${widget.index}",
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                Text(
                  widget.document['documentType'] ?? (isPdf ? "PDF Belgesi" : "Görsel"),
                  style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          if (_loading)
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            if (isImage)
              IconButton(
                onPressed: _showFullScreen,
                icon: const Icon(Icons.visibility_rounded, size: 20, color: AppTheme.textSecondary),
              ),
            IconButton(
              onPressed: _downloading ? null : _download,
              icon: _downloading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_rounded, size: 20, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
