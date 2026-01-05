// 📁 lib/pages/widgets/jobs_page_header.dart
import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_Service.dart';

class JobsPageHeader extends StatelessWidget {
  final String selectedStatus;

  const JobsPageHeader({
    super.key,
    required this.selectedStatus,
  });

  static const Color primary = Color(0xFF1E3A5F);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

  String _getPageTitle() {
    switch (selectedStatus) {
      case FirestoreService.statusPending:
        return "Bekleyen İşler";
      case FirestoreService.statusRejected:
        return "Reddedilen İşler";
      case FirestoreService.statusApproved:
        return "Yoldaki İşler";
      case FirestoreService.statusCompleted:
        return "Tamamlanan İşler";
      default:
        return "İş Takibi";
    }
  }

  String _getPageSubtitle() {
    switch (selectedStatus) {
      case FirestoreService.statusPending:
        return "Onay bekleyen işleriniz";
      case FirestoreService.statusRejected:
        return "Şoförler tarafından reddedilen işler";
      case FirestoreService.statusApproved:
        return "Onaylanmış ve yolda olan işler";
      case FirestoreService.statusCompleted:
        return "Başarıyla tamamlanan işler";
      default:
        return "Tüm işleriniz";
    }
  }

  IconData _getPageIcon() {
    switch (selectedStatus) {
      case FirestoreService.statusPending:
        return Icons.pending_outlined;
      case FirestoreService.statusRejected:
        return Icons.cancel_outlined;
      case FirestoreService.statusApproved:
        return Icons.local_shipping_outlined;
      case FirestoreService.statusCompleted:
        return Icons.check_circle;
      default:
        return Icons.assignment_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_getPageIcon(), color: primary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getPageTitle(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getPageSubtitle(),
                style: const TextStyle(
                  fontSize: 14,
                  color: textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}