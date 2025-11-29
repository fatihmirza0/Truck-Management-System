import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  late TextEditingController _cargoCtrl;
  late TextEditingController _loadCtrl;
  late TextEditingController _unloadCtrl;
  late TextEditingController _notesCtrl;

  bool _editing = false;
  bool _saving = false;

  // driver list
  bool _driversLoading = true;
  List<Map<String, String>> _drivers = []; // [{id: driver123, name: Ali}, ...]
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

  Future<void> _loadDrivers() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('roleId', isEqualTo: 'driver')
          .get();

      _drivers = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': (data['driverId'] ?? '').toString(),
          'name': (data['name'] ?? '').toString(),
        };
      }).where((e) => e['id']!.isNotEmpty).toList();
    } catch (e) {
      debugPrint('driver load error: $e');
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
      // fallback: jobs dokümanında assignedToName varsa onu kullan
      return (widget.data['assignedToName'] ?? id).toString();
    }
    return match['name'] ?? id;
  }

  InputDecoration _input(String label) {
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
        borderSide: const BorderSide(color: _accent, width: 2),
      ),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Future<void> _save() async {
    if (_selectedDriverId == null || _selectedDriverId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir şoför seçin.')),
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
        'assignedToName': driverName, // kolay gösterim için
        // reddedilen iş yeniden gönderildiğinde pending
        if (widget.data['status'] == 'declined') 'status': 'pending',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _editing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İş başarıyla güncellendi.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kaydetme hatası: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cancelEdit() {
    setState(() {
      _editing = false;
      _cargoCtrl.text = widget.data['cargoInfo'] ?? '';
      _loadCtrl.text = widget.data['loadPort'] ?? '';
      _unloadCtrl.text = widget.data['unloadPort'] ?? '';
      _notesCtrl.text = widget.data['notes'] ?? '';
      _selectedDriverId = widget.data['assignedTo'];
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 850;
    final status = (widget.data['status'] ?? '').toString();

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 60 : 20,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'İş Detayı',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (widget.canEdit && !_editing)
                    IconButton(
                      tooltip: 'Düzenle',
                      onPressed: () => setState(() => _editing = true),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                ],
              ),
              const SizedBox(height: 20),

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
                        // Başlık + durum
                        Row(
                          children: [
                            const Text(
                              'İş Bilgileri',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            _statusChip(status),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // -------- VIEW MODE --------
                        if (!_editing) ...[
                          _displayRow('Yük', _cargoCtrl.text),
                          _displayRow('Yükleme', _loadCtrl.text),
                          _displayRow('Varış', _unloadCtrl.text),
                          _displayRow('Şoför',
                              _driverNameFor(widget.data['assignedTo'])),
                          _displayRow('Notlar', _notesCtrl.text),
                          _displayRow(
                            'Oluşturma',
                            widget.data['createdAt'] != null
                                ? widget.data['createdAt']
                                .toDate()
                                .toString()
                                .substring(0, 16)
                                : '-',
                          ),
                          if (widget.canEdit)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                'Düzenlemek için sağ üstteki kalem ikonuna tıklayın.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.black45,
                                ),
                              ),
                            ),
                        ],

                        // -------- EDIT MODE --------
                        if (_editing) ...[
                          TextField(
                            controller: _cargoCtrl,
                            decoration: _input('Yük'),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _loadCtrl,
                            decoration: _input('Yükleme'),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _unloadCtrl,
                            decoration: _input('Varış'),
                          ),
                          const SizedBox(height: 14),

                          // ŞOFÖR SEÇİMİ
                          _driversLoading
                              ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: LinearProgressIndicator(minHeight: 2),
                          )
                              : DropdownButtonFormField<String>(
                            value: _selectedDriverId,
                            decoration: _input('Şoför'),
                            items: _drivers
                                .map(
                                  (d) => DropdownMenuItem<String>(
                                value: d['id'],
                                child: Text(d['name'] ?? '-'),
                              ),
                            )
                                .toList(),
                            onChanged: (val) {
                              setState(() => _selectedDriverId = val);
                            },
                          ),

                          const SizedBox(height: 14),
                          TextField(
                            controller: _notesCtrl,
                            maxLines: 3,
                            decoration: _input('Notlar'),
                          ),
                          const SizedBox(height: 24),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _saving ? null : _save,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _accent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _saving
                                      ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                      : const Text(
                                    'Kaydet',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _saving ? null : _cancelEdit,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    side: BorderSide(
                                        color: Colors.grey.shade300),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text(
                                    'İptal',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
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
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _displayRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(
              value.isNotEmpty ? value : '-',
              style: const TextStyle(fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg, text;

    switch (status) {
      case 'pending':
        bg = Colors.orange.shade100;
        text = Colors.orange.shade800;
        break;
      case 'declined':
        bg = Colors.red.shade100;
        text = Colors.red.shade800;
        break;
      case 'approved':
      case 'completed':
        bg = Colors.green.shade100;
        text = Colors.green.shade800;
        break;
      default:
        bg = Colors.grey.shade200;
        text = Colors.grey.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.isEmpty ? '-' : status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }
}
