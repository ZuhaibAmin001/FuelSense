import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  late AnimationController _heroCtrl;
  late AnimationController _slideCtrl;
  late Animation<double> _heroFade;
  late Animation<Offset> _slideAnim;
  int _activeFeature = 0;

  final List<Map<String, dynamic>> _features = [
    {'icon': Icons.map_rounded, 'title': 'Live Station Map', 'desc': 'See real-time congestion at every fuel station near you', 'color': const Color(0xFF2563EB)},
    {'icon': Icons.speed_rounded, 'title': 'Zero Wait Time', 'desc': 'Our AI predicts queue length before you even leave home', 'color': const Color(0xFF10B981)},
    {'icon': Icons.shield_rounded, 'title': 'Emergency Ready', 'desc': 'Instant access to emergency services and fuel delivery', 'color': const Color(0xFFF59E0B)},
  ];

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _heroFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _heroCtrl.forward();
    Future.delayed(const Duration(milliseconds: 300), () => _slideCtrl.forward());
    _startFeatureCycle();
  }

  void _startFeatureCycle() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return false;
      setState(() => _activeFeature = (_activeFeature + 1) % _features.length);
      return mounted;
    });
  }

  @override
  void dispose() { _heroCtrl.dispose(); _slideCtrl.dispose(); super.dispose(); }

  void _showRoleSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF0D1425),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          const Align(alignment: Alignment.centerLeft, child: Text('I am a...', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
          const SizedBox(height: 20),
          _roleOption(ctx, icon: Icons.directions_car_rounded, title: 'Driver', desc: 'Find fuel stations & check live queues', color: const Color(0xFF2563EB), role: 'driver'),
          const SizedBox(height: 14),
          _roleOption(ctx, icon: Icons.storefront_rounded, title: 'Station Owner', desc: 'Manage your station, employees & stats', color: const Color(0xFF8B5CF6), role: 'owner'),
        ]),
      ),
    );
  }

  Widget _roleOption(BuildContext ctx, {required IconData icon, required String title, required String desc, required Color color, required String role}) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(ctx);
        Navigator.push(context, _route(SignupScreen(role: role)));
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
          ])),
          Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(0.3)),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: Stack(children: [
        CustomPaint(size: size, painter: _DotGridPainter()),
        Positioned(top: -150, right: -100, child: _orb(350, const Color(0xFF2563EB).withOpacity(0.08))),
        Positioned(bottom: 200, left: -80, child: _orb(280, const Color(0xFF10B981).withOpacity(0.06))),

        SafeArea(child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: FadeTransition(
              opacity: _heroFade,
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.local_gas_station_rounded, color: Color(0xFF2563EB), size: 16),
                    const SizedBox(width: 6),
                    const Text('FuelSense', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.5)),
                  ]),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.push(context, _route(const LoginScreen())),
                  child: const Text('Sign In', style: TextStyle(color: Colors.white54, fontSize: 14)),
                ),
              ]),
            ),
          ),

          Expanded(
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _heroFade,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          const Text('Live across Islamabad', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                        ]),
                      ),
                      const SizedBox(height: 24),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.5),
                          children: [
                            TextSpan(text: 'Never waste\ntime at ', style: TextStyle(color: Colors.white)),
                            TextSpan(text: 'fuel\nstations', style: TextStyle(color: Color(0xFF2563EB))),
                            TextSpan(text: '.', style: TextStyle(color: Color(0xFF10B981))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Real-time queue monitoring powered by\ncomputer vision and AI.',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 15, height: 1.6, letterSpacing: 0.2),
                      ),
                      const SizedBox(height: 40),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero).animate(anim), child: child)),
                        child: _FeatureCard(
                          key: ValueKey(_activeFeature),
                          icon: _features[_activeFeature]['icon'],
                          title: _features[_activeFeature]['title'],
                          desc: _features[_activeFeature]['desc'],
                          color: _features[_activeFeature]['color'],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(children: List.generate(3, (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 6),
                        width: i == _activeFeature ? 24 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: i == _activeFeature ? const Color(0xFF2563EB) : Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ))),
                    ],
                  ),
                ),
              ),
            ),
          ),

          FadeTransition(
            opacity: _heroFade,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _showRoleSheet,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('Get Started', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 20),
                    ]),
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () => Navigator.push(context, _route(const LoginScreen())),
                  child: RichText(text: TextSpan(
                    text: 'Already have an account? ',
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                    children: const [TextSpan(text: 'Sign In', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600))],
                  )),
                ),
              ]),
            ),
          ),
        ])),
      ]),
    );
  }

  Widget _orb(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  PageRoute _route(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 500),
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title, desc;
  final Color color;
  const _FeatureCard({super.key, required this.icon, required this.title, required this.desc, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 12, height: 1.4)),
        ])),
      ]),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.03);
    for (double x = 0; x < size.width; x += 30) {
      for (double y = 0; y < size.height; y += 30) {
        canvas.drawCircle(Offset(x, y), 1, p);
      }
    }
  }
  @override bool shouldRepaint(_) => false;
}