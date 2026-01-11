import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_service.dart';
import 'package:lojistik/config/app_theme.dart';
import 'package:lojistik/widgets/animated/animated_widgets.dart';

class DriverSelectionPanel extends StatelessWidget {
  final Animation<double> animation;
  final bool isDesktop;
  final TextEditingController searchController;
  final String searchQuery;
  final String? selectedDriverUid;
  final Function(String) onSearchChanged;
  final VoidCallback onClose;
  final Function(Map<String, dynamic>) onSelectDriver;

  const DriverSelectionPanel({
    super.key,
    required this.animation,
    required this.isDesktop,
    required this.searchController,
    required this.searchQuery,
    required this.selectedDriverUid,
    required this.onSearchChanged,
    required this.onClose,
    required this.onSelectDriver,
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
                  Expanded(child: _buildDriverList()),
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
                child: const Icon(Icons.person_search,
                    color: AppTheme.primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Şoför Seç",
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
              hintText: "İsim, e-posta veya plaka ara...",
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

  Widget _buildDriverList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: FirestoreService.fetchDrivers(),
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
                  height: 80,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
          );
        }

        final drivers = snap.data!.where((d) {
          if (searchQuery.isEmpty) return true;
          final q = searchQuery;
          return d['name'].toString().toLowerCase().contains(q) ||
              d['email'].toString().toLowerCase().contains(q) ||
              (d['activePlate'] ?? '').toString().toLowerCase().contains(q);
        }).toList();

        if (drivers.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 48, color: AppTheme.textSecondary),
                SizedBox(height: 12),
                Text(
                  "Şoför bulunamadı",
                  style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: drivers.length,
          itemBuilder: (context, i) {
            final driver = drivers[i];
            final isSelected = driver['uid'] == selectedDriverUid;
            final isBusy = (driver['jobStatus'] ?? 'available') == 'busy';

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AnimatedCard(
                onTap: isBusy ? null : () => onSelectDriver(driver),
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.05)
                    : (isBusy
                        ? AppTheme.errorColor.withValues(alpha: 0.03)
                        : AppTheme.surfaceColor),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : (isBusy
                              ? AppTheme.errorColor.withValues(alpha: 0.3)
                              : const Color(0xFFE2E8F0)),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isBusy
                              ? AppTheme.errorColor.withValues(alpha: 0.1)
                              : AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isBusy ? Icons.work_outline : Icons.person_outlined,
                          color: isBusy
                              ? AppTheme.errorColor
                              : AppTheme.primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    driver['name'],
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isBusy
                                          ? AppTheme.textSecondary
                                          : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isBusy
                                        ? AppTheme.errorColor
                                        : AppTheme.successColor,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    isBusy ? "MEŞGUL" : "MÜSAİT",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: .3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              driver['email'],
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            if (driver['activePlate'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                "🚛 ${driver['activePlate']}",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
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
