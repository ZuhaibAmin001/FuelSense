import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'signup_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  bool _loading = false, _obscure = true;
  String? _error;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
  }

  @override
  void dispose() { _phone.dispose(); _pass.dispose(); _shakeCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    if (_phone.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      _shakeCtrl.forward(from: 0);
      return;
    }
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.login(_phone.text.trim(), _pass.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (r.success) {
      Navigator.pushAndRemoveUntil(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ), (_) => false);
    } else {
      setState(() => _error = r.error ?? 'Login failed');
      _shakeCtrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: Stack(children: [
        CustomPaint(size: MediaQuery.of(context).size, painter: _DotPainter()),
        Positioned(top: -100, right: -80, child: _orb(280, const Color(0xFF2563EB).withOpacity(0.07))),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 16),
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 16),
                ),
              ),
              const SizedBox(height: 40),

              // Header
              Text('Welcome\nback.', style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -1,
              )),
              const SizedBox(height: 12),
              Text('Sign in to your FuelSense account', style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 15,
              )),
              const SizedBox(height: 48),

              // Error banner
              if (_error != null) ...[
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(10 * (0.5 - (_shakeAnim.value % 1)).abs() * (1 - _shakeAnim.value), 0),
                    child: child,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.25)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13))),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Phone field
              _buildLabel('Phone Number'),
              const SizedBox(height: 8),
              _buildField(
                controller: _phone,
                hint: '03001234567',
                icon: Icons.phone_android_rounded,
                keyboardType: TextInputType.phone,
                formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
              ),
              const SizedBox(height: 20),

              // Password field
              _buildLabel('Password'),
              const SizedBox(height: 8),
              _buildField(
                controller: _pass,
                hint: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
                suffix: GestureDetector(
                  onTap: () => setState(() => _obscure = !_obscure),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white30, size: 20),
                  ),
                ),
                onSubmit: (_) => _login(),
              ),
              const SizedBox(height: 40),

              // Login button
              SizedBox(
                width: double.infinity, height: 56,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      disabledBackgroundColor: const Color(0xFF2563EB).withOpacity(0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Divider
              Row(children: [
                Expanded(child: Divider(color: Colors.white.withOpacity(0.08), height: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('or', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13)),
                ),
                Expanded(child: Divider(color: Colors.white.withOpacity(0.08), height: 1)),
              ]),
              const SizedBox(height: 28),

              // Signup
              Center(child: GestureDetector(
                onTap: () => Navigator.pushReplacement(context, PageRouteBuilder(
                  pageBuilder: (_, __, ___) => const SignupScreen(),
                  transitionDuration: const Duration(milliseconds: 400),
                  transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                )),
                child: RichText(text: TextSpan(
                  text: "Don't have an account? ",
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                  children: const [TextSpan(text: 'Create one', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600))],
                )),
              )),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildLabel(String text) => Text(text, style: TextStyle(
    color: Colors.white.withOpacity(0.6),
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  ));

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    bool obscure = false,
    Widget? suffix,
    Function(String)? onSubmit,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(children: [
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Icon(icon, color: Colors.white.withOpacity(0.25), size: 20),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: formatters,
            obscureText: obscure,
            onSubmitted: onSubmit,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 15),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
            ),
          ),
        ),
        if (suffix != null) suffix,
      ]),
    );
  }

  Widget _orb(double size, Color color) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(0.025);
    for (double x = 0; x < size.width; x += 30) {
      for (double y = 0; y < size.height; y += 30) {
        canvas.drawCircle(Offset(x, y), 1, p);
      }
    }
  }
  @override bool shouldRepaint(_) => false;
}