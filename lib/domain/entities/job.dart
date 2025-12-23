class JobEntity {
  final String id;
  final String title;
  final String status;
  final String? driverId;

  const JobEntity({
    required this.id,
    required this.title,
    required this.status,
    this.driverId,
  });
}
