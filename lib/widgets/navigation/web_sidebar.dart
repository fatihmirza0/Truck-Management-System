import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../services/auth_service.dart';
import '../../config/app_theme.dart';

class WebSidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onDestinationSelected;

  const WebSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  State<WebSidebar> createState() => _WebSidebarState();
}

class _WebSidebarState extends State<WebSidebar> {
  String? _role;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await AuthService.getSavedUserRole();
    if (mounted) setState(() => _role = role);
  }

  @override
  Widget build(BuildContext context) {
    final isManager = _role == 'manager';
    final isDispatch = _role == 'dispatch';

    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: AppTheme.sidebarColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                if (isManager || isDispatch) _buildSectionLabel('OPERASYON'),
                if (isManager)
                  _SidebarItem(
                    icon: Icons.dashboard_rounded,
                    label: 'Ana Sayfa',
                    isActive: widget.selectedIndex == 0,
                    onTap: () => widget.onDestinationSelected(0),
                  ),
                if (isManager || isDispatch)
                  _SidebarItem(
                    icon: Icons.map_rounded,
                    label: 'Canlı Takip',
                    isActive: widget.selectedIndex == 1,
                    onTap: () => widget.onDestinationSelected(1),
                  ),
                if (isManager || isDispatch)
                  _SidebarItem(
                    icon: Icons.assignment_rounded,
                    label: 'İş Yönetimi',
                    isActive: widget.selectedIndex == 2,
                    onTap: () => widget.onDestinationSelected(2),
                  ),
                if (isManager || isDispatch)
                  _SidebarItem(
                    icon: Icons.task_alt_rounded,
                    label: 'Tamamlananlar',
                    isActive: widget.selectedIndex == 3,
                    onTap: () => widget.onDestinationSelected(3),
                  ),
                
                if (isManager) ...[
                  const SizedBox(height: 16),
                  _buildSectionLabel('YÖNETİM'),
                  _SidebarItem(
                    icon: Icons.person_add_rounded,
                    label: 'Personel Ekle',
                    isActive: widget.selectedIndex == 4,
                    onTap: () => widget.onDestinationSelected(4),
                  ),
                  _SidebarItem(
                    icon: Icons.people_rounded,
                    label: 'Kullanıcılar',
                    isActive: widget.selectedIndex == 5,
                    onTap: () => widget.onDestinationSelected(5),
                  ),
                  _SidebarItem(
                    icon: Icons.local_shipping_rounded,
                    label: 'Araçlar',
                    isActive: widget.selectedIndex == 6,
                    onTap: () => widget.onDestinationSelected(6),
                  ),
                  const SizedBox(height: 16),
                  _buildSectionLabel('SİSTEM'),
                  _SidebarItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'Raporlar',
                    isActive: widget.selectedIndex == 7,
                    onTap: () => widget.onDestinationSelected(7),
                  ),
                  _SidebarItem(
                    icon: Icons.history_rounded,
                    label: 'Denetim Kayıtları',
                    isActive: widget.selectedIndex == 8,
                    onTap: () => widget.onDestinationSelected(8),
                  ),
                  _SidebarItem(
                    icon: Icons.credit_card_rounded,
                    label: 'Paketler & Ödeme',
                    isActive: widget.selectedIndex == 9,
                    onTap: () => widget.onDestinationSelected(9),
                  ),
                  _SidebarItem(
                    icon: Icons.settings_rounded,
                    label: 'Ayarlar',
                    isActive: widget.selectedIndex == 10,
                    onTap: () => widget.onDestinationSelected(10),
                  ),
                ],
              ],
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.3),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LOGIPRO',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.white,
                ),
              ),
              Text(
                'Lojistik Yönetimi',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: const Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => widget.onDestinationSelected(11), // Profile index
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryColor,
                    child: const Icon(Icons.person, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kullanıcı',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Profil Ayarları',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.redAccent),
                    onPressed: () async {
                      await AuthService.logoutFast();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryColor.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)) : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive ? Colors.white : Colors.white60,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.white60,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
              if (isActive)
                const Spacer()
              else
                const SizedBox.shrink(),
              if (isActive)
                Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


