import 'package:flutter/material.dart';

import '../widgets/landlord_dashboard_widgets.dart';

class LandlordLeasesPage extends StatelessWidget {
  const LandlordLeasesPage({super.key, required this.leases});

  final List<Map<String, dynamic>> leases;

  @override
  Widget build(BuildContext context) {
    return LandlordPageLayout(
      title: 'Leases',
      subtitle: 'Agreements managed through Rent Manager.',
      children: leases.isEmpty
          ? [
              const LandlordEmptyState(
                'No leases are linked to this rental profile yet.',
              ),
            ]
          : leases
                .map(
                  (lease) => LandlordInfoCard(
                    icon: Icons.description_outlined,
                    title:
                        'Lease ${lease['referenceNumber'] ?? lease['id'] ?? ''}',
                    detail:
                        'Status: ${lease['status'] ?? '—'}\nUnit: ${lease['unitId'] ?? '—'}\nTerm: ${lease['startDate'] ?? '—'} – ${lease['endDate'] ?? '—'}',
                  ),
                )
                .toList(),
    );
  }
}
