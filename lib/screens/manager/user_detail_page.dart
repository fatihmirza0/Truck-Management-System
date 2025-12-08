import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserDetailPage extends StatefulWidget {
  final String userId; // 🔥 UID (auth + firestore aynı)
  final Map<String, dynamic> data;

  const UserDetailPage({
    super.key,
    required this.userId,
    required this.data,
  });

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  bool editing = false;

  late TextEditingController name;
  late TextEditingController email;
  late TextEditingController phone;
  late TextEditingController plate;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.data['name'] ?? '');
    email = TextEditingController(text: widget.data['email'] ?? '');
    phone = TextEditingController(text: widget.data['phone'] ?? '');
    plate = TextEditingController(text: widget.data['plateNumber'] ?? '');
  }

  void cancelEdit() {
    setState(() {
      editing = false;
      name.text = widget.data['name'] ?? '';
      email.text = widget.data['email'] ?? '';
      phone.text = widget.data['phone'] ?? '';
      plate.text = widget.data['plateNumber'] ?? '';
    });
  }

  // -------------------------------------------------------------
  // SAVE USER CHANGES
  // -------------------------------------------------------------
  Future<void> save() async {
    Map<String, dynamic> updateData = {
      'name': name.text.trim(),
      'email': email.text.trim(),
      'phone': phone.text.trim(),
    };

    if (widget.data['role'] == 'driver') {
      updateData['plateNumber'] = plate.text.trim();
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .update(updateData);

    setState(() => editing = false);

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Kullanıcı güncellendi.")));
  }

  // -------------------------------------------------------------
  // DELETE USER (Firestore)
  // -------------------------------------------------------------
  Future<void> deleteUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Kullanıcıyı Sil"),
        content: const Text("Bu kullanıcı kalıcı olarak silinecek."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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
        const SnackBar(content: Text("Kullanıcı silindi.")),
      );
    }
  }

  // -------------------------------------------------------------
  // INPUT DECORATION
  // -------------------------------------------------------------
  InputDecoration inputStyle(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
    );
  }

  Widget displayField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(value.isNotEmpty ? value : "-", style: const TextStyle(fontSize: 15)),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  // -------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.of(context).size.width > 850;
    final role = widget.data['role'] == 'driver' ? "Şoför" : "Dispatch";

    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: desktop ? 60 : 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ========================= HEADER =========================
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    "Kullanıcı Detayı",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),

                  if (!editing)
                    IconButton(
                      onPressed: () => setState(() => editing = true),
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: "Düzenle",
                    ),

                  IconButton(
                    onPressed: deleteUser,
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: "Sil",
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ========================= CARD =========================
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Kullanıcı Bilgileri",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 20),

                        // ========================= VIEW MODE =========================
                        if (!editing) ...[
                          displayField("İsim", name.text),
                          displayField("E-posta", email.text),
                          displayField("Telefon", phone.text),
                          if (role == "Şoför") displayField("Plaka", plate.text),
                          displayField("Rol", role),

                          const SizedBox(height: 8),
                          const Text(
                            "Düzenlemek için sağ üstteki kalem ikonuna tıklayın.",
                            style: TextStyle(fontSize: 13, color: Colors.black45),
                          ),
                        ],

                        // ========================= EDIT MODE =========================
                        if (editing) ...[
                          TextField(controller: name, decoration: inputStyle("İsim")),
                          const SizedBox(height: 16),

                          TextField(controller: email, decoration: inputStyle("E-posta")),
                          const SizedBox(height: 16),

                          TextField(controller: phone, decoration: inputStyle("Telefon")),
                          const SizedBox(height: 16),

                          if (role == "Şoför")
                            TextField(controller: plate, decoration: inputStyle("Plaka")),

                          const SizedBox(height: 26),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xff2563eb),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: save,
                                  child: const Text("Kaydet",
                                      style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: cancelEdit,
                                  child: const Text("İptal",
                                      style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
