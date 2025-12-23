import 'package:lojistik/domain/entities/vehicle.dart';

class VehicleModel {
  final String id;
  final String plate;
  final String type;
  final bool isActive;

  const VehicleModel({
    required this.id,
    required this.plate,
    required this.type,
    required this.isActive,
  });

  factory VehicleModel.fromMap(String id, Map<String, dynamic> map) => VehicleModel(
        id: id,
        plate: map['plate'] ?? '',
        type: map['type'] ?? '',
        isActive: map['isActive'] ?? true,
      );

  Map<String, dynamic> toMap() => {
        'plate': plate,
        'type': type,
        'isActive': isActive,
      };

  VehicleEntity toEntity() => VehicleEntity(
        id: id,
        plate: plate,
        type: type,
        isActive: isActive,
      );
}
