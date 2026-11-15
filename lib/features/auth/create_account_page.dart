import 'package:flutter/material.dart';
import 'package:tante/services/tante_api.dart';

class CreateAccountRouteArgs {
  const CreateAccountRouteArgs({this.initialPhoneNumber = ''});

  final String initialPhoneNumber;
}

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({
    super.key,
    required this.api,
    this.initialPhoneNumber = '',
  });

  final TanteApi api;
  final String initialPhoneNumber;

  @override
  State<CreateAccountPage> createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final _formKey = GlobalKey<FormState>();
  late final _phoneController = TextEditingController(
    text: widget.initialPhoneNumber,
  );
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _createAccount() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final phoneNumber = _phoneController.text.replaceAll(
        RegExp(r'[\s-]'),
        '',
      );
      await widget.api.registerAccount(
        phoneNumber: phoneNumber,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, phoneNumber);
    } on TanteApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create account'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _isLoading ? null : () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join Tante',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: const Color(0xFF102F4C),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Create an account to continue.'),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      maxLength: 10,
                      decoration: const InputDecoration(
                        labelText: 'Tanzanian phone number',
                        hintText: '0712345678',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) {
                        final phone =
                            value?.replaceAll(RegExp(r'[\s-]'), '') ?? '';
                        return RegExp(r'^0[678]\d{8}$').hasMatch(phone)
                            ? null
                            : 'Enter a valid Tanzanian mobile number';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.length < 4
                          ? 'Enter a password (at least 4 characters)'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmation,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _createAccount(),
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscureConfirmation
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () => setState(
                            () => _obscureConfirmation = !_obscureConfirmation,
                          ),
                          icon: Icon(
                            _obscureConfirmation
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value != _passwordController.text
                          ? 'Passwords do not match'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _createAccount,
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Create account'),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.maybePop(context),
                        child: const Text('Already have an account? Sign in'),
                      ),
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
