import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const FuelSenseApp());
}

class FuelSenseApp extends StatelessWidget {
  const FuelSenseApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FuelSense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primaryColor: const Color(0xFF2196F3), colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)), useMaterial3: true),
      home: const WelcomeScreen(),
    );
  }
}

// ══════════════════════════════════════
// 1. WELCOME SCREEN (Dark Nawgati Style)
// ══════════════════════════════════════
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  int _tab = 1;
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  final List<Map<String, dynamic>> _content = [
    {
      'title': 'For Fuel Stations',
      'subtitle': 'Monitor your station in real-time',
      'features': ['📊 Real-time queue monitoring', '📈 Daily traffic analytics', '🚗 Vehicle count per dispenser', '⏰ Peak hour predictions'],
      'btn': 'Register Station',
    },
    {
      'title': 'For Drivers',
      'subtitle': 'Never wait in long queues again',
      'features': ['🗺️ Live station congestion map', '📍 Find nearest open station', '⛽ Compare fuel prices', '🆘 Emergency fuel assistance'],
      'btn': 'Get Started',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final c = _content[_tab];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0A0A0A), Color(0xFF111827), Color(0xFF0D1B2A)])))),
          Positioned.fill(child: CustomPaint(painter: _GridPainter())),
          Positioned(bottom: -100, left: -80, child: Container(width: 350, height: 350, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [const Color(0xFF2196F3).withOpacity(0.15), Colors.transparent])))),
          Positioned(top: -50, right: -50, child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [const Color(0xFF2196F3).withOpacity(0.1), Colors.transparent])))),
          SafeArea(
            child: FadeTransition(
              opacity: _anim,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                    child: Row(
                      children: [
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFF2196F3).withOpacity(0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF2196F3).withOpacity(0.4))), child: const Icon(Icons.local_gas_station, color: Color(0xFF2196F3), size: 24)),
                        const SizedBox(width: 12),
                        const Text('FuelSense', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                        const Spacer(),
                        TextButton(onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())), child: const Text('Login', style: TextStyle(color: Color(0xFF2196F3), fontSize: 16))),
                      ],
                    ),
                  ),
                  // Toggle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.white.withOpacity(0.15))),
                      child: Row(
                        children: [
                          Expanded(child: GestureDetector(
                            onTap: () => setState(() => _tab = 0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(color: _tab == 0 ? Colors.white.withOpacity(0.12) : Colors.transparent, borderRadius: BorderRadius.circular(26), border: _tab == 0 ? Border.all(color: Colors.white.withOpacity(0.2)) : null),
                              child: Text('For fuel providers', textAlign: TextAlign.center, style: TextStyle(color: _tab == 0 ? Colors.white : Colors.white54, fontSize: 14, fontWeight: _tab == 0 ? FontWeight.bold : FontWeight.normal)),
                            ),
                          )),
                          Expanded(child: GestureDetector(
                            onTap: () => setState(() => _tab = 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(color: _tab == 1 ? const Color(0xFF2196F3) : Colors.transparent, borderRadius: BorderRadius.circular(26)),
                              child: Text('For you', textAlign: TextAlign.center, style: TextStyle(color: _tab == 1 ? Colors.white : Colors.white54, fontSize: 14, fontWeight: _tab == 1 ? FontWeight.bold : FontWeight.normal)),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Illustration
                  SizedBox(
                    height: 200,
                    child: Stack(alignment: Alignment.center, children: [
                      Positioned(bottom: 20, left: 0, right: 0, child: Container(height: 2, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.white.withOpacity(0.1), Colors.transparent])))),
                      Positioned(
                        bottom: 22,
                        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          AnimatedOpacity(opacity: _tab == 1 ? 1.0 : 0.3, duration: const Duration(milliseconds: 300), child: _CarWidget()),
                          const SizedBox(width: 20),
                          _PumpWidget(),
                          const SizedBox(width: 20),
                          _WorkerWidget(color: _tab == 0 ? const Color(0xFF2196F3) : Colors.white54),
                        ]),
                      ),
                    ]),
                  ),
                  const Spacer(),
                  // Bottom card
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      key: ValueKey(_tab),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withOpacity(0.1)), boxShadow: [BoxShadow(color: const Color(0xFF2196F3).withOpacity(0.1), blurRadius: 30, spreadRadius: -5)]),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c['title'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(c['subtitle'], style: const TextStyle(color: Color(0xFF2196F3), fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 16),
                        ...List.generate((c['features'] as List).length, (i) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(c['features'][i], style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 13)))),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2196F3), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 8, shadowColor: const Color(0xFF2196F3).withOpacity(0.5)),
                            child: Text(c['btn'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 90, height: 42, decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(20), bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(margin: const EdgeInsets.only(bottom: 4, left: 6), width: 22, height: 13, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(4))),
          Container(margin: const EdgeInsets.only(bottom: 4, right: 6), width: 22, height: 13, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(4))),
        ]),
      ),
      Row(children: [
        const SizedBox(width: 8),
        Container(width: 18, height: 10, decoration: BoxDecoration(color: Colors.grey.shade700, shape: BoxShape.circle)),
        const SizedBox(width: 44),
        Container(width: 18, height: 10, decoration: BoxDecoration(color: Colors.grey.shade700, shape: BoxShape.circle)),
        const SizedBox(width: 8),
      ]),
    ]);
  }
}

