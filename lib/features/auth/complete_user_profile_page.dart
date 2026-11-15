import 'package:flutter/material.dart';
import 'package:tante/services/tante_api.dart';

class CompleteUserProfileRouteArgs {
  const CompleteUserProfileRouteArgs({
    required this.phoneNumber,
    required this.token,
    required this.role,
  });

  final String phoneNumber;
  final String token;
  final String role;
}

class CompleteUserProfilePage extends StatefulWidget {
  const CompleteUserProfilePage({
    super.key,
    required this.api,
    required this.phoneNumber,
    required this.token,
    required this.role,
  });

  final TanteApi api;
  final String phoneNumber;
  final String token;
  final String role;

  @override
  State<CompleteUserProfilePage> createState() =>
      _CompleteUserProfilePageState();
}

class _CompleteUserProfilePageState extends State<CompleteUserProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _createProfile() async {
    if (_isLoading || !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final session = await widget.api.createUserProfile(
        phoneNumber: widget.phoneNumber,
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        token: widget.token,
        role: widget.role,
      );
      if (mounted) Navigator.pop(context, session);
    } on TanteApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _requiredName(String? value, String name) {
    return value == null || value.trim().isEmpty ? 'Enter your $name.' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete your profile'),
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
                      'How can we address you?',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: const Color(0xFF102F4C),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Add your name to finish setting up your Tante profile.',
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'First name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) => _requiredName(value, 'first name'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _createProfile(),
                      decoration: const InputDecoration(
                        labelText: 'Last name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) => _requiredName(value, 'last name'),
                    ),
                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      child: Text(widget.phoneNumber),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _createProfile,
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save and continue'),
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
