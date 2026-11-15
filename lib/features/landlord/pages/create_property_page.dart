import 'package:flutter/material.dart';
import 'package:tante/services/tante_api.dart';

class CreatePropertyPage extends StatefulWidget {
  const CreatePropertyPage({
    super.key,
    required this.api,
    required this.session,
    required this.rentalProfileId,
  });

  final TanteApi api;
  final AuthSession session;
  final int rentalProfileId;

  @override
  State<CreatePropertyPage> createState() => _CreatePropertyPageState();
}

class _CreatePropertyPageState extends State<CreatePropertyPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _houseNumberController = TextEditingController();
  final _streetController = TextEditingController();
  final _wardController = TextEditingController();
  final _cityController = TextEditingController();
  final _regionController = TextEditingController();
  final _countryController = TextEditingController();
  final _buildingsController = TextEditingController(text: '1');
  String _type = 'STAND_ALONE_HOUSE';
  String _developmentStatus = 'OPERATIONAL';
  bool _saving = false;
  bool _completed = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _houseNumberController.dispose();
    _streetController.dispose();
    _wardController.dispose();
    _cityController.dispose();
    _regionController.dispose();
    _countryController.dispose();
    _buildingsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    final address = <String, dynamic>{
      if (_houseNumberController.text.trim().isNotEmpty)
        'houseNumber': int.tryParse(_houseNumberController.text.trim()),
      'streetName': _streetController.text.trim(),
      if (_wardController.text.trim().isNotEmpty)
        'ward': _wardController.text.trim(),
      'city': _cityController.text.trim(),
      'region': _regionController.text.trim(),
      'country': _countryController.text.trim(),
    };

    setState(() => _saving = true);
    try {
      final property = await widget.api.createProperty(
        rentalProfileId: widget.rentalProfileId,
        createdByUserId: widget.session.userId,
        token: widget.session.token,
        name: _nameController.text,
        type: _type,
        numberOfBuildings: int.parse(_buildingsController.text.trim()),
        address: address,
        locationName: _cityController.text.trim(),
        description: _descriptionController.text,
        developmentStatus: _developmentStatus,
      );
      if (mounted) {
        _completed = true;
        FocusManager.instance.primaryFocus?.unfocus();
        Navigator.pop(context, property);
      }
    } on TanteApiException catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      } else {
        rethrow;
      }
    } finally {
      if (mounted && !_completed && _saving) {
        setState(() => _saving = false);
      }
    }
  }

  String? _required(String? value, String label) {
    return value == null || value.trim().isEmpty ? 'Enter $label.' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add property'),
        leading: IconButton(
          tooltip: 'Cancel',
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              'Property details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('property-name-field'),
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Property name'),
              validator: (value) => _required(value, 'a property name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Property type'),
              items: const [
                DropdownMenuItem(value: 'LAND', child: Text('Land')),
                DropdownMenuItem(
                  value: 'STAND_ALONE_HOUSE',
                  child: Text('Stand-alone house'),
                ),
                DropdownMenuItem(
                  value: 'APARTMENTS_BUILDING',
                  child: Text('Apartment building'),
                ),
                DropdownMenuItem(value: 'COMPOUND', child: Text('Compound')),
                DropdownMenuItem(value: 'COMPLEX', child: Text('Complex')),
              ],
              onChanged: _saving
                  ? null
                  : (value) =>
                        setState(() => _type = value ?? 'STAND_ALONE_HOUSE'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _developmentStatus,
              decoration: const InputDecoration(
                labelText: 'Development status',
              ),
              items: const [
                DropdownMenuItem(value: 'PLANNING', child: Text('Planning')),
                DropdownMenuItem(
                  value: 'UNDER_CONSTRUCTION',
                  child: Text('Under construction'),
                ),
                DropdownMenuItem(value: 'COMPLETED', child: Text('Completed')),
                DropdownMenuItem(
                  value: 'OPERATIONAL',
                  child: Text('Operational'),
                ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(
                      () => _developmentStatus = value ?? 'OPERATIONAL',
                    ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _buildingsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Number of buildings',
              ),
              validator: (value) {
                final count = int.tryParse(value?.trim() ?? '');
                return count == null || count < 1
                    ? 'Enter at least 1 building.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
            ),
            const SizedBox(height: 16),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Property address',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _houseNumberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'House / plot number (optional)',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return null;
                return int.tryParse(value.trim()) == null
                    ? 'Enter a valid number.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('property-street-field'),
              controller: _streetController,
              decoration: const InputDecoration(labelText: 'Street'),
              validator: (value) => _required(value, 'a street'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _wardController,
              decoration: const InputDecoration(labelText: 'Ward (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('property-city-field'),
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'City'),
              validator: (value) => _required(value, 'a city'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('property-region-field'),
              controller: _regionController,
              decoration: const InputDecoration(labelText: 'Region'),
              validator: (value) => _required(value, 'a region'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('property-country-field'),
              controller: _countryController,
              decoration: const InputDecoration(labelText: 'Country'),
              validator: (value) => _required(value, 'a country'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create property'),
        ),
      ),
    );
  }
}
