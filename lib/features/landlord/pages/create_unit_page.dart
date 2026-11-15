import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tante/services/tante_api.dart';

class CreateUnitPage extends StatefulWidget {
  const CreateUnitPage({
    super.key,
    required this.api,
    required this.buildingId,
    required this.rentalProfileId,
    required this.token,
  });

  final TanteApi api;
  final int buildingId;
  final int rentalProfileId;
  final String token;

  @override
  State<CreateUnitPage> createState() => _CreateUnitPageState();
}

class _CreateUnitPageState extends State<CreateUnitPage> {
  final _formKey = GlobalKey<FormState>();
  final _unitNumberController = TextEditingController();
  final _bedroomsController = TextEditingController(text: '0');
  final _bathroomsController = TextEditingController(text: '1');
  final _parkingController = TextEditingController(text: '0');
  final _rentController = TextEditingController();
  final _roomSizeController = TextEditingController();
  String _type = 'FLAT';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _unitNumberController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _parkingController.dispose();
    _rentController.dispose();
    _roomSizeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final unit = await widget.api.createUnit(
        buildingId: widget.buildingId,
        rentalProfileId: widget.rentalProfileId,
        token: widget.token,
        unitNumber: _unitNumberController.text,
        numberOfBedrooms: int.parse(_bedroomsController.text),
        numberOfBathrooms: int.parse(_bathroomsController.text),
        numberParkingSpots: int.parse(_parkingController.text),
        rentAmount: double.parse(_rentController.text.replaceAll(',', '')),
        type: _type,
        roomSize: _roomSizeController.text.trim().isEmpty
            ? null
            : int.parse(_roomSizeController.text.trim()),
        sizeUnit: _roomSizeController.text.trim().isEmpty ? null : 'SQM',
      );
      if (!mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.pop(context, unit);
    } on TanteApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _nonNegativeInteger(String? value, String label) {
    final number = int.tryParse(value?.trim() ?? '');
    if (number == null || number < 0) return 'Enter a valid $label.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add unit'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _saving ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text('Unit details', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              key: const ValueKey('new-unit-number'),
              controller: _unitNumberController,
              decoration: const InputDecoration(labelText: 'Unit number'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a unit number.'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Unit type'),
              items: const [
                DropdownMenuItem(value: 'FLAT', child: Text('Flat')),
                DropdownMenuItem(value: 'HOUSE', child: Text('House')),
                DropdownMenuItem(value: 'ROOM', child: Text('Room')),
                DropdownMenuItem(value: 'OFFICE', child: Text('Office')),
                DropdownMenuItem(value: 'SHOP', child: Text('Shop')),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _type = value ?? 'FLAT'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('new-unit-bedrooms'),
              controller: _bedroomsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Bedrooms'),
              validator: (value) => _nonNegativeInteger(value, 'bedroom count'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('new-unit-bathrooms'),
              controller: _bathroomsController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Bathrooms'),
              validator: (value) =>
                  _nonNegativeInteger(value, 'bathroom count'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('new-unit-parking'),
              controller: _parkingController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Parking spaces'),
              validator: (value) => _nonNegativeInteger(value, 'parking count'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('new-unit-rent'),
              controller: _rentController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monthly rent (TSh)',
              ),
              validator: (value) {
                final amount = double.tryParse(
                  (value ?? '').replaceAll(',', '').trim(),
                );
                return amount == null || amount <= 0
                    ? 'Enter a rent amount greater than zero.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('new-unit-room-size'),
              controller: _roomSizeController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Room size in square metres (optional)',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
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
              : const Text('Create unit'),
        ),
      ),
    );
  }
}
