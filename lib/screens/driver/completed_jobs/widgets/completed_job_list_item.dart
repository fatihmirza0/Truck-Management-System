// 📁 lib/screens/driver/completed_jobs/widgets/completed_job_list_item.dart
import 'package:flutter/material.dart';
import '../../completed_job_detail/pages/completed_job_detail_page.dart';
import '../../../../models/job_model.dart';

class CompletedJobListItem extends StatelessWidget {
  final Job job;
  final String loadPort;
  final String unloadPort;

  const CompletedJobListItem({
    super.key,
    required this.job,
    required this.loadPort,
    required this.unloadPort,
  });

  static const Color primary = Color(0xFF1E3A5F);
  static const Color border = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    final title = job.referenceNo;
    final subtitle = "$loadPort → $unloadPort";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.check_circle_outline,
          color: primary,
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CompletedJobDetailsPage(
                job: job,
              ),
            ),
          );
        },
      ),
    );
  }
}
