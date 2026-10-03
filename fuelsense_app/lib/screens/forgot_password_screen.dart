import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _otp = TextEditingController();
  final _newPass = TextEditingController();
  final _confirmPass = TextEditingController();
  bool _loading = false;
  bool _otpSent = false;
  bool _done = false;
  bool _ob1 = true, _ob2 = true;
  String? _error;

  Future<void> _sendReset() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.requestPasswordReset(email);
    if (!mounted) return;
    setState(() => _loading = false);
    if (r.success) {
      setState(() => _otpSent = true);
    } else {
      setState(() => _error = r.error ?? 'Something went wrong');
    }
  }

  Future<void> _confirmReset() async {
    if (_otp.text.trim().length != 6) {
      setState(() => _error = 'Enter 6-digit OTP');
      return;
    }
    if (_newPass.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }
    if (_newPass.text != _confirmPass.text) {
      setState(() => _error = 'Passwords don\'t match');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final r = await ApiService.resetPassword(_email.text.trim(), _otp.text.trim(), _newPass.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (r.success) {
      setState(() => _done = true);
    } else {
      setState(() => _error = r.error ?? 'Something went wrong');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1E),
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1))),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 16),
            ),
          ),
          const SizedBox(height: 40),

          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: const Color(0xFF2563EB).withOpacity(0.1), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.2))),
            child: Icon(_done ? Icons.check_circle_outline_rounded : Icons.lock_reset_rounded, color: const Color(0xFF2563EB), size: 32),
          ),
          const SizedBox(height: 24),

          Text(_done ? 'All Done!' : 'Reset Password', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
          const SizedBox(height: 8),
          Text(
            _done
                ? 'Your password has been reset. You can now sign in.'
                : _otpSent
                    ? 'Enter the OTP sent to ${_email.text} and your new password.'
                    : 'Enter your email and we\'ll send you an OTP.',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, height: 1.5)),
          const SizedBox(height: 32),

          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFEF4444).withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.25))),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13))),
              ]),
            ),
            const SizedBox(height: 20),
          ],

          if (_done) ...[
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('Back to Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ] else if (!_otpSent) ...[
            _label('Email Address'),
            const SizedBox(height: 8),
            _field(_email, 'yourname@gmail.com', Icons.email_outlined, type: TextInputType.emailAddress),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _sendReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  disabledBackgroundColor: const Color(0xFF2563EB).withOpacity(0.4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ] else ...[
            _label('OTP Code'),
            const SizedBox(height: 8),
            _field(_otp, '6-digit code', Icons.pin_outlined, type: TextInputType.number, fmt: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)]),
            const SizedBox(height: 18),
            _label('New Password'),
            const SizedBox(height: 8),
            _field(_newPass, 'Min. 8 characters', Icons.lock_outline_rounded, obscure: _ob1,
                suffix: GestureDetector(onTap: () => setState(() => _ob1 = !_ob1),
                    child: Padding(padding: const EdgeInsets.only(right: 16), child: Icon(_ob1 ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white30, size: 20)))),
            const SizedBox(height: 18),
            _label('Confirm New Password'),
            const SizedBox(height: 8),
            _field(_confirmPass, 'Re-enter password', Icons.lock_outline_rounded, obscure: _ob2,
                suffix: GestureDetector(onTap: () => setState(() => _ob2 = !_ob2),
                    child: Padding(padding: const EdgeInsets.only(right: 16), child: Icon(_ob2 ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.white30, size: 20)))),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity, height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _confirmReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  disabledBackgroundColor: const Color(0xFF2563EB).withOpacity(0.4),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Reset Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 12),
            Center(child: TextButton(
              onPressed: _loading ? null : () => setState(() { _otpSent = false; _error = null; }),
              child: Text('Change email', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
            )),
          ],
        ]),
      )),
    );
  }

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
          controller: c,
          keyboardType: type,
          inputFormatters: fmt,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 15),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
          ),
        )),
        if (suffix != null) suffix,
      ]),
    );
}