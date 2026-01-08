// 📁 lib/screens/manager/add_user/widgets/add_user_submit_button.dart
import 'package:flutter/material.dart';

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

  static const Color primary = Color(0xFF1E3A5F);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: isDesktop ? 240 : double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? const CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              )
            : const Text(
                "Kullanıcı Ekle",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}


