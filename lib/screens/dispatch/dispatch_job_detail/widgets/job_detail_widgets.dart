import 'package:flutter/material.dart';
import 'package:lojistik/services/firestore_service.dart';
import 'storage_helper.dart';

/// İş durumu chip'i
class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final statusColor = FirestoreService.getStatusColor(status);
    final statusText = FirestoreService.getStatusText(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bilgi kartı widget'ı
class InfoCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const InfoCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF475569)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// İş referans kartı
class JobReferenceCard extends StatelessWidget {
  final String referenceNo;

  const JobReferenceCard({super.key, required this.referenceNo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.confirmation_number_outlined,
              size: 22,
              color: Color(0xFF1E3A5F),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  referenceNo,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A5F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'İş Referans Numarası (Değiştirilemez)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Yük bilgileri kartı
class CargoInfoCard extends StatelessWidget {
  final Map<String, dynamic>? cargo;

  const CargoInfoCard({super.key, this.cargo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Yük Bilgileri',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Yük Türü',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      cargo?['type'] ?? '-',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ağırlık',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${cargo?['weightKg'] ?? '-'} kg',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Açıklama',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                cargo?['description'] ?? '-',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Reddetme sebebi kartı
class RejectionReasonCard extends StatelessWidget {
  final String reason;

  const RejectionReasonCard({super.key, required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(Icons.info_outline, size: 18, color: Colors.red),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Reddetme Sebebi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reason,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Evrak bilgileri kartı
class DocumentsCard extends StatelessWidget {
  final List<dynamic> documents;
  final String referenceNo;
  final bool showDebug;

  const DocumentsCard({
    super.key,
    required this.documents,
    required this.referenceNo,
    this.showDebug = false,
  });

  Future<void> _downloadAllDocuments(BuildContext context) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Belgeler indiriliyor...'),
                ],
              ),
            ),
          ),
        ),
      );

      int successCount = 0;
      int totalCount = documents.length;

      for (int i = 0; i < documents.length; i++) {
        final doc = documents[i];
        final docMap = doc is String
            ? {'url': doc, 'documentNo': 'Belge ${i + 1}'}
            : (doc as Map<String, dynamic>);

        try {
          final urlData = docMap['url'];
          String? storageUrl;

          if (urlData is String) {
            storageUrl = urlData;
          } else if (urlData is Map && urlData.containsKey('url')) {
            storageUrl = urlData['url'] as String?;
          }

          if (storageUrl != null && storageUrl.isNotEmpty) {
            final downloadUrl = await StorageHelper.getDownloadUrl(storageUrl);

            // Dosya adını oluştur
            final fileName = documents.length > 1
                ? '${referenceNo}_${i + 1}'
                : referenceNo;

            await StorageHelper.downloadFile(downloadUrl, fileName);
            successCount++;
          }
        } catch (e) {
          debugPrint('Download error for document $i: $e');
          // İptal edildi hatası ise döngüyü kır
          if (e.toString().contains('iptal')) {
            break;
          }
        }
      }

      if (context.mounted) {
        Navigator.pop(context); // Loading dialog'u kapat

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              successCount == totalCount
                  ? 'Tüm belgeler indirildi ($successCount/$totalCount)'
                  : successCount > 0
                  ? 'Bazı belgeler indirildi ($successCount/$totalCount)'
                  : 'İndirme iptal edildi',
            ),
            backgroundColor: successCount == totalCount
                ? Colors.green
                : successCount > 0
                ? Colors.orange
                : Colors.grey,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        if (!e.toString().contains('iptal')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Evrak Bilgileri',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.green,
                  ),
                ),
              ),
              // Tümünü İndir Butonu
              if (documents.length > 1)
                ElevatedButton.icon(
                  onPressed: () => _downloadAllDocuments(context),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Tümünü İndir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...documents.asMap().entries.map((entry) {
            final index = entry.key;
            final doc = entry.value;

            final docMap = doc is String
                ? {'url': doc, 'documentNo': 'Belge ${index + 1}'}
                : (doc as Map<String, dynamic>);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DocumentInfoItem(
                document: docMap,
                index: index + 1,
                referenceNo: referenceNo,
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Evrak bilgisi satırı - KOMPAKT GÖRÜNTÜLEME
class DocumentInfoItem extends StatefulWidget {
  final Map<String, dynamic> document;
  final int index;
  final String referenceNo;

  const DocumentInfoItem({
    super.key,
    required this.document,
    required this.referenceNo,
    this.index = 1,
  });

  @override
  State<DocumentInfoItem> createState() => _DocumentInfoItemState();
}

class _DocumentInfoItemState extends State<DocumentInfoItem> {
  bool _loading = false;
  bool _downloading = false;
  String? _downloadUrl;

  String? _getUrlFromDocument() {
    final urlData = widget.document['url'];

    if (urlData is String) return urlData;

    if (urlData is Map) {
      if (urlData.containsKey('url')) return urlData['url'] as String?;
      if (urlData.containsKey('downloadUrl')) return urlData['downloadUrl'] as String?;
      if (urlData.containsKey('path')) return urlData['path'] as String?;
    }

    if (urlData is List && urlData.isNotEmpty) {
      final first = urlData.first;
      if (first is String) return first;
      if (first is Map && first.containsKey('url')) return first['url'] as String?;
    }

    return null;
  }

  Future<void> _loadUrl() async {
    if (_downloadUrl != null) return;
    if (_loading) return;

    setState(() => _loading = true);

    try {
      final storageUrl = _getUrlFromDocument();
      if (storageUrl == null || storageUrl.isEmpty) {
        throw Exception('Belge URL\'si bulunamadı');
      }

      final url = await StorageHelper.getDownloadUrl(storageUrl);
      if (mounted) {
        setState(() {
          _downloadUrl = url;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('URL yüklenemedi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadDocument() async {
    if (_downloading) return;

    setState(() => _downloading = true);

    try {
      String? urlToDownload = _downloadUrl;

      if (urlToDownload == null) {
        final storageUrl = _getUrlFromDocument();
        if (storageUrl == null || storageUrl.isEmpty) {
          throw Exception('Belge URL\'si bulunamadı');
        }
        urlToDownload = await StorageHelper.getDownloadUrl(storageUrl);
        _downloadUrl = urlToDownload;
      }

      // Dosya adını oluştur
      final fileName = '${widget.referenceNo}_${widget.index}';

      await StorageHelper.downloadFile(urlToDownload, fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Belge indirildi'),
            backgroundColor: Colors.green,
          ),
        );
      }
        } catch (e) {
      if (mounted) {
        // İptal hatası mesajını gösterme
        if (!e.toString().contains('iptal')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('İndirme hatası: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _downloading = false);
      }
    }
  }

  void _showFullScreen() {
    if (_downloadUrl == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  _downloadUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  @override
  Widget build(BuildContext context) {
    final urlExists = _getUrlFromDocument() != null;
    final isImage = _downloadUrl?.toLowerCase().contains(RegExp(r'\.(jpg|jpeg|png|gif|webp)')) ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          // Thumbnail - sadece görsel için
          if (urlExists && isImage && _downloadUrl != null && !_loading)
            GestureDetector(
              onTap: _showFullScreen,
              child: Container(
                width: 60,
                height: 60,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        _downloadUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[100],
                            child: const Icon(Icons.broken_image, size: 24, color: Colors.grey),
                          );
                        },
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.3)],
                          ),
                        ),
                      ),
                      const Center(
                        child: Icon(Icons.zoom_in, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (urlExists && !isImage)
            Container(
              width: 60,
              height: 60,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Icon(
                _downloadUrl?.toLowerCase().contains('.pdf') ?? false
                    ? Icons.picture_as_pdf
                    : Icons.insert_drive_file,
                color: Colors.blue,
                size: 30,
              ),
            ),

          // Belge bilgileri
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.document['documentNo'] ?? 'Belge ${widget.index}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                if (widget.document['documentType'] != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.document['documentType'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (widget.document['notes'] != null && widget.document['notes'].toString().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.document['notes'],
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Butonlar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (urlExists && isImage)
                IconButton(
                  onPressed: _showFullScreen,
                  icon: const Icon(Icons.fullscreen, size: 20),
                  tooltip: 'Tam Ekran',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.withValues(alpha: 0.1),
                  ),
                ),
              if (urlExists)
                IconButton(
                  onPressed: _downloading ? null : _downloadDocument,
                  icon: _downloading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.download, size: 20),
                  tooltip: 'İndir',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Form text field'ı
class JobFormTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final int maxLines;
  final String? hintText;

  const JobFormTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.enabled = true,
    this.maxLines = 1,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF475569),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            maxLines: maxLines,
            decoration: InputDecoration(
              prefixIcon: maxLines == 1 ? Icon(icon, size: 20, color: const Color(0xFF64748B)) : null,
              hintText: hintText,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

/// Şoför dropdown widget'ı
class DriverDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> drivers;
  final String? selectedDriverId;
  final ValueChanged<String?> onChanged;

  const DriverDropdown({
    super.key,
    required this.drivers,
    required this.selectedDriverId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Şoför *', style: TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: selectedDriverId,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down),
              hint: Row(
                children: [
                  const Icon(Icons.person_outline, size: 20, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text('Şoför seçin...', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              items: drivers.map((driver) {
                return DropdownMenuItem<String>(
                  value: driver['uid'],
                  child: Text(driver['name'] ?? ''),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// Araç dropdown widget'ı
class VehicleDropdown extends StatelessWidget {
  final List<Map<String, dynamic>> vehicles;
  final String? selectedVehicleId;
  final String? selectedDriverId;
  final ValueChanged<String?>? onChanged;

  const VehicleDropdown({
    super.key,
    required this.vehicles,
    required this.selectedVehicleId,
    required this.selectedDriverId,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasDriver = selectedDriverId != null;
    final hasVehicles = vehicles.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Araç *', style: TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<String>(
              value: selectedVehicleId,
              isExpanded: true,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down),
              hint: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 20, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  if (!hasDriver)
                    Text('Önce şoför seçin...', style: TextStyle(color: Colors.grey[600]))
                  else if (!hasVehicles)
                    Text('Bu şoföre ait araç yok', style: TextStyle(color: Colors.orange[600]))
                  else
                    Text('Araç seçin...', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
              items: vehicles.map((vehicle) {
                return DropdownMenuItem<String>(
                  value: vehicle['vehicleId'],
                  child: Text('${vehicle['plate']} (${vehicle['type']})'),
                );
              }).toList(),
              onChanged: (!hasDriver || !hasVehicles) ? null : onChanged,
            ),
          ),
        ),
        if (hasDriver && !hasVehicles)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Seçili şoföre ait aktif araç bulunmuyor',
              style: TextStyle(fontSize: 12, color: Colors.orange[600]),
            ),
          ),
      ],
    );
  }
}