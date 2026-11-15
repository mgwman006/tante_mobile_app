import 'package:flutter/material.dart';
import 'package:tante/services/tante_api.dart';

import 'create_unit_page.dart';

class PropertyDetailsPage extends StatefulWidget {
  const PropertyDetailsPage({
    super.key,
    required this.propertyId,
    required this.rentalProfileId,
    required this.api,
    required this.token,
  });

  final int propertyId;
  final int rentalProfileId;
  final TanteApi api;
  final String token;

  @override
  State<PropertyDetailsPage> createState() => _PropertyDetailsPageState();
}

class _PropertyDetailsPageState extends State<PropertyDetailsPage> {
  late Future<Map<String, dynamic>> _propertyFuture;
  final Set<int> _updatingUnitIds = {};
  final Map<int, bool> _unitListingOverrides = {};
  final Map<int, List<Map<String, dynamic>>> _addedUnitsByBuilding = {};

  @override
  void initState() {
    super.initState();
    _propertyFuture = _loadProperty();
  }

  Future<Map<String, dynamic>> _loadProperty() {
    return widget.api.getPropertyDetails(widget.propertyId, widget.token);
  }

  void _retry() {
    setState(() {
      _propertyFuture = _loadProperty();
    });
  }

  Future<void> _advertiseUnit(Map<String, dynamic> unit) async {
    final unitId = _intValue(unit['id']);
    if (unitId == null || _updatingUnitIds.contains(unitId)) return;
    if (unit['isListed'] == true || _unitListingOverrides[unitId] == true) {
      return;
    }
    setState(() => _updatingUnitIds.add(unitId));
    try {
      final isListed = await widget.api.advertiseUnit(
        unitId: unitId,
        token: widget.token,
      );
      if (!mounted) return;
      setState(() {
        _unitListingOverrides[unitId] = isListed;
        _updatingUnitIds.remove(unitId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unit is now advertised.')));
    } on TanteApiException catch (error) {
      if (!mounted) return;
      setState(() => _updatingUnitIds.remove(unitId));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _addUnit(Map<String, dynamic> building) async {
    final buildingId = _intValue(building['id']);
    if (buildingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This building has no valid ID.')),
      );
      return;
    }
    final unit = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => CreateUnitPage(
          api: widget.api,
          buildingId: buildingId,
          rentalProfileId: widget.rentalProfileId,
          token: widget.token,
        ),
      ),
    );
    if (!mounted || unit == null) return;
    setState(() {
      _addedUnitsByBuilding.putIfAbsent(buildingId, () => []).add(unit);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Property details')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _propertyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is TanteApiException
                ? error.message
                : 'Could not load property details. Please try again.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _retry,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            );
          }
          final property = snapshot.data;
          if (property == null) {
            return const Center(
              child: Text('Property details are unavailable.'),
            );
          }
          return _buildProperty(property);
        },
      ),
    );
  }

  Widget _buildProperty(Map<String, dynamic> property) {
    final buildings = _objectList(
      property['buildings'],
      'The property service returned invalid building details.',
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      children: [
        Text(
          property['name']?.toString() ?? 'Property',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          _readableEnum(property['type']),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 20),
        if (buildings.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('There are no buildings for this property yet.'),
            ),
          )
        else
          ...buildings.map(_buildBuilding),
      ],
    );
  }

  Widget _buildBuilding(Map<String, dynamic> building) {
    final units = [
      ..._objectList(
        building['units'],
        'The property service returned invalid units for a building.',
      ),
      ...?_addedUnitsByBuilding[_intValue(building['id'])],
    ];
    final number = building['number']?.toString();
    final name = building['name']?.toString();
    final title = name?.isNotEmpty == true
        ? name!
        : 'Building ${number ?? ''}'.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (building['numberOfFloors'] != null)
              Text('${building['numberOfFloors']} floors'),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _addUnit(building),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add unit'),
              ),
            ),
            if (units.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No units in this building yet.'),
              )
            else
              ...units.map(_buildUnit),
          ],
        ),
      ),
    );
  }

  Widget _buildUnit(Map<String, dynamic> unit) {
    final unitId = _intValue(unit['id']);
    final isListed =
        _unitListingOverrides[unitId] ?? (unit['isListed'] == true);
    final rent = unit['rentAmount'];
    final detailParts = <String>[
      if (unit['type'] != null) _readableEnum(unit['type']),
      '${unit['numberOfBedrooms'] ?? 0} bed',
      '${unit['numberOfBathrooms'] ?? 0} bath',
      if (rent != null) 'TSh ${_formatNumber(rent)} / month',
      if (unit['status'] != null) _readableEnum(unit['status']),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Card(
        color: const Color(0xFFF7F9FC),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Unit ${unit['unitNumber'] ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(detailParts.join(' · ')),
              const SizedBox(height: 8),
              if (isListed)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: const Icon(
                      Icons.campaign_outlined,
                      size: 18,
                      color: Color(0xFF16864A),
                    ),
                    label: const Text('Advertised'),
                    backgroundColor: const Color(0xFFE7F8E7),
                  ),
                )
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed:
                        unitId == null || _updatingUnitIds.contains(unitId)
                        ? null
                        : () => _advertiseUnit(unit),
                    icon: _updatingUnitIds.contains(unitId)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.campaign_outlined),
                    label: const Text('Advertise'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

List<Map<String, dynamic>> _objectList(Object? value, String errorMessage) {
  if (value == null) return const [];
  if (value is! List || value.any((item) => item is! Map)) {
    throw TanteApiException(errorMessage);
  }
  return value.map((item) => Map<String, dynamic>.from(item as Map)).toList();
}

int? _intValue(Object? value) {
  return value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
}

String _readableEnum(Object? value) {
  final normalized = value?.toString().trim() ?? '';
  if (normalized.isEmpty) return 'Unknown';
  return normalized
      .split('_')
      .where((word) => word.isNotEmpty)
      .map(
        (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _formatNumber(Object value) {
  final number = num.tryParse(value.toString());
  if (number == null) return value.toString();
  final whole = number.round().toString();
  return whole.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );
}
