import 'package:flutter/material.dart';

import 'tenant_invitations_page.dart';
import 'tenant_lease_details_page.dart';
import 'tenant_viewings_page.dart';
import 'package:tante/services/tante_api.dart';

class TenantHomePage extends StatefulWidget {
  const TenantHomePage({super.key, required this.session, this.api});
  final AuthSession session;
  final TanteApi? api;

  @override
  State<TenantHomePage> createState() => _TenantHomePageState();
}

class _TenantHomePageState extends State<TenantHomePage> {
  late final TanteApi _api;
  Map<String, dynamic>? _tenant;
  List<Map<String, dynamic>> _leases = const [];
  List<Map<String, dynamic>> _invitations = const [];
  List<Map<String, dynamic>> _viewings = const [];
  String? _invitationsError;
  String? _viewingsError;
  bool _showEndedLeases = false;
  bool _loading = true;
  String? _error;
  int _tab = 0;
  final List<int> _tabHistory = [0];

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? TanteApi();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tenant = await _api.getTenantDetails(
        widget.session.userId,
        widget.session.token,
      );
      final tenantId = _asInt(tenant['id']);
      if (tenantId == null) {
        throw const TanteApiException(
          'The tenant profile is missing its account identifier.',
        );
      }
      final leases = await _api.getTenantLeases(tenantId, widget.session.token);
      final extras = await Future.wait([
        _loadOptionalList(
          () => _api.getTenantInvitations(
            widget.session.phoneNumber,
            widget.session.token,
          ),
        ),
        _loadOptionalList(
          () => _api.getTenantViewingBookings(
            widget.session.userId,
            widget.session.token,
          ),
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _tenant = tenant;
        _leases = leases;
        _invitations = extras[0].items;
        _invitationsError = extras[0].error;
        _viewings = extras[1].items;
        _viewingsError = extras[1].error;
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

  void _navigateToTab(int index) {
    if (index == _tab) return;
    setState(() {
      _tab = index;
      _tabHistory.add(index);
    });
  }

  void _goBack() {
    if (_tabHistory.length < 2) return;
    setState(() {
      _tabHistory.removeLast();
      _tab = _tabHistory.last;
    });
  }

  List<Map<String, dynamic>> get _visibleLeases => _leases.where((lease) {
    final status = lease['status']?.toString().toUpperCase();
    return _showEndedLeases ? status == 'ENDED' : status == 'ACTIVE';
  }).toList();

  List<Map<String, dynamic>> get _activeLeases => _leases
      .where((lease) => lease['status']?.toString().toUpperCase() == 'ACTIVE')
      .toList();

  Future<void> _openViewings() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(title: const Text('Viewing bookings')),
        body: TenantViewingsPage(
          bookings: _viewings,
          error: _viewingsError,
          onRetry: () {
            Navigator.of(context).pop();
            _load();
          },
        ),
      ),
    ),
  );

