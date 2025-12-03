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
  List<Map<String, String>> _drivers = [];
  String? _selectedDriverId;

  @override
  void initState() {
    super.initState();

    _cargoCtrl = TextEditingController(text: widget.data['cargoInfo'] ?? '');
    _loadCtrl = TextEditingController(text: widget.data['loadPort'] ?? '');
    _unloadCtrl = TextEditingController(text: widget.data['unloadPort'] ?? '');
    _notesCtrl = TextEditingController(text: widget.data['notes'] ?? '');

    _selectedDriverId = widget.data['assignedTo'];
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
          .where('roleId', isEqualTo: 'driver')
          .get();

      _drivers = snap.docs
          .map((d) {
            final data = d.data();
            return {
              'id': (data['driverId'] ?? '').toString(),
              'name': (data['name'] ?? '').toString(),
              'plate': (data['plateNumber'] ?? '-').toString(),
            };
          })
          .where((e) => e['id']!.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('Driver load error: $e');
    }

    if (mounted) {
      setState(() => _driversLoading = false);
    }
  }

  String _driverNameFor(String? id) {
    if (id == null || id.isEmpty) return '-';

    final match = _drivers.firstWhere(
      (e) => e['id'] == id,
      orElse: () => {},
    );

    if (match.isEmpty) {
      return (widget.data['assignedToName'] ?? id).toString();
    }
    return match['name'] ?? id;
  }

  String _safeDriverSlug() {
    final raw = _driverNameFor(widget.data['assignedTo']);
    final cleaned = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9ğüşıöç]+'), "_")
        .replaceAll(RegExp(r'_+'), "_")
        .trim();

    return cleaned.isEmpty ? "sofor" : cleaned;
  }

  String _fileNameForDoc(String url, int index) {
    final slug = _safeDriverSlug();
    final ext = url.split('.').last.split('?').first;
    return "${slug}_evrak_${index + 1}.$ext";
  }

  // ---------------------------------------------------------------------------
  // INPUT DECORATION
  // ---------------------------------------------------------------------------
  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: _accent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  // ---------------------------------------------------------------------------
  // SAVE JOB
  // ---------------------------------------------------------------------------
  Future<void> _save() async {
    if (_selectedDriverId == null || _selectedDriverId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen bir şoför seçin.")),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final driverName = _driverNameFor(_selectedDriverId);

      await FirebaseFirestore.instance
          .collection('jobs')
          .doc(widget.jobId)
          .update({
        'cargoInfo': _cargoCtrl.text.trim(),
        'loadPort': _loadCtrl.text.trim(),
        'unloadPort': _unloadCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
        'assignedTo': _selectedDriverId,
        'assignedToName': driverName,
        if (widget.data['status'] == 'declined') 'status': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _editing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("İş başarıyla güncellendi.")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kaydetme hatası: $e")),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------------
  // DOWNLOAD (MOBILE)
  // ---------------------------------------------------------------------------
  Future<void> _downloadMobile(String url, String fileName) async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Depolama izni gerekli")));
        return;
      }
    }

    Directory baseDir;

    if (Platform.isAndroid) {
      baseDir = (await getExternalStorageDirectory()) ??
          await getApplicationDocumentsDirectory();
    } else {
      baseDir = await getApplicationDocumentsDirectory();
    }

    await FlutterDownloader.enqueue(
      url: url,
      savedDir: baseDir.path,
      fileName: fileName,
      showNotification: true,
      openFileFromNotification: true,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("İndirme başlatıldı: $fileName")),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // DOWNLOAD (DESKTOP - KLÖSOR)
  // ---------------------------------------------------------------------------
  Future<void> _downloadAllDesktop(List docs) async {
    final String? folder = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Belgelerin kaydedileceği klasörü seçin",
    );

    if (folder == null) {
      debugPrint("Klasör seçilmedi.");
      return;
    }

    for (var i = 0; i < docs.length; i++) {
      final url = docs[i].toString();
      final fileName = _fileNameForDoc(url, i);
      final savePath = "$folder/$fileName";

      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final file = File(savePath);
          await file.writeAsBytes(response.bodyBytes);
        }
      } catch (e) {
        debugPrint("Evrak indirilemedi: $e");
      }
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Belgeler başarıyla kaydedildi:\n$folder")),
    );
  }

  // Tek dosya indir (Desktop)
  Future<void> _downloadDesktopSingle(String url, String fileName) async {
    final String? savePath = await FilePicker.platform.saveFile(
      dialogTitle: "Dosyayı kaydet",
      fileName: fileName,
    );

    if (savePath == null) return;

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final file = File(savePath);
      await file.writeAsBytes(response.bodyBytes);

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Kaydedildi: $savePath")));
    }
  }

  // ---------------------------------------------------------------------------
  // IMAGE PREVIEW
  // ---------------------------------------------------------------------------
  void _openImage(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DOWNLOAD DISPATCHER
  // ---------------------------------------------------------------------------
  Future<void> _downloadFile(String url, String fileName) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return _downloadMobile(url, fileName);
    }
    return _downloadDesktopSingle(url, fileName);
  }

  // ---------------------------------------------------------------------------
  // DOCUMENT SECTION
  // ---------------------------------------------------------------------------
  Widget _documentsSection() {
    if (widget.data['status'] != 'completed') return const SizedBox();

    final List docs = widget.data['documents'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              "Tamamlanan İş Evrakları",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),

            const Spacer(), // ← butonu sağa iter

            if (docs.isNotEmpty)
              ElevatedButton.icon(
                onPressed: () async {
                  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
                    await _downloadAllDesktop(docs);
                  } else {
                    for (var i = 0; i < docs.length; i++) {
                      final url = docs[i].toString();
                      final fileName = _fileNameForDoc(url, i);
                      await _downloadFile(url, fileName);
                    }
                  }
                },
                icon: const Icon(Icons.download),
                label: const Text("Tümünü İndir"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                ),
              ),
          ],
        ),

        const SizedBox(height: 10),

        if (docs.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: _sectionBox(),
            child: const Text("Bu iş için yüklenmiş evrak bulunmuyor."),
          )
        else
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
              final fileName = _fileNameForDoc(url, i);

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
                    Positioned(
                      top: 6,
                      right: 6,
                      child: InkWell(
                        onTap: () => _downloadFile(url, fileName),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.download,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
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
  // BUILD LAYOUT
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final status = (widget.data['status'] ?? '-').toString();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            const Text("İş Detayı",
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.black)),
            const SizedBox(width: 10),
            _statusChip(status),
          ],
        ),
        actions: [
          if (widget.canEdit && !_editing)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.black87),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: !_editing ? _buildViewMode(isWide) : _buildEditMode(isWide),
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

    final topRow = isWide
        ? Row(
            children: [
              Expanded(child: _generalInfoCard(createdAt)),
              const SizedBox(width: 16),
              Expanded(child: _driverInfoCard()),
            ],
          )
        : Column(
            children: [
              _generalInfoCard(createdAt),
              const SizedBox(height: 16),
              _driverInfoCard(),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        topRow,
        const SizedBox(height: 20),
        _documentsSection(),
      ],
    );
  }

  Widget _generalInfoCard(String createdAt) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: _sectionBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Genel Bilgiler"),
          const SizedBox(height: 10),
          _displayRow("Yük", _cargoCtrl.text),
          _displayRow("Yükleme Noktası", _loadCtrl.text),
          _displayRow("Varış Noktası", _unloadCtrl.text),
          _displayRow("Oluşturma Tarihi", createdAt),
        ],
      ),
    );
  }

  Widget _driverInfoCard() {
    final plate = _drivers.firstWhere(
      (d) => d['id'] == widget.data['assignedTo'],
      orElse: () => {'plate': '-'},
    )['plate'];

    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: _sectionBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("Şoför & Notlar"),
          const SizedBox(height: 10),
          _displayRow("Şoför", _driverNameFor(widget.data['assignedTo'])),
          _displayRow("Plaka", plate ?? "-"),
          _displayRow(
              "Notlar", _notesCtrl.text.isEmpty ? "-" : _notesCtrl.text),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EDIT MODE
  // ---------------------------------------------------------------------------
  Widget _buildEditMode(bool isWide) {
    final left = Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _sectionBox(),
        child: Column(
          children: [
            _sectionTitle("İş Bilgileri"),
            const SizedBox(height: 10),
            TextField(controller: _cargoCtrl, decoration: _input("Yük")),
            const SizedBox(height: 10),
            TextField(
                controller: _loadCtrl, decoration: _input("Yükleme Noktası")),
            const SizedBox(height: 10),
            TextField(
                controller: _unloadCtrl, decoration: _input("Varış Noktası")),
          ],
        ),
      ),
    );

    final right = Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _sectionBox(),
        child: Column(
          children: [
            _sectionTitle("Şoför & Notlar"),
            const SizedBox(height: 10),
            _driversLoading
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<String>(
                    value: _selectedDriverId,
                    decoration: _input("Şoför"),
                    items: _drivers
                        .map(
                          (d) => DropdownMenuItem(
                            value: d['id'],
                            child: Text("${d['name']}  (${d['plate']})"),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDriverId = v),
                  ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: _input("Notlar"),
            ),
          ],
        ),
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Kaydet"),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton(
                onPressed:
                    _saving ? null : () => setState(() => _editing = false),
                child: const Text("İptal"),
              ),
            ),
          ],
        )
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SMALL HELPERS
  // ---------------------------------------------------------------------------
  BoxDecoration _sectionBox() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.grey.shade300),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700));
  }

  Widget _displayRow(String label, String value) {
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
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xfffafafa),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(value.isNotEmpty ? value : "-"),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
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
