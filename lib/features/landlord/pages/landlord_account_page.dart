import 'package:flutter/material.dart';

import '../rental_profile_utils.dart';
import '../widgets/landlord_dashboard_widgets.dart';

class LandlordAccountPage extends StatelessWidget {
  const LandlordAccountPage({
    super.key,
    required this.profile,
    required this.fallbackPhoneNumber,
    required this.onSwitchProfile,
    required this.onLogout,
  });

  final Map<String, dynamic> profile;
  final String fallbackPhoneNumber;
  final VoidCallback onSwitchProfile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final email = profile['email']?.toString() ?? '';
    final name = profile['name']?.toString() ?? 'Rental profile';
    return LandlordPageLayout(
      title: 'Account',
      subtitle: 'Your Tante landlord or agent account.',
      children: [
        LandlordDataCard(
          icon: Icons.business_outlined,
          title: name,
          detail: '${rentalProfileTypeLabel(profile['type'])} rental profile',
        ),
        LandlordDataCard(
          icon: Icons.phone_outlined,
          title: 'Phone number',
          detail: profile['phoneNumber']?.toString() ?? fallbackPhoneNumber,
        ),
        if (email.isNotEmpty)
          LandlordDataCard(
            icon: Icons.email_outlined,
            title: 'Email',
            detail: email,
          ),
        OutlinedButton.icon(
          onPressed: onSwitchProfile,
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Switch rental profile'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Log out'),
        ),
      ],
    );
  }
}
