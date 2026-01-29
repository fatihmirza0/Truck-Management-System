import 'package:lojistik/models/job_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  final now = DateTime.now();
  final timestamp = Timestamp.fromDate(now);

  final firestoreData = {
    'referenceNo': 'JOB-12345',
    'driverId': 'driver_uid',
    'driverName': 'Ali Yılmaz',
    'vehicleId': 'vehicle_id',
    'vehiclePlate': '34 ABC 123',
    'reviewedBy': 'manager_uid',
    'cargo': {
      'type': 'Konteyner',
      'description': 'Elektronik eşya',
      'weightKg': 1500.5,
    },
    'route': {
      'loadPort': 'İstanbul',
      'unloadPort': 'İzmir',
      'distanceKm': 450.0,
    },
    'status': 'approved',
    'rejectionReason': null,
    'createdBy': 'dispatch_uid',
    'companyId': 'company_id',
    'softDeleted': false,
    'documents': ['doc1.pdf', 'doc2.jpg'],
    'timestamps': {
      'createdAt': timestamp,
      'reviewedAt': timestamp,
    },
    'revenue': 5000.0,
    'expenses': {
      'fuel': 1200.0,
      'toll': 200.0,
    },
  };

  print('--- Testing Job.fromMap ---');
  final job = Job.fromMap(firestoreData, 'job_id');

  assert(job.id == 'job_id');
  assert(job.driverName == 'Ali Yılmaz');
  assert(job.vehiclePlate == '34 ABC 123');
  assert(job.cargoType == 'Konteyner');
  assert(job.loadPort == 'İstanbul');
  assert(job.distanceKm == 450.0);
  assert(job.expenses['fuel'] == 1200.0);
  print('✅ Job.fromMap successful');

  print('--- Testing Job.toMap ---');
  final mappedData = job.toMap();

  assert(mappedData['driverName'] == 'Ali Yılmaz');
  assert(mappedData['cargo']['type'] == 'Konteyner');
  assert(mappedData['route']['unloadPort'] == 'İzmir');
  assert(mappedData['route']['distanceKm'] == 450.0);
  print('✅ Job.toMap successful');

  print('--- All tests passed! ---');
}
