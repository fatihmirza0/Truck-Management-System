import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/job_document_model.dart';
import '../../services/auth_service.dart';
import '../../services/job_document_service.dart';

/// Şoför evrak yükleme bottom sheet'i.
///
/// Kullanım:
/// ```dart
/// showModalBottomSheet(
///   context: context,
///   isScrollControlled: true,
///   backgroundColor: Colors.transparent,
///   builder: (_) => DriverDocumentUploadSheet(jobId: job.id),
/// );
/// ```
class DriverDocumentUploadSheet extends StatefulWidget {
  final String jobId;

  const DriverDocumentUploadSheet({super.key, required this.jobId});

  @override
  State<DriverDocumentUploadSheet> createState() =>
      _DriverDocumentUploadSheetState();
}

class _DriverDocumentUploadSheetState
    extends State<DriverDocumentUploadSheet> {
  // ── State ──────────────────────────────────────────────────────────────
  JobDocumentType _selectedType = JobDocumentType.kantarFisi;
  File?   _selectedFile;
  String? _selectedFileName;
  bool    _isUploading = false;
  double  _uploadProgress = 0.0;
  String? _errorMessage;
  String? _successMessage;
  bool    _uploadedOnce = false; // En az bir evrak yüklendi mi?

  // Dispatcher kartı için şoför bilgileri
  String _driverName   = '';
  String _vehiclePlate = '';

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadDriverInfo();
  }

  Future<void> _loadDriverInfo() async {
    // 1. Şoför adı — SharedPreferences cache'den (AuthService.saveUserData ile kaydedilir)
    final userData = await AuthService.getSavedUserData();
    final name = (userData['name'] as String?) ?? '';

    // 2. Araç plakası — şoföre atanmış aracı vehicles koleksiyonundan çek
    String plate = '';
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('vehicles')
            .where('assignedDriverId', isEqualTo: uid)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          plate = (snap.docs.first.data()['plate'] as String?) ?? '';
        }
      } catch (_) {
        // Plaka alınamazsa boş bırak — upload yine de çalışır
      }
    }

    if (mounted) {
      setState(() {
        _driverName   = name;
        _vehiclePlate = plate;
      });
    }
  }

  // ── UI Constants ───────────────────────────────────────────────────────
  static const _navy   = Color(0xFF0D1B2A);
  static const _orange = Color(0xFFFF6B2B);
  static const _green  = Color(0xFF22C55E);
  static const _bgGray = Color(0xFFF8FAFC);

  // ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, 32 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle çubuğu
          Center(
            child: Container(
              width: 44, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),

          // Başlık satırı
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Evrak Yükle',
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Teslimat evraklarını yükleyin, ardından seferi tamamlayın.',
                      style: GoogleFonts.inter(fontSize: 13, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Evrak Tipi Seçimi ─────────────────────────────────────────
          _sectionLabel('Evrak Tipi'),
          const SizedBox(height: 8),
          _buildDocTypeGrid(),

          const SizedBox(height: 24),

          // ── Dosya / Fotoğraf Seçimi ───────────────────────────────────
          _sectionLabel('Dosya Seç'),
          const SizedBox(height: 10),
          _buildFilePickerButtons(),

          // Seçilen dosya önizlemesi
          if (_selectedFile != null) ...[
            const SizedBox(height: 12),
            _buildFilePreview(),
          ],

          const SizedBox(height: 24),

          // Progress bar
          if (_isUploading) ...[
            _buildProgressBar(),
            const SizedBox(height: 16),
          ],

          // Hata / başarı mesajı
          if (_errorMessage != null) _buildBanner(_errorMessage!, isError: true),
          if (_successMessage != null) _buildBanner(_successMessage!, isError: false),

          const SizedBox(height: 8),

          // ── Yükle Butonu ──────────────────────────────────────────────
          _buildUploadButton(),

          // ── Yüklenen Evraklar (stream) ────────────────────────────────
          const SizedBox(height: 28),
          _sectionLabel('Bu İşe Ait Evraklar'),
          const SizedBox(height: 10),
          _buildDocumentList(),

          // ── Seferi Tamamla (yalnızca evrak yüklenince aktif olur) ────
          const SizedBox(height: 28),
          _buildCompleteButton(),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Widget Builders
  // ───────────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Text(
    text,
    style: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Colors.grey.shade500,
      letterSpacing: 0.8,
    ),
  );

  Widget _buildDocTypeGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: JobDocumentType.values.map((type) {
        final selected = type == _selectedType;
        return GestureDetector(
          onTap: _isUploading ? null : () => setState(() {
            _selectedType = type;
            _clearMessages();
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? _navy : _bgGray,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? _navy : Colors.grey.shade200,
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(type.emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  type.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : _navy,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFilePickerButtons() {
    return Row(
      children: [
        Expanded(
          child: _pickerButton(
            icon: Icons.camera_alt_rounded,
            label: 'Kamera',
            color: _orange,
            onTap: _isUploading ? null : _pickFromCamera,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _pickerButton(
            icon: Icons.photo_library_rounded,
            label: 'Galeri',
            color: const Color(0xFF6366F1),
            onTap: _isUploading ? null : _pickFromGallery,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _pickerButton(
            icon: Icons.description_rounded,
            label: 'PDF',
            color: const Color(0xFFEF4444),
            onTap: _isUploading ? null : _pickPdf,
          ),
        ),
      ],
    );
  }

  Widget _pickerButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onTap == null ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          alignment: Alignment.center,
          child: Column(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePreview() {
    final ext = _selectedFileName?.split('.').last.toLowerCase() ?? '';
    final isPdf = ext == 'pdf';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bgGray,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: isPdf
                ? Container(
                    width: 56, height: 56,
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    alignment: Alignment.center,
                    child: const Icon(Icons.picture_as_pdf,
                        color: Color(0xFFEF4444), size: 32),
                  )
                : Image.file(_selectedFile!,
                    width: 56, height: 56, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedFileName ?? 'Dosya',
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _navy),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${(_selectedFile!.lengthSync() / 1024).toStringAsFixed(1)} KB',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.grey),
            onPressed: _isUploading
                ? null
                : () => setState(() {
                    _selectedFile = null;
                    _selectedFileName = null;
                    _clearMessages();
                  }),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Yükleniyor…',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _navy),
            ),
            Text(
              '%${(_uploadProgress * 100).toInt()}',
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _orange),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: _uploadProgress,
            backgroundColor: Colors.grey.shade200,
            color: _orange,
            minHeight: 8,
          ),
        ),
      ],
    );
  }

  Widget _buildBanner(String message, {required bool isError}) {
    final color = isError ? const Color(0xFFEF4444) : _green;
    final icon  = isError ? Icons.error_outline : Icons.check_circle_outline;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: GoogleFonts.inter(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadButton() {
    final canUpload = _selectedFile != null && !_isUploading;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 56,
      child: ElevatedButton.icon(
        onPressed: canUpload ? _upload : null,
        icon: _isUploading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.cloud_upload_rounded, size: 22),
        label: Text(
          _isUploading ? 'Yükleniyor…' : 'Evrakı Yükle',
          style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: canUpload ? _orange : Colors.grey.shade300,
          foregroundColor: Colors.white,
          elevation: canUpload ? 2 : 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  Widget _buildCompleteButton() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _uploadedOnce
          ? FilledButton.icon(
              key: const ValueKey('complete-btn'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 22),
              label: Text(
                'Seferi Tamamla',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              onPressed: () => Navigator.pop(context, true),
            )
          : Container(
              key: const ValueKey('complete-hint'),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'En az bir evrak yükledikten sonra seferi tamamlayabilirsiniz.',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDocumentList() {
    return StreamBuilder<List<JobDocument>>(
      stream: JobDocumentService.streamDocuments(widget.jobId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: CircularProgressIndicator(strokeWidth: 2),
          ));
        }

        final docs = snapshot.data ?? [];

        if (docs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                'Henüz evrak yüklenmemiş.',
                style: GoogleFonts.inter(
                    fontSize: 13, color: Colors.grey.shade400),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _buildDocItem(docs[i]),
        );
      },
    );
  }

  Widget _buildDocItem(JobDocument doc) {
    final type    = JobDocumentType.fromValue(doc.type);
    final statusColor = switch (doc.status) {
      'approved' => _green,
      'rejected' => const Color(0xFFEF4444),
      _          => const Color(0xFFF59E0B), // pending → amber
    };
    final statusLabel = switch (doc.status) {
      'approved' => 'Onaylandı',
      'rejected' => 'Reddedildi',
      _          => 'Bekliyor',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _bgGray,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Text(type.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.label,
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _navy)),
                const SizedBox(height: 2),
                Text(
                  doc.uploadedAt != null
                      ? _formatDate(doc.uploadedAt!)
                      : 'Tarih bilinmiyor',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              statusLabel,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Actions
  // ───────────────────────────────────────────────────────────────────────

  Future<void> _pickFromCamera() async {
    _clearMessages();
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;
    setState(() {
      _selectedFile     = File(picked.path);
      _selectedFileName = picked.name;
    });
  }

  Future<void> _pickFromGallery() async {
    _clearMessages();
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
    );
    if (picked == null) return;
    setState(() {
      _selectedFile     = File(picked.path);
      _selectedFileName = picked.name;
    });
  }

  Future<void> _pickPdf() async {
    _clearMessages();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    final pf = result.files.first;
    if (pf.path == null) return;
    setState(() {
      _selectedFile     = File(pf.path!);
      _selectedFileName = pf.name;
    });
  }

  Future<void> _upload() async {
    if (_selectedFile == null) return;
    setState(() {
      _isUploading    = true;
      _uploadProgress = 0.0;
      _errorMessage   = null;
      _successMessage = null;
    });

    try {
      await JobDocumentService.uploadDocument(
        file:         _selectedFile!,
        jobId:        widget.jobId,
        docType:      _selectedType,
        driverName:   _driverName,
        vehiclePlate: _vehiclePlate,
        onProgress:   (p) => setState(() => _uploadProgress = p),
      );

      setState(() {
        _isUploading      = false;
        _uploadProgress   = 0.0;
        _selectedFile     = null;
        _selectedFileName = null;
        _uploadedOnce     = true;
        _successMessage   = '${_selectedType.label} başarıyla yüklendi ve onaya gönderildi.';
      });
    } catch (e) {
      setState(() {
        _isUploading  = false;
        _errorMessage = 'Yükleme başarısız: $e';
      });
    }
  }

  void _clearMessages() {
    _errorMessage   = null;
    _successMessage = null;
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}'
        '.${dt.month.toString().padLeft(2, '0')}'
        '.${dt.year}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
