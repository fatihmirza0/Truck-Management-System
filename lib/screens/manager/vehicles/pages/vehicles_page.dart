import 'package:flutter/material.dart';
import '../../../../services/firestore_service.dart';
import '../../../../config/app_theme.dart';
import '../../../../widgets/animated/animated_widgets.dart';
import '../../../../utils/page_transitions.dart';
import 'vehicle_detail_page.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  String _filterStatus = "all"; // all, active, maintenance, out_of_service

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: Stream.fromFuture(FirestoreService.fetchVehicles()),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildShimmerGrid();
              }
              
              if (snapshot.hasError) {
                 return const Center(child: Text("Veriler alınamadı", style: TextStyle(color: AppTheme.errorColor)));
              }

              var vehicles = snapshot.data ?? [];
              
              // Filter logic
              vehicles = vehicles.where((v) {
                final plate = (v['plate'] ?? "").toString().toLowerCase();
                final type = (v['type'] ?? "").toString().toLowerCase();
                final query = _searchQuery.toLowerCase();
                final status = v['status'] ?? 'active';

                final matchesSearch = plate.contains(query) || type.contains(query);
                final matchesFilter = _filterStatus == 'all' || status == _filterStatus;

                return matchesSearch && matchesFilter;
              }).toList();

              if (vehicles.isEmpty) {
                return _buildEmptyState();
              }

              return GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.8,
                ),
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  return _VehicleCard(
                    vehicle: vehicles[index],
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        SlidePageRoute(page: VehicleDetailPage(vehicle: vehicles[index])),
                      );
                      if (result == true) {
                        setState(() {}); // Refresh list
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_car_filled_outlined, color: AppTheme.primaryColor, size: 28),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Araç Filosu",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    "Tüm araçlarınızı buradan yönetebilirsiniz",
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    SlidePageRoute(page: const VehicleDetailPage()),
                  );
                  if (result == true) {
                    setState(() {}); // Refresh list
                  }
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text("Yeni Araç Ekle", style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  elevation: 4,
                  shadowColor: AppTheme.primaryColor.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: const InputDecoration(
                      hintText: "Plaka, tip veya özellik ara...",
                      prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textSecondary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _buildFilterDropdown(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _filterStatus,
          icon: const Icon(Icons.filter_list_rounded, color: AppTheme.textSecondary),
          borderRadius: BorderRadius.circular(12),
          onChanged: (val) {
            if (val != null) setState(() => _filterStatus = val);
          },
          items: const [
            DropdownMenuItem(value: "all", child: Text("Tüm Durumlar")),
            DropdownMenuItem(value: "active", child: Text("Aktif")),
            DropdownMenuItem(value: "maintenance", child: Text("Bakımda")),
            DropdownMenuItem(value: "out_of_service", child: Text("Servis Dışı")),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.8,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const ShimmerLoading(
          width: double.infinity,
          height: 200,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping_outlined, size: 48, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          const Text(
            "Araç Bulunamadı",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Seçilen kriterlere uygun araç yok.",
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Map<String, dynamic> vehicle;
  final VoidCallback onTap;

  const _VehicleCard({required this.vehicle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = vehicle['status'] ?? 'active';
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'maintenance':
        statusColor = const Color(0xFFF59E0B);
        statusText = 'Bakımda';
        statusIcon = Icons.build_circle_outlined;
        break;
      case 'out_of_service':
        statusColor = const Color(0xFFEF4444);
        statusText = 'Servis Dışı';
        statusIcon = Icons.error_outline_rounded;
        break;
      case 'active':
      default:
        statusColor = const Color(0xFF10B981);
        statusText = 'Aktif';
        statusIcon = Icons.check_circle_outline_rounded;
    }

    return AnimatedCard(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Hero(
                      tag: 'vehicle_icon_${vehicle['vehicleId']}',
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.1),
                              AppTheme.primaryColor.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.local_shipping, color: AppTheme.primaryColor, size: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle['plate'] ?? "-",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          vehicle['type'] ?? "-",
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              height: 1,
              width: double.infinity,
              color: Colors.grey.withOpacity(0.1),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 18, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    vehicle['assignedDriverId'] != null ? "Şoför Atandı" : "Şoför Atanmadı",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: vehicle['assignedDriverId'] != null ? FontWeight.w600 : FontWeight.w400,
                      color: vehicle['assignedDriverId'] != null ? AppTheme.textPrimary : AppTheme.textSecondary,
                    ),
                  ),
                ),
                if (vehicle['assignedDriverId'] != null)
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textSecondary),
              ],
            )
          ],
        ),
      ),
    );
  }
}
