import 'package:flutter/material.dart';
import 'package:lojistik/models/mission_model.dart';
import 'package:lojistik/services/mission_service.dart';
import 'package:lojistik/widgets/driver_document_upload_sheet.dart';

class MissionOverlay extends StatefulWidget {
  final MissionModel mission;

  const MissionOverlay({super.key, required this.mission});

  @override
  State<MissionOverlay> createState() => _MissionOverlayState();
}

class _MissionOverlayState extends State<MissionOverlay>
    with SingleTickerProviderStateMixin {
  static const _accent = Color(0xFF1E3A5F);
  static const _green = Color(0xFF16A34A);
  static const _red = Color(0xFFDC2626);
  static const _orange = Color(0xFFEA580C);

  bool _loading = false;
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() => _loading = true);
    try {
      await MissionService.acceptMission(widget.mission.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _loading = true);
    try {
      await MissionService.rejectMission(widget.mission.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _complete() async {
    // Step 1: Evrak yükleme sheet'ini aç — kapatılamaz, sürüklenemez.
    final uploaded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => DriverDocumentUploadSheet(
        jobId: widget.mission.id,
      ),
    );

    // Şoför "Seferi Tamamla" butonuna basmadan kapattıysa işlem durur.
    if (uploaded != true || !mounted) return;

    // Step 2: Evrak yüklendi → Firestore'da seferi completed yap.
    setState(() => _loading = true);
    try {
      await MissionService.completeMission(widget.mission.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            backgroundColor: _green,
            duration: const Duration(seconds: 4),
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Teslimat başarıyla tamamlandı, evraklar merkeze iletildi!',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnim,
      child: widget.mission.isPending
          ? _PendingMissionCard(
              mission: widget.mission,
              loading: _loading,
              onAccept: _accept,
              onReject: _reject,
            )
          : _ActiveMissionCard(
              mission: widget.mission,
              loading: _loading,
              onComplete: _complete,
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pending card — "Yeni Sefer Atandı!"
// ---------------------------------------------------------------------------

class _PendingMissionCard extends StatelessWidget {
  final MissionModel mission;
  final bool loading;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _PendingMissionCard({
    required this.mission,
    required this.loading,
    required this.onAccept,
    required this.onReject,
  });

  static const _accent = Color(0xFF1E3A5F);
  static const _green = Color(0xFF16A34A);
  static const _red = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final route = mission.routeDetails;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'YENİ SEFER ATANDI',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Kabul etmek veya reddetmek için seçin',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Route details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _RouteRow(
                  icon: Icons.trip_origin,
                  iconColor: _green,
                  label: 'Kalkış',
                  value: route.origin.isEmpty ? '—' : route.origin,
                ),
                _RouteDivider(),
                _RouteRow(
                  icon: Icons.location_on,
                  iconColor: _red,
                  label: 'Varış',
                  value: route.destination.isEmpty ? '—' : route.destination,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.straighten,
                        label: '${route.distanceKm.toStringAsFixed(0)} km',
                        sublabel: 'Mesafe',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.schedule,
                        label: route.duration.isEmpty ? '—' : route.duration,
                        sublabel: 'Süre',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.scale,
                        label: '${mission.cargoTonnage.toStringAsFixed(1)} t',
                        sublabel: 'Tonaj',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'Reddet',
                          icon: Icons.close,
                          color: _red,
                          onTap: onReject,
                          outlined: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: _ActionButton(
                          label: 'Seferi Kabul Et',
                          icon: Icons.check,
                          color: _green,
                          onTap: onAccept,
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

// ---------------------------------------------------------------------------
// Active mission card — "Aktif Sefer"
// ---------------------------------------------------------------------------

class _ActiveMissionCard extends StatelessWidget {
  final MissionModel mission;
  final bool loading;
  final VoidCallback onComplete;

  const _ActiveMissionCard({
    required this.mission,
    required this.loading,
    required this.onComplete,
  });

  static const _orange = Color(0xFFEA580C);
  static const _green = Color(0xFF16A34A);
  static const _red = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final route = mission.routeDetails;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            decoration: BoxDecoration(
              color: _orange,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_car, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'AKTİF SEFER',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Sefer devam ediyor',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Devam Ediyor',
                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _RouteRow(
                  icon: Icons.trip_origin,
                  iconColor: _green,
                  label: 'Kalkış',
                  value: route.origin.isEmpty ? '—' : route.origin,
                ),
                _RouteDivider(),
                _RouteRow(
                  icon: Icons.location_on,
                  iconColor: _red,
                  label: 'Varış',
                  value: route.destination.isEmpty ? '—' : route.destination,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.straighten,
                        label: '${route.distanceKm.toStringAsFixed(0)} km',
                        sublabel: 'Mesafe',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoChip(
                        icon: Icons.scale,
                        label: '${mission.cargoTonnage.toStringAsFixed(1)} t',
                        sublabel: 'Tonaj',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _ActionButton(
                    label: 'Teslimatı Tamamla',
                    icon: Icons.check_circle_outline,
                    color: _green,
                    onTap: onComplete,
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ],
    );
  }
}

class _RouteDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 9, top: 2, bottom: 2),
      child: Column(
        children: List.generate(
          4,
          (_) => Container(
            width: 1.5,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 1),
            color: const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF475569)),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          Text(
            sublabel,
            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        onPressed: onTap,
      );
    }
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      onPressed: onTap,
    );
  }
}
