import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'employee_screen.dart';

class DashboardScreen extends StatefulWidget {
  final int stationId;
  const DashboardScreen({super.key, required this.stationId});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _err;
  Timer? _timer;
  late AnimationController _countCtrl;
  late Animation<double> _countAnim;

  @override
  void initState() {
    super.initState();
    _countCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _countAnim = CurvedAnimation(parent: _countCtrl, curve: Curves.easeOutCubic);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => _load());
  }

  @override
  void dispose() { _timer?.cancel(); _countCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    final r = await ApiService.getDashboard(widget.stationId);
    if (!mounted) return;
    if (r.success) {
      setState(() { _data = r.data; _loading = false; _err = null; });
      _countCtrl.forward(from: 0);
    } else {
      setState(() { _loading = false; _err = r.error; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: Column(children: [
        _buildHeader(),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
            : _err != null
                ? _buildError()
                : _buildDashboard()),
      ]),
    );
  }

  Widget _buildHeader() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF0D1425),
      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.06))),
    ),
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 12,
      left: 20, right: 20, bottom: 14,
    ),
    child: Row(children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 16),
        ),
      ),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_data?['station'] ?? 'Station Dashboard', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        Text('Owner Analytics', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
      ])),
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => EmployeeScreen(stationId: widget.stationId),
        )),
        child: Container(
          width: 40, height: 40,
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF8B5CF6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.2)),
          ),
          child: const Icon(Icons.people_alt_rounded, color: Color(0xFF8B5CF6), size: 18),
        ),
      ),
      GestureDetector(
        onTap: _load,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withOpacity(0.1),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2)),
          ),
          child: const Icon(Icons.refresh_rounded, color: Color(0xFF2563EB), size: 18),
        ),
      ),
    ]),
  );

  Widget _buildError() => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.cloud_off_rounded, color: Colors.white.withOpacity(0.1), size: 64),
      const SizedBox(height: 16),
      Text(_err ?? 'Failed to load', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 15), textAlign: TextAlign.center),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: _load,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: const Text('Retry'),
      ),
    ]),
  ));

  Widget _buildDashboard() {
    final today = _data?['today'] ?? {};
    final monthly = _data?['monthly'] ?? {};
    final hourly = List<Map<String, dynamic>>.from(_data?['hourly_congestion'] ?? []);
    final fuel = Map<String, dynamic>.from(_data?['fuel_breakdown_liters'] ?? {});
    final peak = List<Map<String, dynamic>>.from(_data?['peak_hours'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: AnimatedBuilder(
        animation: _countAnim,
        builder: (_, __) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Today header
          _sectionHeader('TODAY', Icons.wb_sunny_rounded, const Color(0xFFF59E0B)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _statCard('Avg. Vehicles', '${(today['avg_vehicles'] ?? 0)}', Icons.directions_car_rounded, const Color(0xFF2563EB))),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Revenue', 'Rs ${_fmt(today['revenue_pkr'] ?? 0)}', Icons.monetization_on_rounded, const Color(0xFF10B981))),
          ]),
          const SizedBox(height: 12),
          _statCard('Fuel Dispensed', '${_fmt(today['liters_dispensed'] ?? 0)} L', Icons.local_gas_station_rounded, const Color(0xFFF59E0B), wide: true),

          const SizedBox(height: 28),

          // Monthly
          _sectionHeader('THIS MONTH', Icons.calendar_month_rounded, const Color(0xFF10B981)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _statCard('Total Visits', '${monthly['total_visits'] ?? 0}', Icons.people_rounded, const Color(0xFF8B5CF6))),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Revenue', 'Rs ${_fmt(monthly['revenue_pkr'] ?? 0)}', Icons.account_balance_wallet_rounded, const Color(0xFF10B981))),
          ]),
          const SizedBox(height: 12),
          _statCard('Total Fuel Sold', '${_fmt(monthly['liters_dispensed'] ?? 0)} L', Icons.opacity_rounded, const Color(0xFF2563EB), wide: true),

          const SizedBox(height: 28),

          // Hourly traffic
          if (hourly.isNotEmpty) ...[
            _sectionHeader('HOURLY TRAFFIC', Icons.bar_chart_rounded, const Color(0xFF2563EB)),
            const SizedBox(height: 16),
            _buildHourlyChart(hourly),
            const SizedBox(height: 28),
          ],

          // Fuel breakdown
          if (fuel.isNotEmpty) ...[
            _sectionHeader('FUEL BREAKDOWN', Icons.pie_chart_rounded, const Color(0xFF8B5CF6)),
            const SizedBox(height: 12),
            ...fuel.entries.map((e) => _buildFuelRow(e.key, e.value.toDouble(), fuel)),
            const SizedBox(height: 28),
          ],

          // Peak hours
          if (peak.isNotEmpty) ...[
            _sectionHeader('PEAK HOURS', Icons.trending_up_rounded, const Color(0xFFEF4444)),
            const SizedBox(height: 12),
            ...List.generate(peak.length, (i) => _buildPeakRow(peak[i], i)),
          ],
        ]),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) => Row(children: [
    Icon(icon, color: color, size: 16),
    const SizedBox(width: 8),
    Text(title, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
  ]);

  Widget _statCard(String label, String value, IconData icon, Color color, {bool wide = false}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1425),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: wide
          ? Row(children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
              ]),
            ])
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, color: color, size: 18),
                const Spacer(),
                Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              ]),
              const SizedBox(height: 14),
              Text(value, style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
            ]),
    );
  }

  Widget _buildHourlyChart(List<Map<String, dynamic>> hourly) {
    final maxVal = hourly.map((h) => (h['avg_vehicles'] as int? ?? 0).toDouble()).reduce((a, b) => a > b ? a : b);
    final now = DateTime.now().hour;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1425),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('Vehicles per hour', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('Today', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          height: 100,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(24, (i) {
              final val = (hourly.length > i ? (hourly[i]['avg_vehicles'] as int? ?? 0) : 0).toDouble();
              final ratio = maxVal > 0 ? val / maxVal : 0.0;
              final isCurrent = i == now;
              final color = isCurrent ? const Color(0xFF2563EB) : (ratio > 0.7 ? const Color(0xFFEF4444) : ratio > 0.4 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 600 + i * 20),
                    curve: Curves.easeOutCubic,
                    height: (ratio * 80).clamp(2.0, 80.0),
                    decoration: BoxDecoration(
                      color: color.withOpacity(isCurrent ? 1 : 0.6),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                    ),
                  ),
                ]),
              ));
            }),
          ),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('12am', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10)),
          Text('6am', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10)),
          Text('12pm', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10)),
          Text('6pm', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10)),
          Text('now', style: TextStyle(color: const Color(0xFF2563EB).withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }

  Widget _buildFuelRow(String type, double liters, Map<String, dynamic> all) {
    final total = all.values.fold<double>(0, (a, b) => a + (b as num).toDouble());
    final pct = total > 0 ? liters / total : 0.0;
    const colors = {'PETROL': Color(0xFF2563EB), 'DIESEL': Color(0xFFF59E0B), 'HSD': Color(0xFFEF4444), 'KEROSENE': Color(0xFF8B5CF6)};
    final color = colors[type] ?? const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1425),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(children: [
        Row(children: [
          Text(type, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('${liters.toStringAsFixed(1)} L', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.white.withOpacity(0.05),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 5,
          ),
        ),
      ]),
    );
  }

  Widget _buildPeakRow(Map<String, dynamic> peak, int rank) {
    const medals = ['🥇', '🥈', '🥉'];
    final hour = peak['hour'] as int;
    final amPm = hour < 12 ? 'AM' : 'PM';
    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1425),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(children: [
        Text(rank < 3 ? medals[rank] : '#${rank + 1}', style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$h:00 $amPm', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
          Text('Peak hour', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
        ]),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('${peak['avg_vehicles']} avg', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }

  String _fmt(dynamic val) {
    final n = (val as num).toDouble();
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }
}