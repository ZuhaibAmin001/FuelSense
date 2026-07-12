import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';
import 'welcome_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _tab = 0;
  List<Map<String, dynamic>> _stations = [];
  bool _loading = true;
  String? _err;
  Position? _pos;
  Timer? _timer;
  Timer? _locationTimer;
  final _mapCtrl = MapController();
  Map<String, dynamic>? _selected;
  Map<String, dynamic>? _user;
  bool _crisisMode = false;
  String _filterStatus = 'ALL';
  Map<String, dynamic>? _routeTarget;

  // ── OSRM route points (replaces straight line) ──
  List<LatLng> _routePoints = [];
  bool _routeLoading = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _user = await ApiService.getSavedUser();
    await _getLocation();
    await _loadStations();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _loadStations());
    _locationTimer = Timer.periodic(const Duration(seconds: 10), (_) => _getLocation());
  }

  Future<void> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
if (mounted) {
  setState(() => _pos = pos);
  _mapCtrl.move(LatLng(pos.latitude, pos.longitude), _mapCtrl.camera.zoom);
}
    } catch (_) {}
  }

  Future<void> _loadStations() async {
    final r = await ApiService.getAllStations();
    if (!mounted) return;
    if (r.success) {
      setState(() {
        _stations = List<Map<String, dynamic>>.from(r.data);
        _loading = false;
        _err = null;
      });
    } else {
      setState(() { _loading = false; _err = r.error; });
    }
  }

  // ─────────────────────────────────────────────
  // OSRM: fetch real road route between two points
  // ─────────────────────────────────────────────
  Future<void> _fetchRoute(double fromLat, double fromLng, double toLat, double toLng) async {
    setState(() { _routeLoading = true; _routePoints = []; });
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '$fromLng,$fromLat;$toLng,$toLat'
        '?overview=full&geometries=geojson',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final coords = body['routes'][0]['geometry']['coordinates'] as List;
        final points = coords.map<LatLng>((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble())).toList();
        if (mounted) setState(() => _routePoints = points);
      }
    } catch (_) {
      // Fallback: straight line if OSRM unreachable
      if (mounted) {
        setState(() => _routePoints = [
          LatLng(fromLat, fromLng),
          LatLng(toLat, toLng),
        ]);
      }
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredStations {
    var list = [..._stations];
    if (_crisisMode) list = list.where((s) => s['has_fuel'] == true).toList();
    if (_filterStatus != 'ALL') list = list.where((s) => s['status'] == _filterStatus).toList();
    return list;
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'RED': return const Color(0xFFEF4444);
      case 'YELLOW': return const Color(0xFFF59E0B);
      default: return const Color(0xFF10B981);
    }
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'RED': return 'Very Busy';
      case 'YELLOW': return 'Busy';
      default: return 'Available';
    }
  }

  IconData _statusIcon(String s) {
    switch (s) {
      case 'RED': return Icons.block_rounded;
      case 'YELLOW': return Icons.warning_amber_rounded;
      default: return Icons.check_circle_rounded;
    }
  }

  int _driveMinutes(Map s) {
    if (_pos == null) return 0;
    final dist = const Distance().as(
      LengthUnit.Kilometer,
      LatLng(_pos!.latitude, _pos!.longitude),
      LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble()),
    );
    return (dist / 0.5).round();
  }

  String get _firstName {
    final full = _user?['full_name'] ?? '';
    return full.toString().split(' ').first;
  }

  // ─────────────────────────────────────────────
  // Navigate: fetch OSRM route then show on map
  // ─────────────────────────────────────────────
  void _navigateInApp(Map s) {
    final toLat = (s['lat'] as num).toDouble();
    final toLng = (s['lng'] as num).toDouble();
    setState(() {
      _routeTarget = Map<String, dynamic>.from(s);
      _tab = 0;
      _selected = null;
    });
    _mapCtrl.move(LatLng(toLat, toLng), 13);
    if (_pos != null) {
      _fetchRoute(_pos!.latitude, _pos!.longitude, toLat, toLng);
    }
  }

  void _shareStation(Map s) {
    Share.share(
      '🚗 ${s['name']} — ${s['vehicles']} vehicles in queue\n'
      '⏱️ Est. wait: ~${s['wait_minutes']} min\n'
      '📍 ${s['address']}\n\nPowered by FuelSense',
    );
  }

  // ─────────────────────────────────────────────
  // Direct call — opens dialer immediately,
  // does NOT open Contacts app
  // ─────────────────────────────────────────────
  Future<void> _callNumber(String num) async {
    final cleaned = num.replaceAll(' ', '').replaceAll('-', '');
    final uri = Uri.parse('tel:$cleaned');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not dial $num'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: Column(children: [
        _buildHeader(),
        if (_crisisMode) _buildCrisisBanner(),
        Expanded(child: IndexedStack(index: _tab, children: [
          _buildMapTab(),
          _buildListTab(),
          _buildSmartRouteTab(),
          _buildEmergencyTab(),
        ])),
        _buildBottomNav(),
      ]),
    );
  }

  Widget _buildHeader() {
    final greenCount = _stations.where((s) => s['status'] == 'GREEN').length;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D1425),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 14, right: 14, bottom: 12,
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
          ),
          child: const Icon(Icons.local_gas_station_rounded, color: Color(0xFF2563EB), size: 16),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          if (_firstName.isNotEmpty)
            Text('Hello, $_firstName', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
          const Text('FuelSense', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _crisisMode = !_crisisMode),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: _crisisMode ? const Color(0xFFEF4444).withOpacity(0.15) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _crisisMode ? const Color(0xFFEF4444).withOpacity(0.4) : Colors.white.withOpacity(0.08)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🚨', style: TextStyle(fontSize: 11)),
              const SizedBox(width: 3),
              Text('Crisis', style: TextStyle(color: _crisisMode ? const Color(0xFFEF4444) : Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(width: 6),
        if (!_loading && _stations.isNotEmpty)
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1 * _pulseAnim.value),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: Row(children: [
                Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('$greenCount free', style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: _showProfileSheet,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
            ),
            child: const Icon(Icons.person_rounded, color: Color(0xFF2563EB), size: 16),
          ),
        ),
      ]),
    );
  }

  Widget _buildCrisisBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFEF4444).withOpacity(0.12),
      child: Row(children: [
        const Text('🚨', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
        const Expanded(child: Text('CRISIS MODE — Only stations with fuel shown', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600))),
        GestureDetector(onTap: () => setState(() => _crisisMode = false), child: const Icon(Icons.close_rounded, color: Color(0xFFEF4444), size: 16)),
      ]),
    );
  }

  Widget _buildMapTab() {
    final center = _pos != null ? LatLng(_pos!.latitude, _pos!.longitude) : const LatLng(33.5447, 73.1827);
    final filtered = _filteredStations;

    return Stack(children: [
      FlutterMap(
        mapController: _mapCtrl,
        options: MapOptions(
          initialCenter: center,
          initialZoom: 13,
          onTap: (_, __) => setState(() { _selected = null; _routeTarget = null; _routePoints = []; }),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.fuelsense.app',
            tileProvider: CancellableNetworkTileProvider(),
          ),
          // User location dot
          if (_pos != null) MarkerLayer(markers: [
            Marker(
              point: LatLng(_pos!.latitude, _pos!.longitude),
              width: 28, height: 28,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.5), blurRadius: 14)],
                ),
              ),
            ),
          ]),
          // ── Real road route from OSRM ──
          if (_routePoints.length >= 2) PolylineLayer(polylines: [
            // Shadow / outline
            Polyline(
              points: _routePoints,
              strokeWidth: 7,
              color: Colors.black.withOpacity(0.25),
            ),
            // Main route line
            Polyline(
              points: _routePoints,
              strokeWidth: 4.5,
              color: const Color(0xFF2563EB),
              borderColor: const Color(0xFF2563EB).withOpacity(0.3),
              borderStrokeWidth: 2,
            ),
          ]),
          // Station markers
          MarkerLayer(markers: filtered.map((s) {
            final col = _statusColor(s['status'] ?? 'GREEN');
            final sel = _selected?['id'] == s['id'] || _routeTarget?['id'] == s['id'];
            return Marker(
              point: LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble()),
              width: sel ? 56 : 46, height: sel ? 56 : 46,
              child: GestureDetector(
                onTap: () => setState(() { _selected = s; _routeTarget = null; _routePoints = []; }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutBack,
                  decoration: BoxDecoration(
                    color: col, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: sel ? 3 : 2),
                    boxShadow: [BoxShadow(color: col.withOpacity(sel ? 0.7 : 0.4), blurRadius: sel ? 22 : 10)],
                  ),
                  child: Icon(Icons.local_gas_station_rounded, color: Colors.white, size: sel ? 28 : 22),
                ),
              ),
            );
          }).toList()),
        ],
      ),

      // Route info banner
      if (_routeTarget != null) Positioned(
        top: 14, left: 14, right: 14,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1425).withOpacity(0.97),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.4)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: _routeLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 2))
                  : const Icon(Icons.navigation_rounded, color: Color(0xFF2563EB), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_routeTarget!['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              Text(
                _routeLoading
                    ? 'Calculating route…'
                    : '${_driveMinutes(_routeTarget!)} min drive • ${_routeTarget!['wait_minutes']} min wait',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
              ),
            ])),
            GestureDetector(
              onTap: () => setState(() { _routeTarget = null; _routePoints = []; }),
              child: const Icon(Icons.close_rounded, color: Colors.white38, size: 18),
            ),
          ]),
        ),
      ),

      // Legend + filter
      if (_routeTarget == null) Positioned(top: 14, left: 14, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: const Color(0xFF0D1425).withOpacity(0.95), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _legendDot(const Color(0xFF10B981), 'Available'),
            const SizedBox(height: 6),
            _legendDot(const Color(0xFFF59E0B), 'Busy'),
            const SizedBox(height: 6),
            _legendDot(const Color(0xFFEF4444), 'Very Busy'),
          ]),
        ),
        const SizedBox(height: 8),
        _mapFilterChip('ALL', 'All'),
        const SizedBox(height: 4),
        _mapFilterChip('GREEN', 'Free Only'),
      ])),

      // Refresh button
      Positioned(top: 14, right: 14, child: GestureDetector(
        onTap: _loadStations,
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: const Color(0xFF0D1425).withOpacity(0.95), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.08))),
          child: const Icon(Icons.refresh_rounded, color: Colors.white60, size: 20),
        ),
      )),

      // My location button
      Positioned(bottom: _selected != null ? 220 : 24, right: 14, child: GestureDetector(
        onTap: () async {
          await _getLocation();
          if (_pos != null) _mapCtrl.move(LatLng(_pos!.latitude, _pos!.longitude), 15);
        },
        child: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withOpacity(0.4), blurRadius: 12)],
          ),
          child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
        ),
      )),

      if (_loading) Positioned(top: 14, left: 0, right: 0, child: Center(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(color: const Color(0xFF0D1425), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.08))),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Fetching stations...', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      ))),

      if (_err != null) Positioned(top: 14, left: 14, right: 14, child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.3))),
        child: const Row(children: [
          Icon(Icons.wifi_off_rounded, color: Color(0xFFEF4444), size: 16),
          SizedBox(width: 8),
          Expanded(child: Text('Backend offline — run Django server', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12))),
        ]),
      )),

      if (_selected != null) Positioned(bottom: 16, left: 16, right: 16, child: _buildStationDetailCard(_selected!)),
    ]);
  }

  Widget _mapFilterChip(String val, String label) {
    final active = _filterStatus == val;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2563EB).withOpacity(0.2) : const Color(0xFF0D1425).withOpacity(0.9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? const Color(0xFF2563EB).withOpacity(0.5) : Colors.white.withOpacity(0.08)),
        ),
        child: Text(label, style: TextStyle(color: active ? const Color(0xFF2563EB) : Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _legendDot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.withOpacity(0.4), blurRadius: 4)])),
    const SizedBox(width: 8),
    Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w500)),
  ]);

  Widget _buildStationDetailCard(Map s) {
    final col = _statusColor(s['status'] ?? 'GREEN');
    final drive = _driveMinutes(s);
    final wait = s['wait_minutes'] as int? ?? 0;
    final total = drive + wait;
    final lastUpdated = s['last_updated'] ?? '';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1425),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: col.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 30)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.local_gas_station_rounded, color: col, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            Text(s['address'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: col.withOpacity(0.3))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_statusIcon(s['status'] ?? 'GREEN'), color: col, size: 12),
              const SizedBox(width: 4),
              Text(_statusLabel(s['status'] ?? 'GREEN'), style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _infoChip(Icons.directions_car_rounded, '${s['vehicles']} cars', Colors.white54),
          const SizedBox(width: 14),
          _infoChip(Icons.access_time_rounded, '~$wait min wait', Colors.white54),
          const SizedBox(width: 14),
          _infoChip(Icons.timer_rounded, '$total min total', const Color(0xFF2563EB)),
        ]),
        if (lastUpdated.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.update_rounded, color: Colors.white.withOpacity(0.25), size: 11),
            const SizedBox(width: 4),
            Text('Updated $lastUpdated', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 11)),
          ]),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => _navigateInApp(s),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(12)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.navigation_rounded, color: Colors.white, size: 16),
                SizedBox(width: 6),
                Text('Navigate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            ),
          )),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _shareStation(s),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.08))),
              child: const Icon(Icons.share_rounded, color: Colors.white54, size: 18),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: color, size: 13),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
  ]);

  Widget _buildListTab() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));
    final filtered = _filteredStations;
    if (filtered.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.local_gas_station_rounded, color: Colors.white.withOpacity(0.1), size: 64),
      const SizedBox(height: 16),
      Text('No stations found', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 16)),
    ]));

    final sorted = [...filtered]..sort((a, b) {
      const order = {'GREEN': 0, 'YELLOW': 1, 'RED': 2};
      return (order[a['status']] ?? 0).compareTo(order[b['status']] ?? 0);
    });

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: sorted.length + 2,
      itemBuilder: (_, i) {
        if (i == 0) return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Nearby Stations', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              Text('${filtered.length} stations found', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12)),
            ]),
            const Spacer(),
            GestureDetector(
              onTap: _loadStations,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.08))),
                child: const Icon(Icons.refresh_rounded, color: Colors.white38, size: 18),
              ),
            ),
          ]),
        );

        if (i == 1) return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _listFilterChip('ALL', 'All Stations'),
              const SizedBox(width: 8),
              _listFilterChip('GREEN', '🟢 Available'),
              const SizedBox(width: 8),
              _listFilterChip('YELLOW', '🟡 Busy'),
              const SizedBox(width: 8),
              _listFilterChip('RED', '🔴 Very Busy'),
            ]),
          ),
        );

        final s = sorted[i - 2];
        final col = _statusColor(s['status'] ?? 'GREEN');
        final drive = _driveMinutes(s);
        final wait = s['wait_minutes'] as int? ?? 0;
        final total = drive + wait;

        return GestureDetector(
          onTap: () {
            setState(() { _tab = 0; _selected = s; });
            _mapCtrl.move(LatLng((s['lat'] as num).toDouble(), (s['lng'] as num).toDouble()), 15);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF0D1425), borderRadius: BorderRadius.circular(18), border: Border.all(color: col.withOpacity(0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 48, height: 48, decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: col.withOpacity(0.25))), child: Icon(Icons.local_gas_station_rounded, color: col, size: 24)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(s['address'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(_statusLabel(s['status'] ?? 'GREEN'), style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                _infoChip(Icons.directions_car_rounded, '${s['vehicles']} cars', Colors.white38),
                const SizedBox(width: 12),
                _infoChip(Icons.access_time_rounded, '~$wait min wait', Colors.white38),
                const SizedBox(width: 12),
                _infoChip(Icons.timer_rounded, '$total min total', const Color(0xFF2563EB)),
                const Spacer(),
                Text(s['last_updated'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10)),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => _navigateInApp(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2))),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.navigation_rounded, color: Color(0xFF2563EB), size: 14),
                      SizedBox(width: 5),
                      Text('Navigate', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _shareStation(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 14),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.07))),
                    child: const Icon(Icons.share_rounded, color: Colors.white38, size: 14),
                  ),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _listFilterChip(String val, String label) {
    final active = _filterStatus == val;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = val),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2563EB).withOpacity(0.12) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? const Color(0xFF2563EB).withOpacity(0.4) : Colors.white.withOpacity(0.07)),
        ),
        child: Text(label, style: TextStyle(color: active ? const Color(0xFF2563EB) : Colors.white38, fontSize: 12, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
      ),
    );
  }

  Widget _buildSmartRouteTab() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)));

    final options = [..._filteredStations];
    options.sort((a, b) {
      final tA = _driveMinutes(a) + (a['wait_minutes'] as int? ?? 0);
      final tB = _driveMinutes(b) + (b['wait_minutes'] as int? ?? 0);
      return tA.compareTo(tB);
    });

    if (options.isEmpty) return Center(child: Text('No stations available', style: TextStyle(color: Colors.white.withOpacity(0.3))));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text('Smart Route', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Ranked by drive time + queue wait', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.15))),
          child: Row(children: [
            const Text('🕐', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(child: Text('We estimate arrival time and predict queue size when you get there.', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, height: 1.5))),
          ]),
        ),
        const SizedBox(height: 16),
        ...options.asMap().entries.map((entry) {
          final i = entry.key;
          final s = entry.value;
          final drive = _driveMinutes(s);
          final wait = s['wait_minutes'] as int? ?? 0;
          final total = drive + wait;
          final col = _statusColor(s['status'] ?? 'GREEN');
          final isBest = i == 0;
          final arrival = DateTime.now().add(Duration(minutes: drive));
          final arrivalStr = '${arrival.hour}:${arrival.minute.toString().padLeft(2, '0')} ${arrival.hour < 12 ? 'AM' : 'PM'}';
          final predictedQ = s['vehicles'] + (drive ~/ 5);

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1425),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isBest ? const Color(0xFF10B981).withOpacity(0.4) : Colors.white.withOpacity(0.06), width: isBest ? 1.5 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (isBest) Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: const BoxDecoration(color: Color(0x1A10B981), borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
                child: const Row(children: [
                  Text('⭐', style: TextStyle(fontSize: 13)),
                  SizedBox(width: 6),
                  Text('BEST OPTION — Fastest total time', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w700)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: col.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.local_gas_station_rounded, color: col, size: 20)),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                      Text(s['address'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: isBest ? const Color(0xFF10B981).withOpacity(0.1) : Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(20)),
                      child: Text('$total min', style: TextStyle(color: isBest ? const Color(0xFF10B981) : Colors.white54, fontSize: 13, fontWeight: FontWeight.w800)),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    _routeStat('🚗', 'Drive', '$drive min'),
                    const SizedBox(width: 6),
                    Text('+', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 16)),
                    const SizedBox(width: 6),
                    _routeStat('⏱️', 'Wait', '$wait min'),
                    const SizedBox(width: 6),
                    Text('=', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 16)),
                    const SizedBox(width: 6),
                    _routeStat('⭐', 'Total', '$total min'),
                  ]),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(10)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('🕐  Arrive at: $arrivalStr', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                      const SizedBox(height: 3),
                      Text('📊  Expected queue: ~$predictedQ cars', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: GestureDetector(
                      onTap: () => _navigateInApp(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(10)),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.navigation_rounded, color: Colors.white, size: 15),
                          SizedBox(width: 6),
                          Text('Navigate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                        ]),
                      ),
                    )),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _shareStation(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withOpacity(0.06))),
                        child: const Icon(Icons.share_rounded, color: Colors.white38, size: 16),
                      ),
                    ),
                  ]),
                ]),
              ),
            ]),
          );
        }),
      ],
    );
  }

  Widget _routeStat(String emoji, String label, String val) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(color: Colors.white.withOpacity(0.04), borderRadius: BorderRadius.circular(10)),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(height: 3),
      Text(val, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
    ]),
  ));

  Widget _buildEmergencyTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Emergency', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Tap any number to call instantly', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2))),
          child: Row(children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.15), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.sos_rounded, color: Color(0xFFEF4444), size: 28)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Need immediate help?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              Text('Tap any number below to call instantly', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
            ])),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('EMERGENCY CONTACTS', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        _emergencyCard(Icons.local_police_rounded, const Color(0xFF2563EB), 'Police Emergency', 'Pakistan Police', '15'),
        _emergencyCard(Icons.local_hospital_rounded, const Color(0xFFEF4444), 'Ambulance', 'Emergency Medical Services', '1122'),
        _emergencyCard(Icons.fire_truck_rounded, const Color(0xFFF59E0B), 'Fire & Rescue', 'Rescue 1122 Services', '16'),
        _emergencyCard(Icons.local_gas_station_rounded, const Color(0xFF10B981), 'OGRA Helpline', 'Fuel Regulation Authority', '0800-00677'),
        const SizedBox(height: 28),
        const Text('FUEL PRICES TODAY', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        _priceCard('Petrol RON 92', 'Rs. 272', 'per litre', const Color(0xFF2563EB)),
        _priceCard('High Speed Diesel', 'Rs. 293', 'per litre', const Color(0xFFF59E0B)),
        _priceCard('Kerosene', 'Rs. 187', 'per litre', const Color(0xFF8B5CF6)),
      ]),
    );
  }

  Widget _emergencyCard(IconData icon, Color c, String title, String sub, String num) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFF0D1425), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: c, size: 22)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
          Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
        ])),
        // ── Direct dialer button ──
        GestureDetector(
          onTap: () => _callNumber(num),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: c.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.withOpacity(0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.call_rounded, color: c, size: 15),
              const SizedBox(width: 5),
              Text(num, style: TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _priceCard(String label, String price, String unit, Color c) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFF0D1425), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withOpacity(0.06))),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, fontWeight: FontWeight.w500))),
        RichText(text: TextSpan(
          text: price,
          style: TextStyle(color: c, fontSize: 18, fontWeight: FontWeight.w800),
          children: [TextSpan(text: '  $unit', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12, fontWeight: FontWeight.w400))],
        )),
      ]),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF0D1425), border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06)))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: Row(children: [
        _navItem(0, Icons.map_rounded, 'Map'),
        _navItem(1, Icons.format_list_bulleted_rounded, 'Stations'),
        _navItem(2, Icons.route_rounded, 'Routes'),
        _navItem(3, Icons.sos_rounded, 'Emergency'),
      ]),
    );
  }

  Widget _navItem(int idx, IconData icon, String label) {
    final active = _tab == idx;
    return Expanded(child: GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: active ? const Color(0xFF2563EB).withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: active ? const Color(0xFF2563EB) : Colors.white.withOpacity(0.3), size: 20),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: active ? const Color(0xFF2563EB) : Colors.white.withOpacity(0.3), fontSize: 10, fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
        ]),
      ),
    ));
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1425),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF2563EB).withOpacity(0.1),
            child: Text(_firstName.isNotEmpty ? _firstName[0].toUpperCase() : 'U', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 28, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 12),
          Text(_user?['full_name'] ?? 'User', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          Text(_user?['phone'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14)),
          const SizedBox(height: 28),
          if (_user?['is_station_owner'] == true) ...[
            _sheetTile(Icons.dashboard_rounded, 'Station Dashboard', const Color(0xFF2563EB), () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => DashboardScreen(stationId: _user!['owned_station_id'])));
            }),
            const SizedBox(height: 10),
          ],
          _sheetTile(Icons.logout_rounded, 'Sign Out', const Color(0xFFEF4444), () async {
            await ApiService.logout();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(context, PageRouteBuilder(
              pageBuilder: (_, __, ___) => const WelcomeScreen(),
              transitionDuration: const Duration(milliseconds: 500),
              transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
            ), (_) => false);
          }),
        ]),
      ),
    );
  }

  Widget _sheetTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color.withOpacity(0.07), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.15))),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600)),
          const Spacer(),
          Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.4), size: 14),
        ]),
      ),
    );
  }
}