import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autoreel/nav.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/providers/auth_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class LoginPage extends StatefulWidget {
  final String? redirectTo;
  const LoginPage({super.key, this.redirectTo});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _isSignup = false;
  bool _busy = false;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String _friendlyMessageForAuthCode(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
        return 'Incorrect username/email or password';
      case 'user-not-found':
        return 'Account not found. Check your username/email or create an account';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'network-request-failed':
        return 'Network error. Check your connection';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'invalid-email':
        return 'Invalid email';
      case 'email-already-in-use':
        return 'Email already in use';
      case 'weak-password':
        return 'Password is too weak';
      default:
        return 'Authentication failed. Please try again';
    }
  }

  Future<void> _onSubmit() async {
    final identifierOrUsername = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final email = _emailCtrl.text.trim();

    if (!_isSignup) {
      if (identifierOrUsername.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter username/email and password')));
        return;
      }
    } else {
      if (identifierOrUsername.isEmpty || email.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter username, email and password')));
        return;
      }
      if (password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
        return;
      }
      if (!email.contains('@')) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid email')));
        return;
      }
    }

    setState(() => _busy = true);
    try {
      final auth = context.read<AuthProvider>();
      if (_isSignup) {
        await auth.signUpWithUsernameEmailPassword(username: identifierOrUsername, email: email, password: password);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Check your email for welcome message')));
        }
      } else {
        await auth.loginWithIdentifierPassword(identifier: identifierOrUsername, password: password);
      }
      if (!mounted) return;
      final target = widget.redirectTo ?? AppRoutes.home;
      context.go(target);
    } on fb.FirebaseAuthException catch (e) {
      debugPrint('Login/Signup error: $e');
      final msg = _friendlyMessageForAuthCode(e.code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      debugPrint('Auth submit error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: AppSpacing.xl),
                Icon(Icons.directions_car_filled, size: 72, color: cs.primary),
                const SizedBox(height: AppSpacing.sm),
                Text('Motix', style: context.textStyles.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface), textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xl),
                Container(
                  decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: cs.outline.withValues(alpha: 0.08))),
                  padding: AppSpacing.paddingLg,
                  child: Column(children: [
                    Row(children: [
                      Expanded(child: _AuthTab(label: 'Login', selected: !_isSignup, onTap: () => setState(() => _isSignup = false))),
                      const SizedBox(width: 8),
                      Expanded(child: _AuthTab(label: 'Sign up', selected: _isSignup, onTap: () => setState(() => _isSignup = true))),
                    ]),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _usernameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _isSignup ? 'Username' : 'Username or Email',
                        hintText: _isSignup ? 'yourname' : 'yourname or you@example.com',
                        filled: true,
                        fillColor: cs.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _passwordCtrl,
                      obscureText: true,
                      textInputAction: _isSignup ? TextInputAction.next : TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        filled: true,
                        fillColor: cs.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                      ),
                    ),
                    if (_isSignup) ...[
                      const SizedBox(height: AppSpacing.md),
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Email',
                          hintText: 'you@example.com',
                          filled: true,
                          fillColor: cs.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                        ),
                      ),
                    ]
                  ]),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _busy ? null : _onSubmit,
                    style: ElevatedButton.styleFrom(backgroundColor: MarketplaceColors.accentYellow, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)), elevation: 0),
                    child: _busy ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black))) : Text(_isSignup ? 'Create account' : 'Login', style: context.textStyles.titleMedium?.bold.withColor(Colors.black)),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('By continuing, you agree to our Terms & Privacy Policy', style: context.textStyles.bodySmall?.copyWith(color: cs.onSurfaceVariant), textAlign: TextAlign.center),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthTab extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _AuthTab({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? Colors.black.withValues(alpha: 0.1) : Colors.transparent, width: 1)),
          child: Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: selected ? Colors.black : cs.onSurface)),
        ),
      ),
    );
  }
}
