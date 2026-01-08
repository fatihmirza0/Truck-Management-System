// 📁 lib/screens/manager/add_user/widgets/add_user_info_box.dart
import 'package:flutter/material.dart';

class AddUserInfoBox extends StatelessWidget {
  const AddUserInfoBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Dispatch kullanıcıları iş ataması yapar; sürücüler yalnızca kendilerine atanmış işleri görür.",
              style: TextStyle(
                color: Colors.white.withOpacity(.9),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


