// 📁 lib/pages/widgets/vehicle_selection_panel.dart
import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_Service.dart';

class VehicleSelectionPanel extends StatelessWidget {
  final Animation<double> animation;
  final bool isDesktop;
  final TextEditingController searchController;
  final String searchQuery;
  final String? selectedVehicleId;
  final String selectedDriverUid;
  final Function(String) onSearchChanged;
  final VoidCallback onClose;
  final Function(Map<String, dynamic>) onSelectVehicle;

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

  static const Color primary = Color(0xFF1E3A5F);
  static const Color accent = Color(0xFF3B82F6);
  static const Color success = Color(0xFF10B981);
  static const Color bg = Color(0xFFF8FAFC);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);

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
                offset: Offset(0, (1 - animation.value) * (isDesktop ? 50 : 500)),
                child: Opacity(opacity: animation.value, child: child),
              );
            },
            child: Container(
              width: isDesktop ? 600 : double.infinity,
              height: isDesktop ? 550 : MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: isDesktop
                    ? BorderRadius.circular(16)
                    : const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  )
                ],
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
        color: cardBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isDesktop ? 16 : 24),
          topRight: Radius.circular(isDesktop ? 16 : 24),
        ),
        border: const Border(bottom: BorderSide(color: border)),
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
                  color: border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_shipping, color: primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Araç Seç",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 22),
                color: textSecondary,
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
              prefixIcon: const Icon(Icons.search, color: textSecondary, size: 20),
              filled: true,
              fillColor: bg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: FirestoreService.fetchVehiclesByDriver(selectedDriverUid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final vehicles = snap.data!.where((v) {
          if (searchQuery.isEmpty) return true;
          return v['plate'].toString().toLowerCase().contains(searchQuery) ||
              v['type'].toString().toLowerCase().contains(searchQuery);
        }).toList();

        if (vehicles.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: textSecondary),
                SizedBox(height: 12),
                Text(
                  "Bu şoföre atanmış araç bulunamadı",
                  style: TextStyle(fontSize: 15, color: textSecondary),
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
            final isSelected = vehicle['vehicleId'] == selectedVehicleId;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected ? accent.withOpacity(0.05) : cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? accent : border,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelectVehicle(vehicle),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.local_shipping_outlined,
                            color: accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehicle['plate'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                vehicle['type'],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: success, size: 20),
                      ],
                    ),
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