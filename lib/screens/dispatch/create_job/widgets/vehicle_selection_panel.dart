import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_service.dart';
import 'package:lojistik/config/app_theme.dart';
import 'package:lojistik/widgets/animated/animated_widgets.dart';
import 'package:lojistik/models/vehicle_model.dart';

class VehicleSelectionPanel extends StatelessWidget {
  final Animation<double> animation;
  final bool isDesktop;
  final TextEditingController searchController;
  final String searchQuery;
  final String? selectedVehicleId;
  final String selectedDriverUid;
  final Function(String) onSearchChanged;
  final VoidCallback onClose;
  final Function(Vehicle) onSelectVehicle;

  const VehicleSelectionPanel({
    super.key,
    required this.animation,
    required this.isDesktop,
    required this.searchController,
    required this.searchQuery,
    required this.selectedVehicleId,
    required this.selectedDriverUid,
    required this.onSearchChanged,
    required this.onClose,
    required this.onSelectVehicle,
  });

  // Renkler AppTheme'den kullanılacak

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onTap: onClose,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) => Container(
              color: Colors.black.withOpacity(0.5 * animation.value),
            ),
          ),
        ),
        Align(
          alignment: isDesktop ? Alignment.center : Alignment.bottomCenter,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Transform.translate(
                offset:
                    Offset(0, (1 - animation.value) * (isDesktop ? 50 : 500)),
                child: Opacity(opacity: animation.value, child: child),
              );
            },
            child: Container(
              width: isDesktop ? 600 : double.infinity,
              height:
                  isDesktop ? 550 : MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: isDesktop
                    ? BorderRadius.circular(16)
                    : const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                children: [
                  _buildHeader(context),
                  Expanded(child: _buildVehicleList()),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isDesktop ? 16 : 24),
          topRight: Radius.circular(isDesktop ? 16 : 24),
        ),
        border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        children: [
          if (!isDesktop)
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_shipping,
                    color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Araç Seç",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 22),
                color: AppTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: "Plaka veya tip ara...",
              hintStyle: const TextStyle(fontSize: 13),
              prefixIcon: const Icon(Icons.search,
                  color: AppTheme.textSecondary, size: 20),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleList() {
    return FutureBuilder<List<Vehicle>>(
      future: FirestoreService.fetchVehiclesByDriver(selectedDriverUid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView.builder(
              itemCount: 5,
              itemBuilder: (_, __) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: ShimmerLoading(
                  width: double.infinity,
                  height: 70,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
          );
        }

        final vehicles = snap.data!.where((v) {
          if (searchQuery.isEmpty) return true;
          final q = searchQuery.toLowerCase();
          return v.plate.toLowerCase().contains(q) ||
              v.type.toLowerCase().contains(q);
        }).toList();

        if (vehicles.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: AppTheme.textSecondary),
                SizedBox(height: 12),
                Text(
                  "Bu şoföre atanmış araç bulunamadı",
                  style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: vehicles.length,
          itemBuilder: (context, i) {
            final vehicle = vehicles[i];
            final isSelected = vehicle.id == selectedVehicleId;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AnimatedCard(
                onTap: () => onSelectVehicle(vehicle),
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.05)
                    : AppTheme.surfaceColor,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : const Color(0xFFE2E8F0),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vehicle.plate,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              vehicle.type,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: AppTheme.successColor, size: 20),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
