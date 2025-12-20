import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'job_service.dart';
import 'job_documents.dart';


class JobDetailPanel extends StatefulWidget {
  final Map job;
  final String jobId;
  final String Function(String?) userName;
  final String Function(String?) vehiclePlate;
  final VoidCallback onApprove;
  final void Function(String reason) onReject;


  const JobDetailPanel({
    super.key,
    required this.job,
    required this.jobId,
    required this.userName,
    required this.vehiclePlate,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<JobDetailPanel> createState() => _JobDetailPanelState();
}

class _JobDetailPanelState extends State<JobDetailPanel> {
  final _reasonController = TextEditingController();

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
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Color(0xFFDC2626)),
            SizedBox(width: 12),
            Text("İşi Reddet"),
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
            onPressed: () {
              if (_reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Lütfen red nedeni belirtin"),
                  ),
                );
                return;
              }
              widget.onReject(_reasonController.text.trim());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text("Reddet"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final cargo = widget.job["cargo"] as Map<String, dynamic>?;
    final route = widget.job["route"] as Map<String, dynamic>?;
    final timestamps = widget.job["timestamps"] as Map<String, dynamic>?;

    return Drawer(
      width: 480,
      backgroundColor: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 22,
              vertical: isMobile ? 12 : 18,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1E3A5F),
            ),
            child: Center(
              child: Row(
                children: [
                  Icon(
                    Icons.description,
                    size: isMobile ? 16 : 20,
                    color: Colors.white.withOpacity(.9),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "İş Detayları",
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      size: isMobile ? 18 : 22,
                      color: Colors.white.withOpacity(.9),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Badge
                  _buildStatusBadge(widget.job["status"]),
                  const SizedBox(height: 20),

                  // Reference Number
                  _buildMinimalCard(
                    "Referans Numarası",
                    widget.job["referenceNo"],
                    Icons.tag,
                  ),
                  const SizedBox(height: 12),

                  // Driver Info
                  _buildMinimalCard(
                    "Şoför",
                    widget.userName(widget.job["driverId"]),
                    Icons.person_outline,
                  ),
                  const SizedBox(height: 12),

                  // Vehicle Info
                  _buildMinimalCard(
                    "Araç Plakası",
                    widget.vehiclePlate(widget.job["vehicleId"]),
                    Icons.car_rental_outlined,
                  ),
                  const SizedBox(height: 12),

                  // Cargo Type
                  _buildMinimalCard(
                    "Yük Tipi",
                    cargo?["type"],
                    Icons.inventory_2_outlined,
                  ),
                  const SizedBox(height: 12),

                  // Cargo Description
                  if (cargo?["description"] != null &&
                      cargo!["description"].toString().isNotEmpty)
                    _buildMinimalCard(
                      "Yük Açıklaması",
                      cargo["description"],
                      Icons.description_outlined,
                    ),
                  if (cargo?["description"] != null &&
                      cargo!["description"].toString().isNotEmpty)
                    const SizedBox(height: 12),

                  // Weight
                  _buildMinimalCard(
                    "Ağırlık",
                    "${cargo?["weightKg"] ?? 0} kg",
                    Icons.scale_outlined,
                  ),
                  const SizedBox(height: 12),

                  // Load Port
                  _buildMinimalCard(
                    "Yükleme Noktası",
                    route?["loadPort"],
                    Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 12),

                  // Unload Port
                  _buildMinimalCard(
                    "Varış Noktası",
                    route?["unloadPort"],
                    Icons.flag_outlined,
                  ),
                  const SizedBox(height: 12),

                  // Dispatcher
                  _buildMinimalCard(
                    "Dispatch",
                    widget.userName(widget.job["createdBy"]),
                    Icons.support_agent_outlined,
                  ),
                  const SizedBox(height: 12),

                  // Created At
                  if (timestamps?["createdAt"] != null)
                    _buildMinimalCard(
                      "Oluşturulma Tarihi",
                      _formatTimestamp(timestamps!["createdAt"]),
                      Icons.calendar_today_outlined,
                    ),
                  if (timestamps?["createdAt"] != null)
                    const SizedBox(height: 12),

                  // Reviewed At
                  if (timestamps?["reviewedAt"] != null)
                    _buildMinimalCard(
                      "İncelenme Tarihi",
                      _formatTimestamp(timestamps!["reviewedAt"]),
                      Icons.check_circle_outline,
                    ),
                  if (timestamps?["reviewedAt"] != null)
                    const SizedBox(height: 12),

                  // Rejection Reason
                  if (widget.job["status"] == "rejected" &&
                      widget.job["rejectionReason"] != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Color(0xFFDC2626),
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Red Nedeni",
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.job["rejectionReason"] ?? "",
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF991B1B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.job["status"] == "rejected" &&
                      widget.job["rejectionReason"] != null)
                    const SizedBox(height: 24),

                  // Logs Section
                  const Divider(height: 32),
                  _buildLogsSection(),
                  const SizedBox(height: 24),

                  // Action Buttons
                  if (widget.job["status"] == "pending")
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _showRejectDialog,
                            icon:
                            const Icon(Icons.cancel_outlined, size: 18),
                            label: const Text("Reddet"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFDC2626),
                              side: const BorderSide(
                                color: Color(0xFFDC2626),
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: widget.onApprove,
                            icon: const Icon(Icons.check_circle_outline,
                                size: 18),
                            label: const Text("Onayla"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case "pending":
        bgColor = const Color(0xFFFEF3C7);
        textColor = const Color(0xFF92400E);
        label = "Onay Bekliyor";
        icon = Icons.pending_outlined;
        break;
      case "approved":
        bgColor = const Color(0xFFDBEAFE);
        textColor = const Color(0xFF1E40AF);
        label = "Onaylandı";
        icon = Icons.check_circle_outline;
        break;
      case "completed":
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF065F46);
        label = "Tamamlandı";
        icon = Icons.done_all_outlined;
        break;
      case "rejected":
        bgColor = const Color(0xFFFEE2E2);
        textColor = const Color(0xFF991B1B);
        label = "Reddedildi";
        icon = Icons.cancel_outlined;
        break;
      default:
        bgColor = const Color(0xFFF3F4F6);
        textColor = const Color(0xFF374151);
        label = "Bilinmiyor";
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMinimalCard(String title, dynamic value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF2F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 24,
              color: const Color(0xFF4A5568),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF718096),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value?.toString() ?? "-",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.history, size: 20, color: Color(0xFF4A5568)),
            SizedBox(width: 8),
            Text(
              "İşlem Geçmişi",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D3748),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: JobService.getJobLogs(widget.jobId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final logs = snapshot.data!.docs;

            if (logs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    "Henüz işlem kaydı yok",
                    style: TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 14,
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
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

  Widget _buildLogItem(Map<String, dynamic> log) {
    final action = log["action"] as String?;
    final note = log["note"] as String?;
    final performedBy = log["performedBy"] as String?;
    final performedAt = log["performedAt"] as Timestamp?;

    IconData icon;
    Color iconColor;
    String actionLabel;

    switch (action) {
      case "created":
        icon = Icons.add_circle_outline;
        iconColor = const Color(0xFF3B82F6);
        actionLabel = "İş oluşturuldu";
        break;
      case "approved":
        icon = Icons.check_circle_outline;
        iconColor = const Color(0xFF059669);
        actionLabel = "Onaylandı";
        break;
      case "completed":
        icon = Icons.done_all_outlined;
        iconColor = const Color(0xFF059669);
        actionLabel = "Tamamlandı";
        break;
      default:
        icon = Icons.info_outline;
        iconColor = const Color(0xFF64748B);
        actionLabel = action ?? "Bilinmiyor";
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actionLabel,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.userName(performedBy),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                if (performedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatTimestamp(performedAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      note,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}