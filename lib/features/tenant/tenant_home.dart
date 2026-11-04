import 'package:flutter/material.dart';
import 'package:tante/services/tante_api.dart';

class TenantHomePage extends StatefulWidget {
  const TenantHomePage({super.key, required this.session});
  final AuthSession session;

  @override
  State<TenantHomePage> createState() => _TenantHomePageState();
}

class _TenantHomePageState extends State<TenantHomePage> {
  final _api = TanteApi();
  int? _tenantId;
  Map<String, dynamic>? _tenant;
  List<Map<String, dynamic>> _leases = const [];
  bool _loading = true;
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final tenant = await _api.getTenantDetails(widget.session.userId, widget.session.token);
      final tenantId = _asInt(tenant['id']);
      final leases = tenantId == null
          ? <Map<String, dynamic>>[]
          : await _api.getTenantLeases(tenantId, widget.session.token);
      if (!mounted) return;
      setState(() { _tenant = tenant; _tenantId = tenantId; _leases = leases; _loading = false; });
    } on TanteApiException catch (error) {
      if (mounted) setState(() { _error = error.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_overview(), _rentPage(), _leasePage(), _accountPage()];
    return Scaffold(
      appBar: AppBar(
        title: const Text('tante', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .5)),
        actions: [IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState()
              : IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), label: 'My rent'),
          NavigationDestination(icon: Icon(Icons.description_outlined), label: 'Leases'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'Account'),
        ],
      ),
    );
  }

  Widget _overview() => _page(
        title: 'Welcome home${_tenant?['firstName'] == null ? '' : ', ${_tenant!['firstName']}'}',
        subtitle: 'Your rental information, all together.',
        children: [
          _infoCard(Icons.home_work_outlined, 'Your home', _leases.isEmpty ? 'No active lease found' : 'You have ${_leases.length} lease${_leases.length == 1 ? '' : 's'} on your account.'),
          _heading('Quick actions'),
          _action(Icons.payments_outlined, 'View rent details', 'See current leases and rent terms', () => setState(() => _tab = 1)),
          _action(Icons.description_outlined, 'View lease agreements', 'Check your agreement details', () => setState(() => _tab = 2)),
          _heading('Account'),
          _infoCard(Icons.phone_outlined, 'Phone number', widget.session.phoneNumber),
        ],
      );

  Widget _rentPage() => _page(
        title: 'My rent',
        subtitle: 'Rent details from your active lease agreements.',
        children: _leases.isEmpty
            ? [_empty('No rent information is available yet.')]
            : _leases.map((lease) {
                final rent = lease['rent'] is Map ? Map<String, dynamic>.from(lease['rent'] as Map) : const <String, dynamic>{};
                return _infoCard(Icons.payments_outlined, 'Lease ${lease['referenceNumber'] ?? lease['id'] ?? ''}',
                    'Rent: ${rent['amount'] ?? rent['rentAmount'] ?? '—'} ${rent['currency'] ?? ''}\nStatus: ${lease['status'] ?? '—'}\n${lease['startDate'] ?? ''} – ${lease['endDate'] ?? ''}');
              }).toList(),
      );

  Widget _leasePage() => _page(
        title: 'My leases',
        subtitle: 'Your agreements and key dates.',
        children: _leases.isEmpty
            ? [_empty('No leases were found for this tenant account.')]
            : _leases.map((lease) => _infoCard(
                  Icons.description_outlined,
                  'Lease ${lease['referenceNumber'] ?? lease['id'] ?? ''}',
                  'Status: ${lease['status'] ?? '—'}\nTerm: ${lease['startDate'] ?? '—'} – ${lease['endDate'] ?? '—'}\nUnit: ${lease['unitId'] ?? '—'}',
                )).toList(),
      );

  Widget _accountPage() => _page(
        title: 'Account',
        subtitle: 'Your Tante tenant account.',
        children: [
          _infoCard(Icons.person_outline_rounded, '${_tenant?['firstName'] ?? ''} ${_tenant?['lastName'] ?? ''}'.trim(), _tenant?['email']?.toString() ?? widget.session.phoneNumber),
          _infoCard(Icons.phone_outlined, 'Phone number', widget.session.phoneNumber),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ],
      );

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 44, color: Color(0xFF3E5674)),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: _load, child: const Text('Try again')),
          ]),
        ),
      );

  Widget _page({required String title, required String subtitle, required List<Widget> children}) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Color(0xFF102F4C))),
          const SizedBox(height: 6), Text(subtitle, style: const TextStyle(color: Color(0xFF3E5674))), const SizedBox(height: 22), ...children],
      );

  Widget _heading(String text) => Padding(padding: const EdgeInsets.only(top: 24, bottom: 10), child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF102F4C))));

  Widget _infoCard(IconData icon, String title, String detail) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFE7F8E7), child: Icon(icon, color: const Color(0xFF19A75C))),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(detail)),
      );

  Widget _action(IconData icon, String title, String subtitle, VoidCallback onTap) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(leading: Icon(icon, color: const Color(0xFF19A75C)), title: Text(title), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right), onTap: onTap),
      );

  Widget _empty(String message) => Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(message, textAlign: TextAlign.center)));

  int? _asInt(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
}
