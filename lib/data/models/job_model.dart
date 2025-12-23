import 'package:lojistik/domain/entities/job.dart';

class JobModel {
  final String id;
  final String title;
  final String status;
  final String? driverId;

  const JobModel({
    required this.id,
    required this.title,
    required this.status,
    this.driverId,
  });

  factory JobModel.fromMap(String id, Map<String, dynamic> map) => JobModel(
        id: id,
        title: map['title'] ?? '',
        status: map['status'] ?? 'pending',
        driverId: map['driverId'],
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'status': status,
        'driverId': driverId,
      };

  JobEntity toEntity() => JobEntity(
        id: id,
        title: title,
        status: status,
        driverId: driverId,
      );
}
