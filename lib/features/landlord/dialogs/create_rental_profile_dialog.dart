import 'package:flutter/material.dart';
import 'package:tante/services/tante_api.dart';

class CreateRentalProfileDialog extends StatefulWidget {
  const CreateRentalProfileDialog({
    super.key,
    required this.api,
    required this.session,
  });

  final TanteApi api;
  final AuthSession session;

  @override
  State<CreateRentalProfileDialog> createState() =>
      _CreateRentalProfileDialogState();
}

class _CreateRentalProfileDialogState extends State<CreateRentalProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController();
  late final _phoneController = TextEditingController(
    text: widget.session.phoneNumber,
  );
  late final _emailController = TextEditingController(
    text: widget.session.email ?? '',
  );
  final _viewingServiceFeeController = TextEditingController(text: '0');
  String _type = 'INDIVIDUAL';
  int? _organizationId;
  bool _saving = false;

  List<Map<String, dynamic>> get _organizations =>
      widget.session.memberships.where((membership) {
        final id = membership['organizationId'];
        return id is num
            ? id > 0
            : int.tryParse(id?.toString() ?? '') != null &&
                  int.parse(id.toString()) > 0;
      }).toList();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _viewingServiceFeeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final profile = await widget.api.createRentalProfile(
        session: widget.session,
        name: _nameController.text,
        phoneNumber: _phoneController.text,
        email: _emailController.text,
        type: _type,
        viewingServiceFee: double.parse(
          _viewingServiceFeeController.text.trim(),
        ),
        organizationId: _type == 'BUSINESS' ? _organizationId : null,
      );
      if (mounted) Navigator.pop(context, profile);
    } on TanteApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final organizations = _organizations;
    final hasOrganizations = organizations.isNotEmpty;
    return AlertDialog(
      title: const Text('Create rental profile'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Create a profile to manage rental units and collect rent efficiently.',
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Rental profile name',
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a profile name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a phone number'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isNotEmpty &&
                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _viewingServiceFeeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Viewing service fee (TZS)',
                  prefixIcon: Icon(Icons.payments_outlined),
                  helperText:
                      'Fee charged to tenants when they book a viewing.',
                ),
                validator: (value) {
                  final fee = double.tryParse(value?.trim() ?? '');
                  if (fee == null || !fee.isFinite) {
                    return 'Enter a valid viewing service fee.';
                  }
                  if (fee < 0) return 'Fee cannot be negative.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Rental profile type',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'INDIVIDUAL',
                    child: Text('Individual'),
                  ),
                  DropdownMenuItem(value: 'BUSINESS', child: Text('Business')),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        _type = value ?? 'INDIVIDUAL';
                        if (_type != 'BUSINESS') _organizationId = null;
                      }),
              ),
              if (_type == 'BUSINESS') ...[
                const SizedBox(height: 12),
                if (hasOrganizations)
                  DropdownButtonFormField<int>(
                    initialValue: _organizationId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Organization',
                      prefixIcon: Icon(Icons.groups_outlined),
                    ),
                    items: organizations.map((membership) {
                      final rawId = membership['organizationId'];
                      final id = rawId is num
                          ? rawId.toInt()
                          : int.parse(rawId.toString());
                      final name = membership['organizationName']?.toString();
                      return DropdownMenuItem(
                        value: id,
                        child: Text(
                          name?.isNotEmpty == true ? name! : 'Organization $id',
                        ),
                      );
                    }).toList(),
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _organizationId = value),
                    validator: (value) =>
                        value == null ? 'Select an organization' : null,
                  )
                else
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'A business profile requires an organization membership on your account.',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving || (_type == 'BUSINESS' && !hasOrganizations)
              ? null
              : _submit,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create profile'),
        ),
      ],
    );
  }
}