  Future<void> _openInvitations() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (context) => TenantInvitationsPage(
        invitations: _invitations,
        error: _invitationsError,
        session: widget.session,
        api: _api,
        onRetry: () {
          Navigator.of(context).pop();
          _load();
        },
        onAccepted: () {
          Navigator.of(context).pop();
          _load();
        },
      ),
    ),
  );

  Future<void> _openLease(Map<String, dynamic> lease) async {
    final leaseId = _asInt(lease['id']);
    final tenantId = _asInt(_tenant?['id']);
    if (leaseId == null || tenantId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lease details are unavailable.')),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => TenantLeaseDetailsPage(
          leaseId: leaseId,
          tenantId: tenantId,
          session: widget.session,
          api: _api,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_overview(), _leasePage(), _accountPage()];
    return PopScope<Object?>(
      canPop: _tabHistory.length <= 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _tabHistory.length > 1
              ? IconButton(
                  tooltip: 'Back',
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
          title: const Text(
            'tante',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .5),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _errorState()
            : IndexedStack(index: _tab, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _navigateToTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Overview',
            ),
            NavigationDestination(
              icon: Icon(Icons.description_outlined),
              label: 'Leases',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }

  Widget _overview() => _page(
    title:
        'Welcome home${_tenant?['firstName'] == null ? '' : ', ${_tenant!['firstName']}'}',
    subtitle: 'Your rental information, all together.',
    children: [
      _infoCard(
        Icons.home_work_outlined,
        'Your home',
        _activeLeases.isEmpty
            ? 'No active lease found'
            : 'You have ${_activeLeases.length} active lease${_activeLeases.length == 1 ? '' : 's'} on your account.',
      ),
      _action(
        Icons.mark_email_unread_outlined,
        'Lease invitations',
        _invitationsError != null
            ? 'Could not load invitations. Tap to retry.'
            : '${_invitations.length} invitation${_invitations.length == 1 ? '' : 's'} to review',
        _openInvitations,
      ),
      _action(
        Icons.event_outlined,
        'Viewing bookings',
        _viewingsError != null
            ? 'Could not load viewing bookings. Tap to retry.'
            : '${_viewings.length} viewing booking${_viewings.length == 1 ? '' : 's'}',
        _openViewings,
      ),
      _heading('Quick actions'),
      _action(
        Icons.description_outlined,
        'View lease agreements',
        'Check your agreement details',
        () => _navigateToTab(1),
      ),
      _heading('Account'),
      _infoCard(
        Icons.phone_outlined,
        'Phone number',
        widget.session.phoneNumber,
      ),
    ],
  );

  Widget _leasePage() => _page(
    title: 'My leases',
    subtitle: 'Your agreements and key dates.',
    children: [
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Active')),
          ButtonSegment(value: true, label: Text('Ended')),
        ],
        selected: {_showEndedLeases},
        onSelectionChanged: (selection) =>
            setState(() => _showEndedLeases = selection.first),
      ),
      const SizedBox(height: 16),
      if (_visibleLeases.isEmpty)
        _empty(
          _showEndedLeases
              ? 'No ended leases were found.'
              : 'No active leases were found.',
        )
      else
        ..._visibleLeases.map(
          (lease) => _leaseCard(
            lease,
            'Status: ${_readable(lease['status'])}\nTerm: ${lease['startDate'] ?? '—'} – ${lease['endDate'] ?? '—'}\nUnit: ${lease['unitId'] ?? '—'}',
            Icons.description_outlined,
          ),
        ),
    ],
  );

  Widget _leaseCard(Map<String, dynamic> lease, String detail, IconData icon) =>
      Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFE7F8E7),
            child: Icon(icon, color: const Color(0xFF19A75C)),
          ),
          title: Text(
            'Lease ${lease['referenceNumber'] ?? lease['id'] ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(detail),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openLease(lease),
        ),
      );

  Widget _accountPage() => _page(
    title: 'Account',
    subtitle: 'Your Tante tenant account.',
    children: [
      _infoCard(
        Icons.person_outline_rounded,
        '${_tenant?['firstName'] ?? ''} ${_tenant?['lastName'] ?? ''}'.trim(),
        _tenant?['email']?.toString() ?? widget.session.phoneNumber,
      ),
      _infoCard(
        Icons.phone_outlined,
        'Phone number',
        widget.session.phoneNumber,
      ),
      OutlinedButton.icon(
        onPressed: () => Navigator.pushNamedAndRemoveUntil(
          context,
          '/login',
          (route) => false,
        ),
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Log out'),
      ),
    ],
  );

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 44,
            color: Color(0xFF3E5674),
          ),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Try again')),
        ],
      ),
    ),
  );

  Widget _page({
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 25,
          fontWeight: FontWeight.w800,
          color: Color(0xFF102F4C),
        ),
      ),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(color: Color(0xFF3E5674))),
      const SizedBox(height: 22),
      ...children,
    ],
  );

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Color(0xFF102F4C),
      ),
    ),
  );

  Widget _infoCard(IconData icon, String title, String detail) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFE7F8E7),
        child: Icon(icon, color: const Color(0xFF19A75C)),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(detail),
    ),
  );

  Widget _action(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF19A75C)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );

  Widget _empty(String message) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(child: Text(message, textAlign: TextAlign.center)),
  );

  int? _asInt(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  Future<_TenantListResult> _loadOptionalList(
    Future<List<Map<String, dynamic>>> Function() load,
  ) async {
    try {
      return _TenantListResult(await load(), null);
    } on TanteApiException catch (error) {
      return _TenantListResult(const [], error.message);
    }
  }

  String _readable(Object? value) => (value?.toString() ?? 'Unknown')
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

class _TenantListResult {
  const _TenantListResult(this.items, this.error);

  final List<Map<String, dynamic>> items;
  final String? error;
}
