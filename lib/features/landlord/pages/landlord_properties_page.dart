import 'package:flutter/material.dart';

import '../widgets/landlord_dashboard_widgets.dart';

class LandlordPropertiesPage extends StatelessWidget {
  const LandlordPropertiesPage({
    super.key,
    required this.properties,
    required this.onAddProperty,
  });

  final List<Map<String, dynamic>> properties;
  final VoidCallback onAddProperty;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const Text(
          'Your properties',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: Color(0xFF102F4C),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: onAddProperty,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add property'),
          ),
        ),
        const SizedBox(height: 22),
        ...properties.isEmpty
            ? [
                const LandlordEmptyState(
                  'No properties are linked to this rental profile yet.',
                ),
              ]
            : properties.map((property) {
                final location = property['location'] is Map
                    ? Map<String, dynamic>.from(property['location'] as Map)
                    : const <String, dynamic>{};
                final rawAddress = location['address'];
                final address = rawAddress is Map
                    ? Map<String, dynamic>.from(rawAddress)
                    : const <String, dynamic>{};
                final readableAddress = rawAddress is String
                    ? rawAddress
                    : [
                            address['houseNumber'],
                            address['streetName'],
                            address['ward'],
                            address['city'],
                            address['region'],
                            address['country'],
                          ]
                          .whereType<Object>()
                          .map((part) => part.toString().trim())
                          .where((part) => part.isNotEmpty)
                          .join(', ');

                final propertyType = _formatPropertyType(property['type']);
                return PropertyDataCard(
                  icon: Icons.apartment_rounded,
                  title: property['name']?.toString() ?? 'Property',
                  type: propertyType,
                  address: readableAddress,
                );
              }).toList(),
      ],
    );
  }
}

String _formatPropertyType(Object? value) {
  final type = value?.toString().trim() ?? '';
  if (type.isEmpty) return 'Property';
  return type
      .split('_')
      .where((word) => word.isNotEmpty)
      .map(
        (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}
