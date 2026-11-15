import 'package:flutter/material.dart';

import '../widgets/landlord_dashboard_widgets.dart';

class LandlordOverviewPage extends StatelessWidget {
  const LandlordOverviewPage({
    super.key,
    required this.profileName,
    required this.propertyCount,
    required this.leaseCount,
    required this.onOpenProperties,
    required this.onOpenLeases,
  });

  final String profileName;
  final int propertyCount;
  final int leaseCount;
  final VoidCallback onOpenProperties;
  final VoidCallback onOpenLeases;

  @override
  Widget build(BuildContext context) {
    return LandlordPageLayout(
      title: 'Your rental overview',
      subtitle: 'Live information for $profileName.',
      children: [
        LandlordMetricCard(
          label: 'Properties',
          value: '$propertyCount',
          icon: Icons.apartment_rounded,
        ),
        LandlordMetricCard(
          label: 'Leases',
          value: '$leaseCount',
          icon: Icons.description_outlined,
        ),
        const LandlordSectionHeading('Quick actions'),
        LandlordActionCard(
          icon: Icons.apartment_rounded,
          title: 'View properties',
          subtitle: 'See properties linked to this rental profile',
          onTap: onOpenProperties,
        ),
        LandlordActionCard(
          icon: Icons.description_outlined,
          title: 'Manage leases',
          subtitle: 'Review current lease agreements',
          onTap: onOpenLeases,
        ),
      ],
    );
  }
}
