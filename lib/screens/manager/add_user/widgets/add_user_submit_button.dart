import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../widgets/animated/animated_widgets.dart';

class AddUserSubmitButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  final bool isDesktop;

  const AddUserSubmitButton({
    super.key,
    required this.loading,
    required this.onPressed,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onTap: loading ? null : onPressed,
      child: Container(
        width: isDesktop ? 240 : double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.25),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                "Kullanıcıyı Kaydet",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}



