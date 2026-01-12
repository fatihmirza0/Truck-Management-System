import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../widgets/animated/animated_widgets.dart';

class RoleSelector extends StatelessWidget {
  final String selectedRole;
  final ValueChanged<String> onRoleChanged;

  const RoleSelector({
    super.key,
    required this.selectedRole,
    required this.onRoleChanged,
  });

  Widget _buildButton(String key, String label, IconData icon) {
    final selected = selectedRole == key;

    return Expanded(
      child: ScaleButton(
        onTap: () => onRoleChanged(key),
        child: AnimatedContainer(
          duration: AppTheme.fastAnimation,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
              width: 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.textPrimary,
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
    return Row(
      children: [
        _buildButton("driver", "Şoför", Icons.local_shipping_rounded),
        const SizedBox(width: 12),
        _buildButton("dispatch", "Dispatch", Icons.support_agent_rounded),
      ],
    );
  }
}



