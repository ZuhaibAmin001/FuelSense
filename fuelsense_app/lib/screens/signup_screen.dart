import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'dashboard_screen.dart';

class SignupScreen extends StatefulWidget {
  final String role;
  const SignupScreen({super.key, this.role = 'driver'});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
  int _step = 0;
  final _name  = TextEditingController();
  final _phone = TextEditingController();
  final _cnic  = TextEditingController();
  final _pass  = TextEditingController();
  final _conf  = TextEditingController();
  final List<TextEditingController> _otp = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _foci = List.generate(6, (_) => FocusNode());
  bool _loading = false, _ob1 = true, _ob2 = true;
  String? _error;

  List<Map<String, dynamic>> _stations = [];
  int? _selectedStationId;
  bool _stationsLoading = false;

  late AnimationController _pageCtrl;
  late Animation<Offset> _pageSlide;

  @override
  void initState() {
    super.initState();
    _pageCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _pageSlide = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageCtrl, curve: Curves.easeOutCubic));
    _pageCtrl.forward();
    if (widget.role == 'owner') _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() => _stationsLoading = true);
    final r = await ApiService.getStationsList();
    if (!mounted) return;
    if (r.success) {
      setState(() {
        _stations = List<Map<String, dynamic>>.from(r.data['stations'] ?? []);
        _stationsLoading = false;
      });
    } else {
      setState(() => _stationsLoading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose(); _phone.dispose(); _cnic.dispose();
    _pass.dispose(); _conf.dispose();
    for (var c in _otp) c.dispose();
    for (var f in _foci) f.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    _pageCtrl.forward(from: 0);
    setState(() { _step++; _error = null; });
  }

  Future<void> _sendOtp() async {
    if (_name.text.trim().isEmpty) { setState(() => _error = 'Enter your full name'); return; }
    if (_phone.text.trim().length < 11) { setState(() => _error = 'Enter a valid 11-digit phone number'); return; }
    if (_cnic.text.trim().length != 13) { setState(() => _error = 'CNIC must be 13 digits (no dashes)'); return; }
    if (widget.role == 'owner' && _selectedStationId == null) { setState(() => _error = 'Please select your station'); return; }

    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _loading = false);
    _nextStep();
  }

  Future<void> _verifyOtp() async {
    setState(() { _loading = true; _error = null; });
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _loading = false);
    _nextStep();
  }

  Future<void> _finish() async {
    if (_pass.text.length < 8) { setState(() => _error = 'Password must be at least 8 characters'); return; }
    if (_pass.text != _conf.text) { setState(() => _error = 'Passwords don\'t match'); return; }
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.signup(
      fullName: _name.text.trim(),
      phone: _phone.text.trim(),
      cnic: _cnic.text.trim(),
      password: _pass.text,
      role: widget.role,
      stationId: widget.role == 'owner' ? _selectedStationId : null,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (r.success) {
      Navigator.pushAndRemoveUntil(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.role == 'owner'
            ? DashboardScreen(stationId: _selectedStationId!)
            : const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ), (_) => false);
    } else {
      setState(() => _error = r.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: Stack(children: [
        CustomPaint(size: MediaQuery.of(context).size, painter: _DotPainter()),
        Positioned(bottom: -100, left: -80, child: _orb(300, const Color(0xFF2563EB).withOpacity(0.07))),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(children: [
                GestureDetector(
                  onTap: () { if (_step > 0) setState(() { _step--; _error = null; }); else Navigator.pop(context); },
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
                const SizedBox(width: 16),
                Expanded(child: Row(children: List.generate(3, (i) => Expanded(child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  height: 3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i <= _step ? const Color(0xFF2563EB) : Colors.white.withOpacity(0.1),
                  ),
                ))))),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_step + 1}/3', style: const TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
            Expanded(
              child: SlideTransition(
                position: _pageSlide,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          _step == 0 ? 'Create your\naccount' : _step == 1 ? 'Verify your\nphone' : 'Set your\npassword',
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -0.8),
                        ),
                      ),
                      if (_step == 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: (widget.role == 'owner' ? const Color(0xFF8B5CF6) : const Color(0xFF2563EB)).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.role == 'owner' ? 'Owner' : 'Driver',
                            style: TextStyle(color: widget.role == 'owner' ? const Color(0xFF8B5CF6) : const Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 10),
                    Text(
                      _step == 0 ? 'Enter your details to get started'
                          : _step == 1 ? 'OTP sent to +92${_phone.text.length > 1 ? _phone.text.substring(1) : _phone.text}'
                          : 'Choose a strong password to protect your account',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    if (_error != null) ...[
                      Container(
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
                      const SizedBox(height: 20),
                    ],
                    if (_step == 0) ..._buildStep0(),
                    if (_step == 1) ..._buildStep1(),
                    if (_step == 2) ..._buildStep2(),
                    const SizedBox(height: 32),
                    if (_step == 1) ...[
                      Center(child: TextButton(
                        onPressed: _loading ? null : () {
                          for (var c in _otp) c.clear();
                          setState(() { _step = 0; _error = null; });
                        },
                        child: Text('Didn\'t receive OTP? Resend', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
                      )),
                      const SizedBox(height: 8),
                    ],
                    SizedBox(
                      width: double.infinity, height: 56,
                      child: ElevatedButton(
                        onPressed: _loading ? null : (_step == 0 ? _sendOtp : _step == 1 ? _verifyOtp : _finish),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          disabledBackgroundColor: const Color(0xFF2563EB).withOpacity(0.4),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _loading
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : Text(
                                _step == 0 ? 'Send OTP' : _step == 1 ? 'Verify & Continue' : 'Create Account',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                      ),
                    ),
                    if (_step == 0) ...[
                      const SizedBox(height: 20),
                      Center(child: GestureDetector(
                        onTap: () => Navigator.pushReplacement(context, PageRouteBuilder(
                          pageBuilder: (_, __, ___) => const LoginScreen(),
                          transitionDuration: const Duration(milliseconds: 400),
                          transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                        )),
                        child: RichText(text: TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
                          children: const [TextSpan(text: 'Sign In', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600))],
                        )),
                      )),
                    ],
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _buildStep0() => [
    _label('Full Name'), const SizedBox(height: 8), _field(_name, 'e.g. Zuhaib Amin', Icons.person_outline_rounded),
    const SizedBox(height: 18),
    _label('Phone Number'), const SizedBox(height: 8),
    _field(_phone, '03001234567', Icons.phone_android_rounded, type: TextInputType.phone, fmt: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)]),
    const SizedBox(height: 18),
    _label('CNIC (13 digits, no dashes)'), const SizedBox(height: 8),
    _field(_cnic, '3740512345678', Icons.badge_outlined, type: TextInputType.number, fmt: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(13)]),
    if (widget.role == 'owner') ...[
      const SizedBox(height: 18),
      _label('Select Your Station'), const SizedBox(height: 8),
      _stationsLoading
          ? const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 2)))
          : Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.08)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedStationId,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF0D1425),
                  hint: Text('Choose a station', style: TextStyle(color: Colors.white.withOpacity(0.3))),
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  items: _stations.map<DropdownMenuItem<int>>((s) => DropdownMenuItem<int>(
                    value: s['id'] as int,
                    child: Text(s['name'].toString(), overflow: TextOverflow.ellipsis),
                  )).toList(),
                  onChanged: (v) => setState(() => _selectedStationId = v),
                ),
              ),
            ),
    ],
  ];

  List<Widget> _buildStep1() => [
    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(6, (i) => _otpBox(i))),
  ];

  Widget _otpBox(int i) => SizedBox(
    width: 46, height: 58,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _otp[i].text.isNotEmpty ? const Color(0xFF2563EB).withOpacity(0.1) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _otp[i].text.isNotEmpty ? const Color(0xFF2563EB).withOpacity(0.5) : Colors.white.withOpacity(0.1),
          width: _otp[i].text.isNotEmpty ? 1.5 : 1,
        ),
      ),
      child: TextField(
        controller: _otp[i], focusNode: _foci[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
        decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (v) {
          if (v.isNotEmpty && i < 5) _foci[i + 1].requestFocus();
          else if (v.isEmpty && i > 0) _foci[i - 1].requestFocus();
          setState(() {});
        },
      ),
    ),
  );

  List<Widget> _buildStep2() => [
    _label('Password'), const SizedBox(height: 8),
    _field(_pass, 'Min. 8 characters', Icons.lock_outline_rounded, obscure: _ob1,
        suffix: GestureDetector(onTap: () => setState(() => _ob1 = !_ob1),
            child: Padding(padding: const EdgeInsets.only(right: 16), child: Icon(_ob1 ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white30, size: 20)))),
    const SizedBox(height: 18),
    _label('Confirm Password'), const SizedBox(height: 8),
    _field(_conf, 'Re-enter password', Icons.lock_outline_rounded, obscure: _ob2,
        suffix: GestureDetector(onTap: () => setState(() => _ob2 = !_ob2),
            child: Padding(padding: const EdgeInsets.only(right: 16), child: Icon(_ob2 ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white30, size: 20)))),
  ];

  Widget _label(String t) => Text(t, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3));

  Widget _field(TextEditingController c, String hint, IconData icon, {TextInputType? type, List<TextInputFormatter>? fmt, bool obscure = false, Widget? suffix}) =>
    Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(children: [
        Padding(padding: const EdgeInsets.only(left: 16), child: Icon(icon, color: Colors.white.withOpacity(0.25), size: 20)),
        Expanded(child: TextField(
          controller: c, keyboardType: type, inputFormatters: fmt, obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 15), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18)),
        )),
        if (suffix != null) suffix,
      ]),
    );

  Widget _orb(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));
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