import 'package:flutter/material.dart';
import 'package:tante/services/tante_api.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _api = TanteApi();
  String _role = 'Landlord';
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final session = await _api.signIn(
        phoneNumber: _phoneController.text,
        password: _passwordController.text,
        role: _role,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home', arguments: session);
    } on TanteApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    Container(
                      height: 58,
                      width: 58,
                      decoration: BoxDecoration(
                        color: const Color(0xFF173F58),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.home_work_rounded, color: Color(0xFF83EC7F), size: 30),
                    ),
                    const SizedBox(height: 28),
                    const Text('Welcome to Tante',
                        style: TextStyle(fontSize: 30, height: 1.15, fontWeight: FontWeight.w800, color: Color(0xFF102F4C))),
                    const SizedBox(height: 8),
                    const Text('Find, rent, and manage — all in one place.',
                        style: TextStyle(fontSize: 15, color: Color(0xFF3E5674))),
                    const SizedBox(height: 32),
                    const Text('I am signing in as', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF102F4C))),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Landlord', label: Text('Landlord'), icon: Icon(Icons.apartment_rounded)),
                        ButtonSegment(value: 'Tenant', label: Text('Tenant'), icon: Icon(Icons.key_rounded)),
                      ],
                      selected: {_role},
                      onSelectionChanged: _isLoading ? null : (selection) => setState(() => _role = selection.first),
                      showSelectedIcon: false,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Tanzanian phone number',
                        hintText: '+255 712 345 678',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (value) {
                        final phone = value?.replaceAll(RegExp(r'[\s-]'), '') ?? '';
                        if (phone.isEmpty) return 'Enter your phone number';
                        if (!RegExp(r'^(\+255|255|0)[678]\d{8}$').hasMatch(phone)) {
                          return 'Enter a valid Tanzanian mobile number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _login(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (value) => value == null || value.length < 4 ? 'Enter a password (at least 4 characters)' : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showMessage('Contact Tante support to reset your password.'),
                        child: const Text('Forgot password?'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text('Log in as $_role'),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: () => _showMessage('Contact your property manager for an invitation to Tante.'),
                        child: const Text('New to Tante? Get an invitation'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text('Your role determines which property tools you see.', textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Color(0xFF3E5674))),
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
