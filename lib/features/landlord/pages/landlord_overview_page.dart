import 'package:flutter/material.dart';

import '../widgets/landlord_dashboard_widgets.dart';

class LandlordOverviewPage extends StatelessWidget {
  const LandlordOverviewPage({
    super.key,
    required this.profileName,
    required this.propertyCount,
    required this.leaseCount,
    required this.viewingCount,
    required this.onOpenProperties,
    required this.onOpenLeases,
    required this.onOpenViewings,
  });

  final String profileName;
  final int propertyCount;
  final int leaseCount;
  final int viewingCount;
  final VoidCallback onOpenProperties;
  final VoidCallback onOpenLeases;
  final VoidCallback onOpenViewings;

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
        LandlordMetricCard(
          label: 'Viewing bookings',
          value: '$viewingCount',
          icon: Icons.event_available_outlined,
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
        LandlordActionCard(
          icon: Icons.event_available_outlined,
          title: 'Manage viewing bookings',
          subtitle: 'Approve requests and record viewing outcomes',
          onTap: onOpenViewings,
        ),
      ],
    );
  }
}