class _PumpWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 80,
      decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.grey.shade700), boxShadow: [BoxShadow(color: const Color(0xFF2196F3).withOpacity(0.3), blurRadius: 15)]),
      child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        Container(width: 28, height: 20, decoration: BoxDecoration(color: const Color(0xFF2196F3).withOpacity(0.6), borderRadius: BorderRadius.circular(3)), child: const Icon(Icons.speed, color: Colors.white, size: 14)),
        Container(width: 20, height: 3, color: Colors.grey.shade600),
        Container(width: 28, height: 15, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(3))),
      ]),
    );
  }
}

class _WorkerWidget extends StatelessWidget {
  final Color color;
  const _WorkerWidget({required this.color});
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 20, height: 20, decoration: BoxDecoration(color: Colors.brown.shade300, shape: BoxShape.circle)),
      const SizedBox(height: 2),
      Container(width: 24, height: 35, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
      Row(children: [
        Container(width: 10, height: 15, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 4),
        Container(width: 10, height: 15, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2))),
      ]),
    ]);
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.03)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    for (double y = 0; y < size.height; y += 40) canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }
  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// ══════════════════════════════════════
// 2. LOGIN SCREEN
// ══════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  void _login() async {
    if (_email.text.isEmpty || _pass.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter email and password')));
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', _email.text);
      setState(() => _loading = false);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFF1F4788)), onPressed: () => Navigator.pop(context))),
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(30), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Welcome Back!', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF1F4788))),
        const SizedBox(height: 10),
        const Text('Login to continue', style: TextStyle(fontSize: 16, color: Colors.grey)),
        const SizedBox(height: 50),
        TextField(controller: _email, decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 20),
        TextField(controller: _pass, obscureText: _obscure, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock), suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _obscure = !_obscure)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
        const SizedBox(height: 10),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () {}, child: const Text('Forgot Password?'))),
        const SizedBox(height: 30),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: _loading ? null : _login,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4788), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('LOGIN', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        )),
        const SizedBox(height: 25),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("Don't have an account? "), TextButton(onPressed: () {}, child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold)))]),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.info_outline, color: Colors.blue, size: 20), const SizedBox(width: 10), Text('Demo Credentials', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900))]),
          const SizedBox(height: 8),
          Text('Email: demo@fuelsense.pk\nPassword: demo123', style: TextStyle(fontSize: 12, color: Colors.blue.shade700)),
        ])),
      ]))),
    );
  }

  @override
  void dispose() { _email.dispose(); _pass.dispose(); super.dispose(); }
}

