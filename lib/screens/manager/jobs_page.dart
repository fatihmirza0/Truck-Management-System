import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';


import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart'; // MASAÜSTÜ PATH İÇİN
import 'package:path/path.dart' as p;
import 'package:file_picker/file_picker.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter/foundation.dart';


/// ###########################################################
/// #                     JOBS PAGE (MANAGER)                 #
/// ###########################################################

class JobsPage extends StatefulWidget {
  final String managerId;
  const JobsPage({super.key, required this.managerId});

  @override
  State<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends State<JobsPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  String _status = "pending"; // pending | approved | completed
  Map<String, dynamic>? _selectedJob;
  String? _selectedId;

  /// driverId / dispatchId -> name
  final Map<String, String> userCache = {};

  bool get isDesktop => MediaQuery.of(context).size.width > 900;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final snap = await FirebaseFirestore.instance.collection("users").get();
    for (var doc in snap.docs) {
      final data = doc.data();
      if (data["driverId"] != null) {
        userCache[data["driverId"]] = data["name"] ?? "-";
      }
      if (data["dispatchId"] != null) {
        userCache[data["dispatchId"]] = data["name"] ?? "-";
      }
    }
    setState(() {});
  }

  String uname(String? id) => userCache[id] ?? "-";

  Stream<QuerySnapshot> _jobsStream() {
    return FirebaseFirestore.instance
        .collection("jobs")
        .where("status", isEqualTo: _status)
        .orderBy("createdAt", descending: true)
        .snapshots();
  }

  // =================== ONAY & RED ===================
  Future<void> _updateJob(String id, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection("jobs").doc(id).update(data);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("İş güncellendi")),
    );
  }

  Future<void> _approve(String id) => _updateJob(id, {"status": "approved"});
  Future<void> _reject(String id) => _updateJob(id, {"status": "declined"});

  // =================== DETAY AÇMA ===================
  void _openDetail(Map<String, dynamic> job, String id) {
    setState(() {
      _selectedJob = job;
      _selectedId = id;
    });

    // ilk tıklamada açılmama bug'ını engellemek için
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scaffoldKey.currentState?.openEndDrawer();
    });
  }

  // =================== UI ===================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: _selectedJob == null
          ? null
          : JobDetailPanel(
        job: _selectedJob!,
        jobId: _selectedId!,
        uname: uname,
        approve: _approve,
        reject: _reject,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "İşler",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 18),

              /// filtreler
              Row(
                children: [
                  _filterChip("pending", "Onay Bekleyen"),
                  _filterChip("approved", "Yolda"),
                  _filterChip("completed", "Tamamlanan"),
                ],
              ),
              const SizedBox(height: 18),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _jobsStream(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return const Center(child: Text("Henüz iş yok"));
                    }

                    if (isDesktop) {
                      // -------- DESKTOP TABLO --------
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text("Yük")),
                            DataColumn(label: Text("Şoför")),
                            DataColumn(label: Text("Yükleme")),
                            DataColumn(label: Text("Varış")),
                            DataColumn(label: Text("Dispatch")),
                            DataColumn(label: Text("İşlem")),
                          ],
                          rows: docs.map((d) {
                            final j = d.data() as Map<String, dynamic>;
                            return DataRow(
                              cells: [
                                _cell(j["cargoInfo"], () => _openDetail(j, d.id)),
                                _cell(uname(j["assignedTo"]),
                                        () => _openDetail(j, d.id)),
                                _cell(j["loadPort"], () => _openDetail(j, d.id)),
                                _cell(j["unloadPort"], () => _openDetail(j, d.id)),
                                _cell(uname(j["assignedBy"]),
                                        () => _openDetail(j, d.id)),
                                DataCell(
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.visibility),
                                        onPressed: () => _openDetail(j, d.id),
                                      ),
                                      if (_status == "pending") ...[
                                        IconButton(
                                          icon: const Icon(Icons.check,
                                              color: Colors.green),
                                          onPressed: () => _approve(d.id),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.close,
                                              color: Colors.red),
                                          onPressed: () => _reject(d.id),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      );
                    }

                    // -------- MOBİL CARD LİSTE --------
                    return ListView(
                      children: docs.map((d) {
                        final j = d.data() as Map<String, dynamic>;
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            onTap: () => _openDetail(j, d.id),
                            title: Text(
                              j["cargoInfo"] ?? "-",
                              style:
                              const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "${uname(j["assignedTo"])} | ${uname(j["assignedBy"])} • ${j["loadPort"]} → ${j["unloadPort"]}",
                            ),
                            trailing: _status == "pending"
                                ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check,
                                      color: Colors.green),
                                  onPressed: () => _approve(d.id),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.red),
                                  onPressed: () => _reject(d.id),
                                ),
                              ],
                            )
                                : null,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DataCell _cell(dynamic text, VoidCallback onTap) {
    return DataCell(
      GestureDetector(
        onTap: onTap,
        child: Text(text?.toString() ?? "-"),
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final selected = _status == key;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: Colors.blue.withOpacity(.15),
        onSelected: (_) => setState(() => _status = key),
      ),
    );
  }
}

