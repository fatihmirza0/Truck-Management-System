import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

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
  static const Color _accent = Color(0xff2563eb);
  static const Color _bg = Color(0xfff5f6fa);

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
  // DOWNLOAD HELPERS
  // ---------------------------------------------------------------------------
  Future<void> _downloadMobile(String url, String fileName) async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) return;
    }

    final dir = Platform.isAndroid
        ? await getExternalStorageDirectory()
        : await getApplicationDocumentsDirectory();

    await FlutterDownloader.enqueue(
      url: url,
      savedDir: dir!.path,
      fileName: fileName,
      showNotification: true,
      openFileFromNotification: true,
    );
  }

  Future<void> _downloadDesktopSingle(String url, String fileName) async {
    final savePath = await FilePicker.platform.saveFile(
      dialogTitle: "Kaydet",
      fileName: fileName,
    );

    if (savePath == null) return;

    final response = await http.get(Uri.parse(url));
    final file = File(savePath);
    await file.writeAsBytes(response.bodyBytes);
  }

  void _openImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(child: Image.network(url)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 📌 INPUT DECORATION EKLENDİ
  // ---------------------------------------------------------------------------
  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      contentPadding: const EdgeInsets.all(12),
    );
  }

  // ---------------------------------------------------------------------------
  // 📌 DOCUMENTS SECTION EKLENDİ
  // ---------------------------------------------------------------------------
  Widget _documentsSection() {
    if (widget.data['status'] != "completed") return const SizedBox();

    final docs = (widget.data["documents"] ?? []) as List;

    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _sectionBox(),
        child: const Text("Bu iş için evrak bulunmuyor."),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Tamamlanan İş Evrakları",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          itemCount: docs.length,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemBuilder: (_, i) {
            final url = docs[i].toString();
            return ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InkWell(
                      onTap: () => _openImage(url),
                      child: Image.network(url, fit: BoxFit.cover),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // UI BUILD MODE
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Row(
          children: [
            const Text("İş Detayı"),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: !_editing
                ? _buildViewMode(isWide)
                : _buildEditMode(isWide),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // VIEW MODE
  // ---------------------------------------------------------------------------
  Widget _buildViewMode(bool isWide) {
    final createdAt = widget.data['createdAt'] != null
        ? widget.data['createdAt'].toDate().toString().substring(0, 16)
        : "-";

    return Column(
      children: [
        isWide
            ? Row(
          children: [
            Expanded(child: _generalCard(createdAt)),
            const SizedBox(width: 16),
            Expanded(child: _driverCard()),
          ],
        )
            : Column(
          children: [
            _generalCard(createdAt),
            const SizedBox(height: 16),
            _driverCard(),
          ],
        ),
        const SizedBox(height: 20),
        _documentsSection(),
      ],
    );
  }

  Widget _generalCard(String createdAt) {
    return _section(
      "Genel Bilgiler",
      [
        _display("Yük", _cargoCtrl.text),
        _display("Yükleme", _loadCtrl.text),
        _display("Varış", _unloadCtrl.text),
        _display("Oluşturma", createdAt),
      ],
    );
  }

  Widget _driverCard() {
    final plate = _drivers.firstWhere(
          (d) => d["uid"] == widget.data['assignedToUid'],
      orElse: () => {"plate": "-"},
    )["plate"];

    return _section(
      "Şoför & Notlar",
      [
        _display("Şoför", _driverNameFor(widget.data['assignedToUid'])),
        _display("Plaka", plate ?? "-"),
        _display("Notlar", _notesCtrl.text.isNotEmpty ? _notesCtrl.text : "-"),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // EDIT MODE
  // ---------------------------------------------------------------------------
  Widget _buildEditMode(bool isWide) {
    final left = Expanded(
      child: _section(
        "İş Bilgileri",
        [
          TextField(controller: _cargoCtrl, decoration: _input("Yük")),
          const SizedBox(height: 10),
          TextField(controller: _loadCtrl, decoration: _input("Yükleme")),
          const SizedBox(height: 10),
          TextField(controller: _unloadCtrl, decoration: _input("Varış")),
        ],
      ),
    );

    final right = Expanded(
      child: _section(
        "Şoför & Notlar",
        [
          _driversLoading
              ? const LinearProgressIndicator()
              : DropdownButtonFormField<String>(
            value: _selectedDriverUid,
            decoration: _input("Şoför"),
            items: _drivers.map((d) {
              return DropdownMenuItem<String>(
                value: d["uid"] as String,   // 🔥 ZORUNLU CAST
                child: Text("${d["name"]} (${d["plate"]})"),
              );
            }).toList(),
            onChanged: (v) => setState(() => _selectedDriverUid = v),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: _input("Notlar"),
          ),
        ],
      ),
    );

    return Column(
      children: [
        isWide
            ? Row(children: [left, const SizedBox(width: 16), right])
            : Column(children: [left, const SizedBox(height: 16), right]),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Kaydet"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _editing = false),
                child: const Text("İptal"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
  Widget _section(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _sectionBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _display(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xfffafafa),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(value),
          ),
        ],
      ),
    );
  }

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

  BoxDecoration _sectionBox() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade300),
    );
  }
}
