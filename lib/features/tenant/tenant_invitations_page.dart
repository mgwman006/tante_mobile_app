import 'package:flutter/material.dart';

import '../../services/tante_api.dart';
import '../landlord/widgets/lease_terms_editor.dart';

class TenantInvitationsPage extends StatelessWidget {
  const TenantInvitationsPage({
    super.key,
    required this.invitations,
    required this.error,
    required this.session,
    required this.api,
    required this.onRetry,
    required this.onAccepted,
  });

  final List<Map<String, dynamic>> invitations;
  final String? error;
  final AuthSession session;
  final TanteApi api;
  final VoidCallback onRetry;
  final VoidCallback onAccepted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lease invitations')),
      body: error != null
          ? _error(context, error!, onRetry)
          : invitations.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'You have no lease invitations.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Lease invitations',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF102F4C),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Review an invitation and accept it to continue.'),
                const SizedBox(height: 16),
                ...invitations.map((invitation) {
                  final invitationToken = invitation['invitationToken']
                      .toString();
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.mark_email_unread_outlined),
                      ),
                      title: Text(
                        'Lease ${invitation['leaseReference'] ?? invitation['leaseId']}',
                      ),
                      subtitle: Text(
                        '${_readable(invitation['status'])}'
                        '${invitation['createdAt'] == null ? '' : ' · ${_date(invitation['createdAt'])}'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final accepted = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (context) => TenantInvitationDetailsPage(
                              invitationToken: invitationToken,
                              session: session,
                              api: api,
                            ),
                          ),
                        );
                        if (accepted == true) onAccepted();
                      },
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class TenantInvitationDetailsPage extends StatefulWidget {
  const TenantInvitationDetailsPage({
    super.key,
    required this.invitationToken,
    required this.session,
    required this.api,
  });

  final String invitationToken;
  final AuthSession session;
  final TanteApi api;

  @override
  State<TenantInvitationDetailsPage> createState() =>
      _TenantInvitationDetailsPageState();
}

class _TenantInvitationDetailsPageState
    extends State<TenantInvitationDetailsPage> {
  Map<String, dynamic>? _invitation;
  Map<String, dynamic>? _lease;
  String? _error;
  bool _loading = true;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invitation = await widget.api.getTenantInvitation(
        widget.invitationToken,
        widget.session.token,
      );
      final leaseId = _intValue(invitation['leaseId']);
      if (leaseId == null) {
        throw const TanteApiException(
          'The rent service returned an invitation without a lease.',
        );
      }
      final lease = await widget.api.getLeaseDetails(
        leaseId,
        widget.session.token,
      );
      if (!mounted) return;
      setState(() {
        _invitation = invitation;
        _lease = lease;
        _loading = false;
      });
    } on TanteApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _accept() async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      await widget.api.acceptTenantLeaseInvitation(
        invitationToken: widget.invitationToken,
        userId: widget.session.userId,
        token: widget.session.token,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lease invitation accepted.')),
      );
      Navigator.pop(context, true);
    } on TanteApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invitation details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorContent(context)
          : _details(context),
      bottomNavigationBar:
          !_loading &&
              _error == null &&
              _invitation?['status']?.toString().toUpperCase() == 'PENDING'
          ? SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _accepting ? null : _accept,
                child: Text(_accepting ? 'Accepting...' : 'Accept invitation'),
              ),
            )
          : null,
    );
  }

  Widget _details(BuildContext context) {
    final lease = _lease!;
    final rent = lease['rent'] is Map
        ? Map<String, dynamic>.from(lease['rent'] as Map)
        : const <String, dynamic>{};
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Lease invitation',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: const Color(0xFF102F4C),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _detail('Status', _readable(_invitation?['status'])),
                _detail('Lease', lease['referenceNumber'] ?? lease['id']),
                _detail('Start date', lease['startDate']),
                _detail('End date', lease['endDate']),
                _detail(
                  'Rent',
                  '${rent['amount'] ?? '—'} ${rent['currency'] ?? ''}',
                ),
                _detail('Rental period', _readable(rent['frequency'])),
                _detail(
                  'Payment requirement',
                  lease['fullLeasePaymentRequired'] == true
                      ? 'Full lease payment required'
                      : 'Installments allowed',
                ),
              ],
            ),
          ),
        ),
        if ((lease['leaseTerms']?.toString().trim().isNotEmpty ?? false)) ...[
          const SizedBox(height: 16),
          const Text(
            'Terms and conditions',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: RichHtmlContent(html: lease['leaseTerms'].toString()),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _detail(String label, Object? value) {
    final text = value?.toString().trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 145,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(text.isEmpty ? 'Not provided' : text)),
        ],
      ),
    );
  }

  Widget _errorContent(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

Widget _error(BuildContext context, String error, VoidCallback onRetry) =>
    Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );

int? _intValue(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

String _readable(Object? value) => (value?.toString() ?? 'Unknown')
    .split('_')
    .map(
      (word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
    )
    .join(' ');

String _date(Object? value) {
  final raw = value?.toString() ?? '';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final local = parsed.toLocal();
  return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