// ══════════════════════════════════════
// 3. HOME DASHBOARD
// ══════════════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _email = 'User';

  @override
  void initState() { super.initState(); _load(); }

  void _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() => _email = p.getString('user_email') ?? 'User');
  }

  String get _name => _email.contains('@') ? _email.split('@')[0] : _email;
  String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F4788), foregroundColor: Colors.white,
        title: const Text('FuelSense', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
          IconButton(icon: const CircleAvatar(radius: 15, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 18, color: Colors.white)), onPressed: () => _profile(context)),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Hello, ${_cap(_name)}! 👋', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1F4788))),
        const SizedBox(height: 5),
        const Text('Where do you need fuel today?', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 25),
        GridView.count(crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: [
          _card(Icons.map, 'Find Station', 'View map', const Color(0xFF1F4788), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen()))),
          _card(Icons.near_me, 'Nearest', 'Closest to you', Colors.green, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen(goToNearest: true)))),
          _card(Icons.emergency, 'Emergency', 'Get help now', Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyModeScreen()))),
          _card(Icons.monetization_on, 'Fuel Prices', 'Compare prices', Colors.orange, () => _prices(context)),
        ]),
        const SizedBox(height: 25),
        const Text('Live Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F4788))),
        const SizedBox(height: 15),
        Row(children: [
          Expanded(child: _stat('🟢 Low', '2 stations', Colors.green)),
          const SizedBox(width: 12),
          Expanded(child: _stat('🟡 Medium', '1 station', Colors.orange)),
          const SizedBox(width: 12),
          Expanded(child: _stat('🔴 High', '0 stations', Colors.red)),
        ]),
        const SizedBox(height: 25),
        const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F4788))),
        const SizedBox(height: 15),
        _action(Icons.local_police, Colors.blue, 'Motorway Police', 'Free emergency help - Dial 130', () => _call('130')),
        const SizedBox(height: 12),
        _action(Icons.local_shipping, Colors.purple, 'RSA Pakistan', 'Professional fuel delivery 24/7', () => _call('05184997772')),
        const SizedBox(height: 12),
        _action(Icons.share_location, Colors.teal, 'Share My Location', 'Send GPS location to family', _share),
        const SizedBox(height: 30),
      ])),
    );
  }

  Widget _card(IconData icon, String label, String sub, Color color, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle), child: Icon(icon, size: 45, color: color)),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ]),
    ));
  }

  Widget _stat(String t, String v, Color c) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontSize: 11)), const SizedBox(height: 6), Text(v, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c))]),
  );

  Widget _action(IconData icon, Color color, String title, String sub, VoidCallback onTap) {
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)]),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 26)),
        const SizedBox(width: 15),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)), Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey))])),
        const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      ]),
    ));
  }

  void _profile(BuildContext context) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => Container(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const CircleAvatar(radius: 35, backgroundColor: Color(0xFF1F4788), child: Icon(Icons.person, size: 40, color: Colors.white)),
      const SizedBox(height: 10),
      Text(_email, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      ListTile(leading: const Icon(Icons.settings), title: const Text('Settings'), onTap: () {}),
      ListTile(leading: const Icon(Icons.history), title: const Text('History'), onTap: () {}),
      const Divider(),
      ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Logout', style: TextStyle(color: Colors.red)),
        onTap: () async {
          final p = await SharedPreferences.getInstance();
          await p.clear();
          if (context.mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WelcomeScreen()));
        }),
    ])));
  }

  void _prices(BuildContext context) {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => Container(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Current Fuel Prices', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const Text('Pakistan - February 2026', style: TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 20),
      ...[['⛽ Petrol (RON 92)', 'Rs. 272/L'], ['⛽ Petrol (RON 95)', 'Rs. 285/L'], ['🛢️ High Speed Diesel', 'Rs. 293/L'], ['🟡 Kerosene', 'Rs. 187/L']].map((r) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Row(children: [Text(r[0], style: const TextStyle(fontSize: 15)), const Spacer(), Text(r[1], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1F4788)))]))),
    ])));
  }

  void _call(String n) async { final u = Uri(scheme: 'tel', path: n); if (await canLaunchUrl(u)) await launchUrl(u); }
  void _share() async { await Share.share("🆘 I need help!\nhttps://maps.google.com/?q=33.6844,73.0479"); }
}

