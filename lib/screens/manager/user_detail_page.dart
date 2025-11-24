import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserDetailPage extends StatefulWidget {
  final String userId;
  final Map<String, dynamic> data;

  const UserDetailPage({super.key, required this.userId, required this.data});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  bool isEditing = false;

  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController plateController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.data['name'] ?? '');
    emailController = TextEditingController(text: widget.data['email'] ?? '');
    phoneController = TextEditingController(text: widget.data['phone'] ?? '');
    plateController = TextEditingController(text: widget.data['plateNumber'] ?? '');
  }

  void _cancelEdit() {
    setState(() {
      isEditing = false;
      nameController.text = widget.data['name'] ?? '';
      emailController.text = widget.data['email'] ?? '';
      phoneController.text = widget.data['phone'] ?? '';
      plateController.text = widget.data['plateNumber'] ?? '';
    });
  }

  // SAVE & DELETE METHODS (Firebase Firestore)
  Future<void> _saveChanges() async {
    await FirebaseFirestore.instance.collection('users').doc(widget.userId).update({
      'name': nameController.text.trim(),
      'email': emailController.text.trim(),
      'phone': phoneController.text.trim(),
      'plateNumber': plateController.text.trim(),
    });
    setState(() => isEditing = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Bilgiler başarıyla güncellendi.")),
    );
  }

  Future<void> _deleteUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Kullanıcıyı Sil"),
        content: const Text("Bu kullanıcıyı silmek istediğinize emin misiniz?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("İptal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Sil"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('users').doc(widget.userId).delete();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Kullanıcı başarıyla silindi.")),
      );
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      filled: true,
      fillColor: Colors.grey[100],
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {bool editable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: editable
          ? TextField(
        controller: controller,
        decoration: _inputDecoration(label),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black54)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xffe5e7eb)),
            ),
            child: Text(controller.text.isNotEmpty ? controller.text : "-", style: const TextStyle(fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _saveChanges,
            icon: const Icon(Icons.save_outlined),
            label: const Text("Kaydet"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff2563eb),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _cancelEdit,
            icon: const Icon(Icons.close_outlined),
            label: const Text("İptal"),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xff94a3b8)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),
      appBar: AppBar(
        title: const Text("Kullanıcı Detayı"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        centerTitle: true,
        actions: [
          if (!isEditing)
            IconButton(icon: const Icon(Icons.edit_outlined), tooltip: "Düzenle", onPressed: () => setState(() => isEditing = true)),
          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), tooltip: "Sil", onPressed: _deleteUser),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: isDesktop ? 48 : 24, vertical: isDesktop ? 36 : 20),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 500 : double.infinity),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Kullanıcı Bilgileri", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20, color: Colors.black87)),
                const SizedBox(height: 12),
                _buildField("İsim", nameController, editable: isEditing),
                _buildField("E-posta", emailController, editable: isEditing),
                _buildField("Telefon", phoneController, editable: isEditing),
                _buildField("Plaka", plateController, editable: isEditing),
                _buildField("Rol", TextEditingController(text: widget.data['roleId'] == 'driver' ? "Şoför" : "Dispatch")),
                const SizedBox(height: 28),
                if (isEditing) _buildActionButtons(),
                if (!isEditing)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text("Not: Düzenleme yapmak için sağ üstteki kalem ikonuna tıklayın.", style: TextStyle(color: Colors.black54, fontSize: 13)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
