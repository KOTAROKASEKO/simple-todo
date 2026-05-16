import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:simpletodo/services/google_sign_in_firebase.dart';

/// Email + password sign-in / register (used in onboarding and standalone login).
class EmailPasswordAuthCard extends StatefulWidget {
  const EmailPasswordAuthCard({super.key});

  @override
  State<EmailPasswordAuthCard> createState() => _EmailPasswordAuthCardState();
}

class _EmailPasswordAuthCardState extends State<EmailPasswordAuthCard> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _googleLoading = false;
  bool _isRegisterMode = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Email and password are required.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isRegisterMode) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = e.message ?? 'Authentication failed.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogleMobile() async {
    if (!GoogleSignIn.instance.supportsAuthenticate()) return;
    setState(() {
      _googleLoading = true;
      _errorMessage = null;
    });
    try {
      await signInWithGoogleUsingAuthenticate();
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message ?? 'Google sign-in failed.';
        });
      }
    } on GoogleSignInException catch (e) {
      final msg = userVisibleMessageForGoogleSignInException(e);
      if (msg != null && mounted) {
        setState(() => _errorMessage = msg);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _googleLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogleWeb() async {
    setState(() {
      _googleLoading = true;
      _errorMessage = null;
    });
    try {
      final provider = GoogleAuthProvider();
      await FirebaseAuth.instance.signInWithPopup(provider);
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message ?? 'Google sign-in failed.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = '$e');
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _isRegisterMode ? 'Create Account' : 'Sign In',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 12),
          if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _isLoading || _googleLoading ? null : _submit,
            child: Text(_isRegisterMode ? 'Register' : 'Sign in'),
          ),
          TextButton(
            onPressed: _isLoading || _googleLoading
                ? null
                : () {
                    setState(() {
                      _isRegisterMode = !_isRegisterMode;
                      _errorMessage = null;
                    });
                  },
            child: Text(
              _isRegisterMode
                  ? 'Already have an account? Sign in'
                  : 'No account yet? Register',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          if (kIsWeb)
            OutlinedButton.icon(
              onPressed: _googleLoading || _isLoading ? null : _signInWithGoogleWeb,
              icon: _googleLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.account_circle_outlined),
              label: const Text('Continue with Google'),
            )
          else if (GoogleSignIn.instance.supportsAuthenticate())
            OutlinedButton.icon(
              onPressed: _googleLoading || _isLoading ? null : _signInWithGoogleMobile,
              icon: _googleLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.account_circle_outlined),
              label: const Text('Continue with Google'),
            ),
          if (_googleLoading && kIsWeb)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
