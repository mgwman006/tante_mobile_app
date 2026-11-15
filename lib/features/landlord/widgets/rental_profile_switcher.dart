import 'package:flutter/material.dart';

import '../rental_profile_utils.dart';

Future<Map<String, dynamic>?> showRentalProfileSwitcher({
  required BuildContext context,
  required List<Map<String, dynamic>> profiles,
  required Object? selectedProfileId,
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Text(
              'Choose a rental profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          ...profiles.map(
            (profile) => ListTile(
              leading: const Icon(Icons.business_outlined),
              title: Text(profile['name']?.toString() ?? 'Rental profile'),
              subtitle: Text(rentalProfileTypeLabel(profile['type'])),
              trailing: profile['id'] == selectedProfileId
                  ? const Icon(Icons.check_circle, color: Color(0xFF19A75C))
                  : null,
              onTap: () => Navigator.pop(context, profile),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_business_outlined),
            title: const Text('Create rental profile'),
            onTap: () =>
                Navigator.pop(context, <String, dynamic>{'__create__': true}),
          ),
        ],
      ),
    ),
  );
}
