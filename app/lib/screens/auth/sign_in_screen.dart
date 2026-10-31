import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../services/supabase_service.dart';
import '../../theme/jamjot_theme.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    this.startInCreateMode = false,
    this.emailJustConfirmed = false,
    this.linkExpired = false,
    this.intendedRole,
  });

  final bool startInCreateMode;
  final bool emailJustConfirmed;
  final bool linkExpired;

  /// 'family' or 'teacher' when they picked a card on the landing page —
  /// remembered through sign-up so onboarding can skip the question.
  final String? intendedRole;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late bool _creating = widget.startInCreateMode;
  bool _busy = false;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    final auth = JamJotBackend.client.auth;
    try {
      if (_creating) {
        final res = await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {
            'full_name': _name.text.trim(),
            if (widget.intendedRole != null)
              'intended_role': widget.intendedRole,
          },
        );
        if (res.session == null) {
          setState(() => _notice =
              'Almost there! Check your email for a confirmation link, then come back and sign in.');
          return;
        }
      } else {
        await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      if (mounted) context.go('/gate');
    } catch (e) {
      setState(() => _notice = _friendly(e.toString()));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _friendly(String raw) {
    if (raw.contains('Invalid login credentials')) {
      return 'That email and password combination did not match. Try again?';
    }
    if (raw.contains('already registered')) {
      return 'There is already an account with that email. Try signing in instead.';
    }
    if (raw.contains('Email not confirmed')) {
      return 'Please tap the confirmation link in your email first, then sign in.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(_creating ? 'Create account' : 'Sign in')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.linkExpired && !_creating) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: JamJotColors.marigoldTint,
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: JamJotColors.ink, width: 2),
                        ),
                        child: Text(
                          'That confirmation link had already been used or expired. Good news: if you clicked it before, your email is probably confirmed — just sign in below. If it says your email is not confirmed yet, create your account again with the same email and a fresh link will be sent.',
                          style: text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (widget.emailJustConfirmed && !_creating) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F3EA),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: JamJotColors.ink, width: 2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                color: JamJotColors.leaf),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your email is confirmed! Sign in below to get started.',
                                style: text.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      _creating
                          ? 'Welcome to JamJot!'
                          : 'Welcome back!',
                      style: text.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _creating
                          ? 'One grown-up account runs the whole family.'
                          : 'Sign in to pick up where you left off.',
                      style: text.bodyMedium
                          ?.copyWith(color: JamJotColors.inkSoft),
                    ),
                    const SizedBox(height: 24),
                    if (_creating) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        decoration:
                            const InputDecoration(labelText: 'Your name'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Please tell us your name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? 'Please enter a valid email'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                      validator: (v) => (v == null || v.length < 8)
                          ? 'At least 8 characters, please'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    if (_notice != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: JamJotColors.marigoldTint,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: JamJotColors.ink, width: 2),
                        ),
                        child: Text(_notice!, style: text.bodyMedium),
                      ),
                      const SizedBox(height: 12),
                    ],
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy
                          ? 'One moment…'
                          : (_creating ? 'Create my account' : 'Sign in')),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _creating = !_creating;
                                _notice = null;
                              }),
                      child: Text(_creating
                          ? 'I already have an account'
                          : 'I need to create an account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