// ══════════════════════════════════════
// 4. MAP SCREEN
// ══════════════════════════════════════
class MapScreen extends StatefulWidget {
  final bool goToNearest;
  const MapScreen({super.key, this.goToNearest = false});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mc = MapController();
  List<Station> _stations = [];
  LatLng _loc = const LatLng(33.6844, 73.0479);
  bool _loading = true;
  String _err = '';
  Station? _nearest;

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    await _getLoc();
    await _fetch();
    _findNearest();
    if (widget.goToNearest) { await Future.delayed(const Duration(milliseconds: 800)); _showNearest(); }
  }

  Future<void> _getLoc() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      setState(() => _loc = LatLng(pos.latitude, pos.longitude));
    } catch (_) {}
  }

  Future<void> _fetch() async {
    try {
      setState(() { _loading = true; _err = ''; });
      final r = await http.get(Uri.parse('http://127.0.0.1:8000/api/traffic/status/')).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        setState(() { _stations = (json.decode(r.body) as List).map((j) => Station.fromJson(j)).toList(); _loading = false; });
      } else { setState(() { _err = 'Failed to load'; _loading = false; }); }
    } catch (_) { setState(() { _err = 'Error: Make sure Django is running!'; _loading = false; }); }
  }

  void _findNearest() {
    if (_stations.isEmpty) return;
    double min = double.infinity; Station? n;
    for (var s in _stations) {
      double d = Geolocator.distanceBetween(_loc.latitude, _loc.longitude, s.lat, s.lng);
      if (d < min) { min = d; n = s; }
    }
    setState(() => _nearest = n);
  }

  void _showNearest() { if (_nearest == null) return; _mc.move(LatLng(_nearest!.lat, _nearest!.lng), 15.0); _details(_nearest!); }

  Color _c(String s) { switch (s.toUpperCase()) { case 'GREEN': return Colors.green; case 'YELLOW': return Colors.orange; case 'RED': return Colors.red; default: return Colors.grey; } }
  String _w(String s) { switch (s.toUpperCase()) { case 'GREEN': return '0-5 min wait'; case 'YELLOW': return '5-10 min wait'; case 'RED': return '10+ min wait'; default: return 'Unknown'; } }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: const Color(0xFF1F4788), foregroundColor: Colors.white, title: const Text('Station Map', style: TextStyle(fontWeight: FontWeight.bold)), actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch), IconButton(icon: const Icon(Icons.near_me), onPressed: _showNearest)]),
      body: Stack(children: [
        FlutterMap(mapController: _mc, options: MapOptions(initialCenter: _loc, initialZoom: 13.0), children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.fuelsense'),
          MarkerLayer(markers: _stations.map((s) => Marker(point: LatLng(s.lat, s.lng), width: 50, height: 50, child: GestureDetector(onTap: () => _details(s), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: _c(s.status), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6)]), child: const Icon(Icons.local_gas_station, color: Colors.white, size: 20))))).toList()),
          MarkerLayer(markers: [Marker(point: _loc, width: 40, height: 40, child: Container(decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)), child: const Icon(Icons.person, color: Colors.white, size: 20)))]),
        ]),
        Positioned(top: 15, right: 15, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _leg(Colors.green, 'Low (0-5)'), const SizedBox(height: 5), _leg(Colors.orange, 'Medium (6-10)'), const SizedBox(height: 5), _leg(Colors.red, 'High (11+)'),
        ]))),
        Positioned(bottom: 0, left: 0, right: 0, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)]), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [Text('${_stations.length} stations near you', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const Spacer(), if (_loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))]),
          if (_err.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err, style: const TextStyle(color: Colors.red, fontSize: 12))),
          const SizedBox(height: 15),
          SizedBox(height: 120, child: _stations.isEmpty ? const Center(child: Text('No stations found')) : ListView.builder(scrollDirection: Axis.horizontal, itemCount: _stations.length, itemBuilder: (_, i) => _stCard(_stations[i]))),
        ]))),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmergencyModeScreen())), backgroundColor: Colors.red, child: const Icon(Icons.emergency, color: Colors.white)),
    );
  }

  Widget _leg(Color c, String l) => Row(children: [Container(width: 16, height: 16, decoration: BoxDecoration(color: c, shape: BoxShape.circle)), const SizedBox(width: 8), Text(l, style: const TextStyle(fontSize: 12))]);

  Widget _stCard(Station s) {
    final c = _c(s.status);
    return GestureDetector(onTap: () => _details(s), child: Container(width: 200, margin: const EdgeInsets.only(right: 15), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: c, width: 2)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)), child: Text(s.status, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))), const Spacer(), Text('${s.vehicles} 🚗', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))]),
      const SizedBox(height: 8),
      Text(s.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 4),
      Text(_w(s.status), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
    ])));
  }

  void _details(Station s) {
    final c = _c(s.status);
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (_) => Container(padding: const EdgeInsets.all(25), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withOpacity(0.2), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.local_gas_station, color: c, size: 30)), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text('${s.lat.toStringAsFixed(4)}, ${s.lng.toStringAsFixed(4)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]))]),
      const SizedBox(height: 25),
      Row(children: [Icon(Icons.directions_car, color: c), const SizedBox(width: 10), Text('${s.vehicles} vehicles'), const Spacer(), Icon(Icons.access_time, color: c), const SizedBox(width: 10), Text(_w(s.status))]),
      const SizedBox(height: 25),
      SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { _mc.move(LatLng(s.lat, s.lng), 15.0); Navigator.pop(context); }, icon: const Icon(Icons.navigation), label: const Text('Navigate on Map'), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1F4788), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
    ])));
  }
}

