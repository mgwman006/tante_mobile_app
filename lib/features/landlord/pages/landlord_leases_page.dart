import 'package:flutter/material.dart';

import '../../../services/tante_api.dart';
import 'create_lease_page.dart';
import 'lease_details_page.dart';
import '../widgets/landlord_dashboard_widgets.dart';

const _leaseStatuses = [
  'ACTIVE',
  'ENDED',
  'TERMINATED',
  'PENDING',
  'PENDING_LANDLORD_APPROVAL',
  'PENDING_TENANT_APPROVAL',
];

class LandlordLeasesPage extends StatefulWidget {
  const LandlordLeasesPage({
    super.key,
    required this.leases,
    this.api,
    this.token,
    this.rentalProfileId,
    this.payerUserId,
    this.onLeaseCreated,
  });

  final List<Map<String, dynamic>> leases;
  final TanteApi? api;
  final String? token;
  final int? rentalProfileId;
  final int? payerUserId;
  final ValueChanged<Map<String, dynamic>>? onLeaseCreated;

  @override
  State<LandlordLeasesPage> createState() => _LandlordLeasesPageState();
}

class _LandlordLeasesPageState extends State<LandlordLeasesPage> {
  String _selectedStatus = 'ALL';

  Future<void> _createLease() async {
    final api = widget.api;
    final token = widget.token;
    final rentalProfileId = widget.rentalProfileId;
    if (api == null || token == null || rentalProfileId == null) return;
    final lease = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => CreateLeasePage(
          api: api,
          rentalProfileId: rentalProfileId,
          token: token,
        ),
      ),
    );
    if (lease != null && mounted) widget.onLeaseCreated?.call(lease);
  }

  @override
  Widget build(BuildContext context) {
    final filteredLeases = _selectedStatus == 'ALL'
        ? widget.leases
        : widget.leases
              .where(
                (lease) =>
                    lease['status']?.toString().trim().toUpperCase() ==
                    _selectedStatus,
              )
              .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        const Text(
          'Your leases',
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: Color(0xFF102F4C),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Agreements managed through Rent Manager.'),
        if (widget.api != null &&
            widget.token != null &&
            widget.rentalProfileId != null) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const ValueKey('create-lease-button'),
              onPressed: _createLease,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create lease'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: const ValueKey('lease-status-filter'),
          initialValue: _selectedStatus,
          decoration: const InputDecoration(
            labelText: 'Filter by status',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
            ..._leaseStatuses.map(
              (status) => DropdownMenuItem(
                value: status,
                child: Text(_readableLeaseValue(status)),
              ),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _selectedStatus = value);
          },
        ),
        const SizedBox(height: 16),
        ...widget.leases.isEmpty
            ? [
                const LandlordEmptyState(
                  'No leases are linked to this rental profile yet.',
                ),
              ]
            : filteredLeases.isEmpty
            ? [const LandlordEmptyState('No leases match the selected status.')]
            : filteredLeases.map((lease) {
                final startDate = _displayValue(lease['startDate']);
                final endDate = _displayValue(lease['endDate']);
                final status = lease['status']?.toString() ?? '';
                final leaseId = _intValue(lease['id']);
                return LeaseDataCard(
                  title:
                      'Lease ${lease['referenceNumber'] ?? lease['id'] ?? ''}',
                  status: _readableLeaseValue(status),
                  statusColor: _leaseStatusColor(status),
                  detail: 'Term: $startDate – $endDate',
                  onTap:
                      leaseId == null ||
                          widget.api == null ||
                          widget.token == null
                      ? null
                      : () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (context) => LeaseDetailsPage(
                              leaseId: leaseId,
                              token: widget.token!,
                              api: widget.api!,
                              rentalProfileId: widget.rentalProfileId,
                              payerUserId: widget.payerUserId,
                            ),
                          ),
                        ),
                );
              }),
      ],
    );
  }
}

Color _leaseStatusColor(String status) {
  return switch (status.trim().toUpperCase()) {
    'ACTIVE' => Colors.green.shade700,
    'TERMINATED' => Colors.red.shade700,
    'PENDING' ||
    'PENDING_LANDLORD_APPROVAL' ||
    'PENDING_TENANT_APPROVAL' => Colors.orange.shade800,
    'ENDED' => Colors.grey.shade700,
    _ => Colors.grey.shade700,
  };
}

String _displayValue(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '—' : text;
}

String _readableLeaseValue(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return 'Unknown status';
  return text
      .split('_')
      .where((word) => word.isNotEmpty)
      .map(
        (word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

int? _intValue(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
