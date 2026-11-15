import 'package:flutter/material.dart';

import '../rental_profile_utils.dart';

class RentalProfilePickerPage extends StatelessWidget {
  const RentalProfilePickerPage({
    super.key,
    required this.profiles,
    required this.onSelectProfile,
    required this.onCreateProfile,
    required this.onLogout,
  });

  final List<Map<String, dynamic>> profiles;
  final ValueChanged<Map<String, dynamic>> onSelectProfile;
  final VoidCallback onCreateProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a rental profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Welcome to Tante',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: Color(0xFF102F4C),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a landlord or agent profile to continue, or create a new profile.',
          ),
          const SizedBox(height: 20),
          if (profiles.isEmpty) ...[
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.business_outlined,
                      size: 38,
                      color: Color(0xFF19A75C),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No rental profiles yet',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Create a profile to manage properties and rental activity.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
          ...profiles.map(
            (profile) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.business_outlined),
                ),
                title: Text(
                  profile['name']?.toString() ?? 'Rental profile',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${rentalProfileTypeLabel(profile['type'])} profile'
                  '${profile['organizationName'] == null ? '' : ' · ${profile['organizationName']}'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onSelectProfile(profile),
              ),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: onCreateProfile,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Create rental profile'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
