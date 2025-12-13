import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lojistik/screens/manager/jobs/full_screen_gallery.dart';
import 'package:lojistik/screens/manager/jobs/download_helper.dart';

class DispatchJobDetailPage extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> data;
  final bool canEdit;

  const DispatchJobDetailPage({
    super.key,
    required this.jobId,
    required this.data,
    required this.canEdit,
  });

  @override
  State<DispatchJobDetailPage> createState() => _DispatchJobDetailPageState();
}

class _DispatchJobDetailPageState extends State<DispatchJobDetailPage> {
  late final TextEditingController _cargoCtrl;
  late final TextEditingController _loadCtrl;
  late final TextEditingController _unloadCtrl;
  late final TextEditingController _notesCtrl;

  bool _editing = false;
  bool _saving = false;

  bool _driversLoading = true;
  List<Map<String, dynamic>> _drivers = [];
  String? _selectedDriverUid;

  @override
  void initState() {
    super.initState();

    _cargoCtrl = TextEditingController(text: widget.data['cargoInfo'] ?? '');
    _loadCtrl = TextEditingController(text: widget.data['loadPort'] ?? '');
    _unloadCtrl = TextEditingController(text: widget.data['unloadPort'] ?? '');
    _notesCtrl = TextEditingController(text: widget.data['notes'] ?? '');

    _selectedDriverUid = widget.data['assignedToUid'];
    _editing = widget.canEdit;

    _loadDrivers();
  }

  // ---------------------------------------------------------------------------
  // DRIVER LOAD
  // ---------------------------------------------------------------------------
  Future<void> _loadDrivers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .get();

