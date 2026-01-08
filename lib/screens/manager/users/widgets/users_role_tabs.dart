// 📁 lib/screens/manager/users/widgets/users_role_tabs.dart
import 'package:flutter/material.dart';

class UsersRoleTabs extends StatelessWidget {
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;

  const UsersRoleTabs({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  Widget _buildTabButton(String key, String label, IconData icon) {
    final selected = selectedRole == key;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onRoleChanged(key),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E3A5F), Color(0xFF2D4A6F)],
                  )
                : null,
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF1E3A5F).withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : const Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? Colors.white : const Color(0xFF64748B),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTabButton("driver", "Şoförler", Icons.local_shipping_rounded),
          const SizedBox(width: 4),
          _buildTabButton("dispatch", "Dispatch", Icons.headset_mic_rounded),
        ],
      ),
    );
  }
}