// ══════════════════════════════════════
// 5. STATION MODEL
// ══════════════════════════════════════
class Station {
  final int id; final String name; final double lat, lng; final int vehicles; final String status;
  Station({required this.id, required this.name, required this.lat, required this.lng, required this.vehicles, required this.status});
  factory Station.fromJson(Map<String, dynamic> j) => Station(id: j['id'], name: j['name'], lat: j['lat'].toDouble(), lng: j['lng'].toDouble(), vehicles: j['vehicles'], status: j['status']);
}

// ══════════════════════════════════════
// 6. EMERGENCY MODE SCREEN
// ══════════════════════════════════════
class EmergencyModeScreen extends StatelessWidget {
  const EmergencyModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.red, foregroundColor: Colors.white, title: const Text('🆘 Emergency Mode'), centerTitle: true),
      body: Container(color: Colors.red.shade50, child: ListView(padding: const EdgeInsets.all(20), children: [
        Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red, width: 2)), child: Row(children: [const Icon(Icons.warning, color: Colors.red, size: 40), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('CAR STOPPED - NO FUEL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red.shade900)), Text('Choose help option below', style: TextStyle(fontSize: 14, color: Colors.red.shade700))]))])),
        const SizedBox(height: 25),
        Text('🚨 PROFESSIONAL SERVICES', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(height: 15),
        _eCard(Icons.local_shipping, Colors.red, 'RSA Pakistan', 'Fuel delivery in 30 min - Pay on delivery', '05184997772'),
        const SizedBox(height: 15),
        _eCard(Icons.local_police, Colors.blue, 'Motorway Police', 'Free highway assistance - Dial 130', '130'),
        const SizedBox(height: 25),
        Text('👨‍👩‍👧 PERSONAL HELP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
        const SizedBox(height: 15),
        _eCard(Icons.phone, Colors.green, 'Call Family/Friend', 'Quick dial your emergency contact', '03001234567'),
        const SizedBox(height: 15),
        _eCard(Icons.local_gas_station, Colors.orange, 'Nearby Station', 'Ask station to bring fuel to you', '0512345678'),
      ])),
    );
  }

  Widget _eCard(IconData icon, Color color, String title, String sub, String num) {
    return Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(15), child: Row(children: [
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 28)),
      const SizedBox(width: 15),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)), const SizedBox(height: 3), Text(sub, style: const TextStyle(fontSize: 12, color: Colors.grey))])),
      Container(decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.phone, color: Colors.white, size: 20), onPressed: () async { final u = Uri(scheme: 'tel', path: num); if (await canLaunchUrl(u)) await launchUrl(u); })),
    ])));
  }
}