      _drivers = snap.docs.map((d) {
        final data = d.data();
        return {
          'uid': d.id,
          'name': data['name'] ?? '',
          'plate': data['plateNumber'] ?? '-',
          'jobStatus': data['jobStatus'] ?? 'available',
        };
      }).toList();
    } catch (e) {
      debugPrint("Driver load error: $e");
    }

    if (mounted) setState(() => _driversLoading = false);
  }

  // ---------------------------------------------------------------------------
  // DRIVER NAME FINDER
  // ---------------------------------------------------------------------------
  String _driverNameFor(String? uid) {
    if (uid == null) return "-";

    final match = _drivers.firstWhere(
          (d) => d["uid"] == uid,
      orElse: () => {},
    );

    if (match.isEmpty) return "-";
    return match["name"] ?? "-";
  }

  // ---------------------------------------------------------------------------
  // SAVE JOB
  // ---------------------------------------------------------------------------
  Future<void> _save() async {
    if (_selectedDriverUid == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Şoför seçmelisiniz.")));
      return;
    }

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance
          .collection("jobs")
          .doc(widget.jobId)
          .update({
        "cargoInfo": _cargoCtrl.text.trim(),
        "loadPort": _loadCtrl.text.trim(),
        "unloadPort": _unloadCtrl.text.trim(),
        "notes": _notesCtrl.text.trim(),
        "assignedToUid": _selectedDriverUid,
        "updatedAt": FieldValue.serverTimestamp(),
      });

      setState(() => _editing = false);

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("İş güncellendi")));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Hata: $e")));
    } finally {
      setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // UI BUILD MODE
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A5F),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.description, size: 20),
            const SizedBox(width: 10),
            const Text(
              "İş Detayları",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 10),
            _statusChip(widget.data['status']),
          ],
        ),
        actions: [
          if (widget.canEdit && !_editing)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editing = true),
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: !_editing ? _buildViewMode() : _buildEditMode(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW MODE
  // ---------------------------------------------------------------------------
  Widget _buildViewMode() {
    final createdAt = widget.data['createdAt'] != null
        ? widget.data['createdAt'].toDate().toString().substring(0, 16)
        : "-";

    return Column(
      children: [
        _buildMinimalCard(
          "Yük Bilgisi",
          _cargoCtrl.text,
          Icons.inventory_2_outlined,
        ),
        const SizedBox(height: 12),
        _buildMinimalCard(
          "Şoför",
          _driverNameFor(widget.data['assignedToUid']),
          Icons.person_outline,
        ),
        const SizedBox(height: 12),
        _buildMinimalCard(
          "Plaka",
          _drivers.firstWhere(
                (d) => d["uid"] == widget.data['assignedToUid'],
            orElse: () => {"plate": "-"},
          )["plate"] ?? "-",
          Icons.drive_eta_outlined,
        ),
        const SizedBox(height: 12),
        _buildMinimalCard(
          "Yükleme Noktası",
          _loadCtrl.text,
          Icons.location_on_outlined,
        ),
        const SizedBox(height: 12),
        _buildMinimalCard(
          "Varış Noktası",
          _unloadCtrl.text,
          Icons.flag_outlined,
        ),
        const SizedBox(height: 12),
        _buildMinimalCard(
          "Oluşturma Tarihi",
          createdAt,
          Icons.calendar_today_outlined,
        ),
        const SizedBox(height: 12),
        if (_notesCtrl.text.isNotEmpty)
          _buildMinimalCard(
            "Notlar",
            _notesCtrl.text,
            Icons.note_outlined,
          ),
        const SizedBox(height: 24),
        _documentsSection(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // EDIT MODE
  // ---------------------------------------------------------------------------
  Widget _buildEditMode() {
    return Column(
      children: [
        _buildEditCard(
          "Yük Bilgisi",
          Icons.inventory_2_outlined,
          TextField(
            controller: _cargoCtrl,
            decoration: _inputDecoration("Yük bilgisi girin"),
          ),
        ),
        const SizedBox(height: 12),
        _buildEditCard(
          "Şoför",
          Icons.person_outline,
          _driversLoading
              ? const LinearProgressIndicator()
              : DropdownButtonFormField<String>(
            value: _selectedDriverUid,
            decoration: _inputDecoration("Şoför seçin"),
            items: _drivers.map((d) {
              return DropdownMenuItem<String>(
                value: d["uid"] as String,
                child: Text("${d["name"]} (${d["plate"]})"),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedDriverUid = v),
          ),
        ),
        const SizedBox(height: 12),
        _buildEditCard(
          "Yükleme Noktası",
          Icons.location_on_outlined,
          TextField(
            controller: _loadCtrl,
            decoration: _inputDecoration("Yükleme noktası girin"),
          ),
        ),
        const SizedBox(height: 12),
        _buildEditCard(
          "Varış Noktası",
          Icons.flag_outlined,
          TextField(
            controller: _unloadCtrl,
            decoration: _inputDecoration("Varış noktası girin"),
          ),
        ),
        const SizedBox(height: 12),
        _buildEditCard(
          "Notlar",
          Icons.note_outlined,
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: _inputDecoration("Notlar (opsiyonel)"),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _editing = false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE53E3E),
                  side: const BorderSide(color: Color(0xFFE53E3E), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "İptal",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38A169),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text(
                  "Kaydet",
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MINIMAL CARD (VIEW MODE)
  // ---------------------------------------------------------------------------
  Widget _buildMinimalCard(String title, dynamic value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF2F7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 24,
              color: const Color(0xFF4A5568),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF718096),
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value?.toString() ?? "-",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EDIT CARD (EDIT MODE)
  // ---------------------------------------------------------------------------
  Widget _buildEditCard(String title, IconData icon, Widget field) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDF2F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: const Color(0xFF4A5568),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4A5568),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          field,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INPUT DECORATION
  // ---------------------------------------------------------------------------
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF7FAFC),
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
        borderSide: const BorderSide(color: Color(0xFF2C5282), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  // ---------------------------------------------------------------------------
  // DOCUMENTS SECTION
  // ---------------------------------------------------------------------------
  Widget _documentsSection() {
    if (widget.data['status'] != "completed") return const SizedBox();

    final docs = (widget.data["documents"] ?? []) as List;

    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            "Bu iş için evrak bulunmuyor.",
            style: TextStyle(
              color: Color(0xFF718096),
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.attachment_outlined,
                    size: 20, color: Color(0xFF4A5568)),
                SizedBox(width: 8),
                Text(
                  "Belgeler",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ],
            ),
            if (docs.length > 1)
              TextButton.icon(
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text("Tümünü indir"),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2C5282),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => DownloadHelper.downloadAll(context, docs),
              )
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: docs.length,
          itemBuilder: (_, i) => _documentItem(docs[i], i, docs),
        ),
      ],
    );
  }

  Widget _documentItem(String url, int index, List docs) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FullScreenGalleryViewer(
                    images: docs,
                    initialIndex: index,
                  ),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF7FAFC),
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        size: 48,
                        color: Color(0xFFCBD5E0),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                  ],
                  stops: const [0.6, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Center(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => DownloadHelper.downloadOne(context, url),
                    borderRadius: BorderRadius.circular(10),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.download_rounded,
                        color: Color(0xFF2C5282),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STATUS CHIP
  // ---------------------------------------------------------------------------
  Widget _statusChip(String? status) {
    status ??= "-";

    Color bg, text;

    switch (status) {
      case "pending":
        bg = Colors.orange.shade100;
        text = Colors.orange.shade800;
        break;
      case "declined":
        bg = Colors.red.shade100;
        text = Colors.red.shade800;
        break;
      case "approved":
        bg = Colors.blue.shade100;
        text = Colors.blue.shade800;
        break;
      case "completed":
        bg = Colors.green.shade100;
        text = Colors.green.shade800;
        break;
      default:
        bg = Colors.grey.shade200;
        text = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}