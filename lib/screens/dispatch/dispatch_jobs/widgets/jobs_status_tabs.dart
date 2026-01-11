// 📁 lib/pages/widgets/jobs_status_tabs.dart
import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_Service.dart';

class JobsStatusTabs extends StatelessWidget {
  final String selectedStatus;
  final bool isDesktop;
  final Function(String) onStatusChanged;

  const JobsStatusTabs({
    super.key,
    required this.selectedStatus,
    required this.isDesktop,
    required this.onStatusChanged,
  });

  static const Color primary = Color(0xFF1E3A5F);
  static const Color textSecondary = Color(0xFF64748B);

  Widget _buildStatusTabButton(String status, String label, IconData icon) {
    final selected = selectedStatus == status;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onStatusChanged(status),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isDesktop
          ? Row(
        children: [
          Expanded(
            child: _buildStatusTabButton(
              FirestoreService.statusPending,
              "Bekleyen",
              Icons.pending_outlined,
            ),
          ),
          Expanded(
            child: _buildStatusTabButton(
              FirestoreService.statusRejected,
              "Reddedilen",
              Icons.cancel_outlined,
            ),
          ),
          Expanded(
            child: _buildStatusTabButton(
              FirestoreService.statusApproved,
              "Yolda",
              Icons.local_shipping_outlined,
            ),
          ),
          Expanded(
            child: _buildStatusTabButton(
              FirestoreService.statusCompleted,
              "Tamamlanan",
              Icons.check_circle,
            ),
          ),
        ],
      )
          : Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatusTabButton(
                  FirestoreService.statusPending,
                  "Bekleyen",
                  Icons.pending_outlined,
                ),
              ),
              Expanded(
                child: _buildStatusTabButton(
                  FirestoreService.statusRejected,
                  "Reddedilen",
                  Icons.cancel_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _buildStatusTabButton(
                  FirestoreService.statusApproved,
                  "Yolda",
                  Icons.local_shipping_outlined,
                ),
              ),
              Expanded(
                child: _buildStatusTabButton(
                  FirestoreService.statusCompleted,
                  "Tamamlanan",
                  Icons.check_circle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}