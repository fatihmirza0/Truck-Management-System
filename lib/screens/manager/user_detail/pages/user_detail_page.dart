// ============================================
// PROFESSIONAL USER DETAIL PAGE
// Desktop & Mobile Optimized
// ============================================
import 'package:flutter/material.dart';
import '../../../../services/firestore_Service.dart';

import '../widgets/user_detail_info_card.dart';
import '../widgets/user_detail_info_tile.dart';

class UserDetailPage extends StatefulWidget {
  final String userId;
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
  bool loading = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _plateCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.data['name'] ?? '');
    _emailCtrl = TextEditingController(text: widget.data['email'] ?? '');
    _phoneCtrl = TextEditingController(text: widget.data['phone'] ?? '');
    _plateCtrl = TextEditingController(text: widget.data['plateNumber'] ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _plateCtrl.dispose();
    super.dispose();
  }

  bool get isDriver => widget.data['role'] == 'driver';

  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      _showSnackBar("İsim boş olamaz", isError: true);
      return;
    }

    setState(() => loading = true);

    try {
      Map<String, dynamic> updates = {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
      };

      if (isDriver) {
        updates['plateNumber'] = _plateCtrl.text.trim();
      }

      await FirestoreService.updateUserHttp(
        uid: widget.userId,
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        phone: _phoneCtrl.text,
        plate: isDriver ? _plateCtrl.text : null,
        role: widget.data['role'],
      );

      setState(() {
        editing = false;
        loading = false;
      });

      _showSnackBar("Başarıyla güncellendi");
    } catch (e) {
      setState(() => loading = false);
      _showSnackBar("Hata: $e", isError: true);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          "Kullanıcıyı Sil",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: const Text(
          "Bu işlem geri alınamaz. Devam etmek istiyor musunuz?",
          style: TextStyle(fontSize: 14),
        ),
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
            ),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => loading = true);
      try {
        await FirestoreService.softDeleteUserHttp(widget.userId);

        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kullanıcı silindi")),
        );
      } catch (e) {
        setState(() => loading = false);
        _showSnackBar("Silme hatası: $e", isError: true);
      }
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isDesktop) {
      return _buildDesktopLayout();
    } else {
      return _buildMobileLayout();
    }
  }

  // ============================================
  // DESKTOP LAYOUT - Full Width Professional
  // ============================================
  Widget _buildDesktopLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          Column(
            children: [
              // Fixed Header Bar
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, size: 22),
                      color: const Color(0xFF1E3A5F),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF8FAFC),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isDriver
                            ? Icons.local_shipping_outlined
                            : Icons.support_agent_outlined,
                        size: 24,
                        color: const Color(0xFF1E3A5F),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.data['name'] ?? "Kullanıcı Detayı",
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E3A5F),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isDriver ? "Şoför" : "Dispatch",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!editing) ...[
                      ElevatedButton.icon(
                        onPressed: () => setState(() => editing = true),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text("Düzenle"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E3A5F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    if (editing) ...[
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            editing = false;
                            _nameCtrl.text = widget.data['name'] ?? '';
                            _emailCtrl.text = widget.data['email'] ?? '';
                            _phoneCtrl.text = widget.data['phone'] ?? '';
                            _plateCtrl.text = widget.data['plateNumber'] ?? '';
                          });
                        },
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text("İptal"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _save,
                        icon: const Icon(Icons.check, size: 18),
                        label: const Text("Kaydet"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    OutlinedButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text("Sil"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFDC2626)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content Area
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column - Main Info
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Kullanıcı Bilgileri",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E3A5F),
                                ),
                              ),
                              const SizedBox(height: 24),
                              if (editing)
                                _buildEditForm()
                              else
                                _buildViewMode(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      // Right Column - Stats/Info
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            UserDetailInfoCard(
                              title: "Hesap Durumu",
                              icon: Icons.verified_user_outlined,
                              value: "Aktif",
                              color: const Color(0xFF059669),
                            ),
                            const SizedBox(height: 16),
                            UserDetailInfoCard(
                              title: "Rol",
                              icon: Icons.badge_outlined,
                              value: isDriver ? "Şoför" : "Dispatch",
                              color: const Color(0xFF1E3A5F),
                            ),
                            const SizedBox(height: 16),
                            UserDetailInfoCard(
                              title: "Kullanıcı ID",
                              icon: Icons.fingerprint_outlined,
                              value: widget.userId.substring(0, 8) + "...",
                              color: const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (loading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF1E3A5F)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================
  // MOBILE LAYOUT - Compact
  // ============================================
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildMobileHeader(),
                    const SizedBox(height: 32),
                    _buildMobileCard(),
                  ],
                ),
              ),
            ),
          ),
          if (loading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(Color(0xFF1E3A5F)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, size: 22),
          color: const Color(0xFF1E3A5F),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.data['name'] ?? "Kullanıcı Detayı",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A5F),
            ),
          ),
        ),
        if (!editing)
          IconButton(
            onPressed: () => setState(() => editing = true),
            icon: const Icon(Icons.edit_outlined, size: 20),
            color: const Color(0xFF1E3A5F),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
            ),
          ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _delete,
          icon: const Icon(Icons.delete_outline, size: 20),
          color: const Color(0xFFDC2626),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFFDC2626)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDriver
                  ? Icons.local_shipping_outlined
                  : Icons.support_agent_outlined,
              size: 32,
              color: const Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.data['name'] ?? "-",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isDriver ? "Şoför" : "Dispatch",
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 24),
          if (editing) _buildEditForm() else _buildViewMode(),
        ],
      ),
    );
  }

  // ============================================
  // SHARED COMPONENTS
  // ============================================
  Widget _buildViewMode() {
    return Column(
      children: [
        UserDetailInfoTile(
          icon: Icons.person_outline,
          label: "İsim",
          value: _nameCtrl.text,
        ),
        UserDetailInfoTile(
          icon: Icons.email_outlined,
          label: "E-posta",
          value: _emailCtrl.text,
        ),
        UserDetailInfoTile(
          icon: Icons.phone_outlined,
          label: "Telefon",
          value: _phoneCtrl.text,
        ),
        if (isDriver)
          UserDetailInfoTile(
            icon: Icons.car_rental_outlined,
            label: "Plaka",
            value: _plateCtrl.text,
          ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        _field("İsim", _nameCtrl, Icons.person_outline),
        const SizedBox(height: 20),
        _field("E-posta", _emailCtrl, Icons.email_outlined),
        const SizedBox(height: 20),
        _field("Telefon", _phoneCtrl, Icons.phone_outlined),
        if (isDriver) ...[
          const SizedBox(height: 20),
          _field("Plaka", _plateCtrl, Icons.car_rental_outlined),
        ],
        if (!isDesktop) ...[
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      editing = false;
                      _nameCtrl.text = widget.data['name'] ?? '';
                      _emailCtrl.text = widget.data['email'] ?? '';
                      _phoneCtrl.text = widget.data['phone'] ?? '';
                      _plateCtrl.text = widget.data['plateNumber'] ?? '';
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    "İptal",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    "Kaydet",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _field(String label, TextEditingController ctrl, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF1E3A5F), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