/// ###########################################################
/// #               MODERN SIDE PANEL (Desktop/Mobile)        #
/// ###########################################################

class JobDetailPanel extends StatelessWidget {
  final Map job;
  final String jobId;
  final String Function(String?) uname;
  final Function(String) approve, reject;

  const JobDetailPanel({
    super.key,
    required this.job,
    required this.jobId,
    required this.uname,
    required this.approve,
    required this.reject,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 460,
      child: Column(
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  "İş Detayı",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _info("Yük", job["cargoInfo"]),
                  _info("Şoför", uname(job["assignedTo"])),
                  _info("Yükleme", job["loadPort"]),
                  _info("Varış", job["unloadPort"]),
                  _info("Dispatch", uname(job["assignedBy"])),
                  const SizedBox(height: 16),

                  // Belgeler sadece completed ise
                  if (job["status"] == "completed")
                    buildDocumentsSection(context, job),

                  const SizedBox(height: 26),

                  if (job["status"] == "pending")
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () => reject(jobId),
                          child: const Text(
                            "Reddet",
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => approve(jobId),
                          child: const Text("Onayla"),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          Text(
            value?.toString() ?? "-",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// ###########################################################
/// #           BELGE ALANI + SWIPE GALLERY VIEWER            #
/// ###########################################################

Widget buildDocumentsSection(BuildContext ctx, Map job) {
  final List docs = job["documents"] ?? [];
  if (docs.isEmpty) {
    return const Text("Belge yok");
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      // === Başlık + Tümünü indir butonu ===
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Belgeler",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),

          // Sadece 2+ belge varsa gözüksün
          if (docs.length > 1)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () => _downloadAllFiles(ctx, docs),
              child: Row(
                children: const [
                  Icon(Icons.download, size: 18),
                  SizedBox(width: 6),
                  Text(
                    "Tümünü indir",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )

        ],
      ),

      const SizedBox(height: 12),

      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: docs.length,
        itemBuilder: (c, i) {
          final String url = docs[i];

          return Stack(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                    builder: (_) => FullScreenGalleryViewer(
                      images: docs,
                      initialIndex: i,
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image, size: 40)),
                  ),
                ),
              ),

              Positioned(
                bottom: 8,
                left: 165,
                right: 0,
                child: Center(
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.download,
                          color: Colors.white, size: 20),
                      onPressed: () => _downloadFile(ctx, url),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

/// Tek bir dosyayı indir
Future<void> _downloadFile(BuildContext context, String url) async {
  try {
    final fileName = "${DateTime.now().millisecondsSinceEpoch}.jpg";

    // ================= WEB =================
    if (kIsWeb) {
      await launchUrl(Uri.parse(url));
      return;
    }

    // ================= MOBİL (Bildirimli) =================
    if (Platform.isAndroid || Platform.isIOS) {
      await FlutterDownloader.enqueue(
        url: url,
        savedDir: "/storage/emulated/0/Download",
        fileName: fileName,
        showNotification: true,
        openFileFromNotification: true,
      );
      return;
    }

    // ================= DESKTOP (PATH seçerek kaydetme) =================
    final folder = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Belgelerin kaydedileceği klasörü seç",
    );

    if (folder == null) return;

    final savePath = "$folder/$fileName";
    final req = await http.get(Uri.parse(url));

    final file = File(savePath);
    await file.writeAsBytes(req.bodyBytes);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kaydedildi → $savePath")),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata: $e")),
      );
    }
  }
}
Future<void> _downloadAllFiles(BuildContext context, List files) async {
  try {
    // WEB
    if (kIsWeb) {
      for (var url in files) {
        launchUrl(Uri.parse(url));
      }
      return;
    }

    // MOBİL
    if (Platform.isAndroid || Platform.isIOS) {
      for (var url in files) {
        await FlutterDownloader.enqueue(
          url: url,
          savedDir: "/storage/emulated/0/Download",
          fileName: "${DateTime.now().millisecondsSinceEpoch}.jpg",
          showNotification: true,
          openFileFromNotification: true,
        );
      }
      return;
    }

    // DESKTOP
    final folder = await FilePicker.platform.getDirectoryPath(
      dialogTitle: "Kaydedilecek klasörü Seçin",
    );

    if (folder == null) return;

    for (var url in files) {
      final req = await http.get(Uri.parse(url));
      final name = "${DateTime.now().microsecondsSinceEpoch}.jpg";
      final file = File("$folder/$name");
      await file.writeAsBytes(req.bodyBytes);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Tüm dosyalar indirildi → $folder")),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Toplu indirme hatası: $e")));
    }
  }
}

/// ===================== FULLSCREEN SWIPE GALLERY =====================

class FullScreenGalleryViewer extends StatefulWidget {
  final List images;
  final int initialIndex;

  const FullScreenGalleryViewer({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State createState() => _FullScreenGalleryViewerState();
}

class _FullScreenGalleryViewerState extends State<FullScreenGalleryViewer> {
  late PageController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: ctrl,
            itemCount: widget.images.length,
            itemBuilder: (c, i) => InteractiveViewer(
              child: Image.network(
                widget.images[i],
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            top: 30,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
