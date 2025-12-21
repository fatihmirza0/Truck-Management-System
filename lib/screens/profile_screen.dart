import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart';

import '../services/auth_Service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  bool loading = true;
  bool saving = false;
  bool isEditing = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _plateController = TextEditingController();

  String? userId;
  String? userRole;

  // Vehicle (NEW)
  String? vehicleId; // driver'a atanmış aktif araç
  String? originalVehiclePlate;

  // Original values to compare
  String? originalName;
  String? originalPhone;

  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  bool get hasChanges {
    if (originalName != _nameController.text.trim()) return true;
    if (originalPhone != _phoneController.text.trim()) return true;
    if (userRole == "driver" &&
        (originalVehiclePlate ?? "") != _plateController.text.trim()) {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();

    _nameController.addListener(_onFormChanged);
    _phoneController.addListener(_onFormChanged);
    _plateController.addListener(_onFormChanged);
  }

  void _onFormChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => loading = false);
        return;
      }

      userId = user.uid;

      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        userRole = (data["role"] ?? "").toString();

        originalName = (data["name"] ?? "").toString();
        originalPhone = (data["phone"] ?? "").toString();

        _nameController.text = originalName!;
        _emailController.text = user.email ?? "";
        _phoneController.text = originalPhone!;

        // NEW: driver plaka vehicles’dan gelir
        if (userRole == "driver") {
          await _loadDriverVehiclePlate(userId!);
        }
      }

      if (!mounted) return;
      setState(() => loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _showError("Kullanıcı bilgileri yüklenemedi");
    }
  }

  Future<void> _loadDriverVehiclePlate(String uid) async {
    // driver'a atanmış aktif aracı bul
    final q = await FirebaseFirestore.instance
        .collection("vehicles")
        .where("assignedDriverId", isEqualTo: uid)
        .where("isActive", isEqualTo: true)
        .limit(1)
        .get();

    if (q.docs.isEmpty) {
      vehicleId = null;
      originalVehiclePlate = "";
      _plateController.text = "";
      return;
    }

    final vDoc = q.docs.first;
    vehicleId = vDoc.id;
    final v = vDoc.data();

    originalVehiclePlate = (v["plate"] ?? "").toString();
    _plateController.text = originalVehiclePlate!;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => saving = true);

    try {
      final updates = <String, dynamic>{
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
      };

      // users update (NEW schema)
      await FirebaseFirestore.instance
          .collection("users")
          .doc(userId)
          .update(updates);

      // driver ise plaka -> vehicles update
      if (userRole == "driver") {
        final newPlate = _plateController.text.trim();

        // sadece driver'a atanmış vehicle varsa update et
        if (vehicleId != null && vehicleId!.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection("vehicles")
              .doc(vehicleId)
              .update({"plate": newPlate});

          originalVehiclePlate = newPlate;
        } else {
          // araç yoksa plate kaydetmeye çalışma (UI'da zaten disabled yapıyoruz)
          originalVehiclePlate = originalVehiclePlate ?? "";
        }
      }

      // Update original values
      originalName = _nameController.text.trim();
      originalPhone = _phoneController.text.trim();

      if (!mounted) return;
      setState(() {
        isEditing = false;
        saving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✓ Profil başarıyla güncellendi"),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      _showError("Profil güncellenemedi");
    }
  }

  void _cancelEdit() {
    setState(() {
      _nameController.text = originalName ?? "";
      _phoneController.text = originalPhone ?? "";
      if (userRole == "driver") {
        _plateController.text = originalVehiclePlate ?? "";
      }
      isEditing = false;
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_outlined, color: Color(0xFFDC2626)),
            SizedBox(width: 12),
            Text("Oturumu Kapat"),
          ],
        ),
        content: const Text("Çıkış yapmak istediğinize emin misiniz?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Çıkış Yap"),
          ),
        ],
      ),
    );

    if (res == true) {
      // 🔥 AuthService ile çıkış yap (Firebase + SharedPreferences temizlenir)
      await AuthService.logout();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
      }
    }
  }

  String _getRoleName() {
    switch (userRole) {
      case "admin":
        return "Yönetici";
      case "manager":
        return "Müdür";
      case "dispatch":
        return "Sevkiyat";
      case "driver":
        return "Şoför";
      default:
        return "Kullanıcı";
    }
  }

  IconData _getRoleIcon() {
    switch (userRole) {
      case "admin":
        return Icons.admin_panel_settings;
      case "manager":
        return Icons.business_center;
      case "dispatch":
        return Icons.local_shipping;
      case "driver":
        return Icons.drive_eta;
      default:
        return Icons.person;
    }
  }

  Color _getRoleColor() {
    switch (userRole) {
      case "admin":
        return const Color(0xFFDC2626);
      case "manager":
        return const Color(0xFF7C3AED);
      case "dispatch":
        return const Color(0xFF1E3A5F);
      case "driver":
        return const Color(0xFF059669);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF1E3A5F)),
              ),
            )
          : SafeArea(
              child: Row(
                children: [
                  if (isDesktop) _buildDesktopSidebar(),
                  Expanded(child: _buildMainContent()),
                ],
              ),
            ),
    );
  }

  // --- UI aynı, sadece plaka alanı enable logic değişti ---
  Widget _buildDesktopSidebar() {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                  ),
                ),
                const SizedBox(width: 16),
                const Text(
                  "Profilim",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _getRoleColor().withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getRoleIcon(),
                    size: 56,
                    color: _getRoleColor(),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _nameController.text.isEmpty
                      ? "Kullanıcı"
                      : _nameController.text,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getRoleColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getRoleIcon(), size: 16, color: _getRoleColor()),
                      const SizedBox(width: 6),
                      Text(
                        _getRoleName(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _getRoleColor(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildMenuItem(
              icon: Icons.person_outline,
              title: "Hesap Bilgileri",
              isActive: true),
          _buildMenuItem(
              icon: Icons.security_outlined,
              title: "Güvenlik",
              isActive: false,
              onTap: () {}),
          _buildMenuItem(
              icon: Icons.notifications_outlined,
              title: "Bildirimler",
              isActive: false,
              onTap: () {}),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(32),
            child: OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFDC2626)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_outlined, size: 20),
                  SizedBox(width: 8),
                  Text("Çıkış Yap",
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isActive ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isActive ? const Color(0xFF1E3A5F).withOpacity(0.1) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(icon,
                    size: 20,
                    color: isActive
                        ? const Color(0xFF1E3A5F)
                        : const Color(0xFF64748B)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color: isActive
                          ? const Color(0xFF1E3A5F)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
                if (isActive)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E3A5F),
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return CustomScrollView(
      slivers: [
        if (!isDesktop)
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            leading: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
            ),
            title: const Text(
              "Profilim",
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w700,
              ),
            ),
            actions: [
              if (isEditing)
                TextButton(onPressed: _cancelEdit, child: const Text("İptal"))
              else
                IconButton(
                  onPressed: () => setState(() => isEditing = true),
                  icon:
                      const Icon(Icons.edit_outlined, color: Color(0xFF1E3A5F)),
                ),
              const SizedBox(width: 8),
            ],
          ),
        SliverPadding(
          padding: EdgeInsets.all(isDesktop ? 48.0 : 24.0),
          sliver: SliverToConstrainedBox(
            maxExtent: 800,
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!isDesktop) ...[
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: _getRoleColor().withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_getRoleIcon(),
                              size: 48, color: _getRoleColor()),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _nameController.text.isEmpty
                              ? "Kullanıcı"
                              : _nameController.text,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _getRoleColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getRoleName(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _getRoleColor(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
                if (isDesktop)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hesap Bilgileri",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Kişisel bilgilerinizi güncelleyin",
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      if (!isEditing)
                        ElevatedButton.icon(
                          onPressed: () => setState(() => isEditing = true),
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text("Düzenle"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A5F),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                    ],
                  ),
                if (isDesktop) const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTextField(
                          controller: _nameController,
                          label: "Ad Soyad",
                          icon: Icons.person_outline,
                          enabled: isEditing,
                          validator: (v) =>
                              v?.isEmpty == true ? "Ad soyad giriniz" : null,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _emailController,
                          label: "E-posta",
                          icon: Icons.email_outlined,
                          enabled: false,
                          helperText: "E-posta adresi değiştirilemez",
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _phoneController,
                          label: "Telefon",
                          icon: Icons.phone_outlined,
                          enabled: isEditing,
                          keyboardType: TextInputType.phone,
                        ),
                        if (userRole == "driver") ...[
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _plateController,
                            label: "Plaka",
                            icon: Icons.car_rental_outlined,
                            enabled: isEditing && (vehicleId != null),
                            helperText: vehicleId == null
                                ? "Size atanmış aktif araç bulunamadı"
                                : null,
                          ),
                        ],
                        if (isEditing) ...[
                          const SizedBox(height: 32),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: saving ? null : _cancelEdit,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    side: const BorderSide(
                                        color: Color(0xFFE2E8F0)),
                                  ),
                                  child: const Text(
                                    "İptal",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: saving || !hasChanges
                                      ? null
                                      : _saveProfile,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E3A5F),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    disabledBackgroundColor:
                                        const Color(0xFFE2E8F0),
                                  ),
                                  child: saving
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation(
                                                Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          "Değişiklikleri Kaydet",
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!isDesktop) ...[
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_outlined, size: 20),
                        SizedBox(width: 8),
                        Text(
                          "Çıkış Yap",
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool enabled = true,
    String? helperText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(
            fontSize: 15,
            color: enabled ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color:
                  enabled ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              size: 20,
            ),
            helperText: helperText,
            helperStyle:
                const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            filled: true,
            fillColor:
                enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}

class SliverToConstrainedBox extends SingleChildRenderObjectWidget {
  const SliverToConstrainedBox({
    super.key,
    required this.maxExtent,
    required Widget sliver,
  }) : super(child: sliver);

  final double maxExtent;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSliverToConstrainedBox(maxExtent: maxExtent);
  }

  @override
  void updateRenderObject(
      BuildContext context, _RenderSliverToConstrainedBox renderObject) {
    renderObject.maxExtent = maxExtent;
  }
}

class _RenderSliverToConstrainedBox extends RenderProxySliver {
  _RenderSliverToConstrainedBox({required double maxExtent})
      : _maxExtent = maxExtent;

  double _maxExtent;

  double get maxExtent => _maxExtent;

  set maxExtent(double value) {
    if (_maxExtent == value) return;
    _maxExtent = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final parentWidth = constraints.crossAxisExtent;
    final horizontalPadding =
        (parentWidth - maxExtent).clamp(0.0, double.infinity) / 2;

    child!.layout(
      constraints.copyWith(
        crossAxisExtent:
            (parentWidth - horizontalPadding * 2).clamp(0.0, maxExtent),
      ),
      parentUsesSize: true,
    );

    geometry = child!.geometry!.copyWith(
      paintOrigin: child!.geometry!.paintOrigin,
      paintExtent: child!.geometry!.paintExtent,
      layoutExtent: child!.geometry!.layoutExtent,
    );
  }
}
