import 'package:flutter/material.dart';
import 'package:tante/services/tante_api.dart';

class LandlordHomePage extends StatefulWidget {
  const LandlordHomePage({super.key, required this.session});
  final AuthSession session;

  @override
  State<LandlordHomePage> createState() => _LandlordHomePageState();
}

class _LandlordHomePageState extends State<LandlordHomePage> {
  final _api = TanteApi();
  List<Map<String, dynamic>> _profiles = const [];
  List<Map<String, dynamic>> _properties = const [];
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
      final profiles = await _api.getRentalProfiles(widget.session);
      final properties = <Map<String, dynamic>>[];
      final leases = <Map<String, dynamic>>[];
      for (final profile in profiles) {
        final id = _asInt(profile['id']);
        if (id == null) continue;
        properties.addAll(await _api.getProperties(id, widget.session.token));
        leases.addAll(await _api.getLandlordLeases(id, widget.session.token));
      }
      if (!mounted) return;
      setState(() { _profiles = profiles; _properties = properties; _leases = leases; _loading = false; });
    } on TanteApiException catch (error) {
      if (mounted) setState(() { _error = error.message; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [_overview(), _propertyPage(), _leasePage(), _accountPage()];
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
          NavigationDestination(icon: Icon(Icons.apartment_rounded), label: 'Properties'),
          NavigationDestination(icon: Icon(Icons.description_outlined), label: 'Leases'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), label: 'Account'),
        ],
      ),
    );
  }

  Widget _overview() => _page(
        title: 'Your rental overview',
        subtitle: 'Live information from your Tante account.',
        children: [
          _metric('Rental profiles', '${_profiles.length}', Icons.business_outlined),
          _metric('Properties', '${_properties.length}', Icons.apartment_rounded),
          _metric('Leases', '${_leases.length}', Icons.description_outlined),
          _heading('Quick actions'),
          _action(Icons.apartment_rounded, 'View properties', 'See properties linked to your rental profiles', () => setState(() => _tab = 1)),
          _action(Icons.description_outlined, 'Manage leases', 'Review current lease agreements', () => setState(() => _tab = 2)),
        ],
      );

  Widget _propertyPage() => _page(
        title: 'Your properties',
        subtitle: 'Property details loaded from Property Manager.',
        children: _properties.isEmpty
            ? [_empty('No properties are linked to your rental profiles yet.')]
            : _properties.map((property) {
                final location = property['location'] is Map ? Map<String, dynamic>.from(property['location'] as Map) : const <String, dynamic>{};
                final address = location['name'] ?? location['address']?.toString() ?? 'Address not provided';
                final buildings = property['buildings'] is List ? (property['buildings'] as List).length : 0;
                return _dataCard(Icons.apartment_rounded, property['name']?.toString() ?? 'Property',
                    '$address\n${property['type'] ?? 'Property'} · $buildings building${buildings == 1 ? '' : 's'}');
              }).toList(),
      );

  Widget _leasePage() => _page(
        title: 'Leases',
        subtitle: 'Agreements managed through Rent Manager.',
        children: _leases.isEmpty
            ? [_empty('No leases are linked to your rental profiles yet.')]
            : _leases.map((lease) => _dataCard(
                  Icons.description_outlined,
                  'Lease ${lease['referenceNumber'] ?? lease['id'] ?? ''}',
                  'Status: ${lease['status'] ?? '—'}\nUnit: ${lease['unitId'] ?? '—'}\nTerm: ${lease['startDate'] ?? '—'} – ${lease['endDate'] ?? '—'}',
                )).toList(),
      );

  Widget _accountPage() => _page(
        title: 'Account',
        subtitle: 'Your Tante landlord account.',
        children: [
          _dataCard(Icons.phone_outlined, 'Phone number', widget.session.phoneNumber),
          ..._profiles.map((profile) => _dataCard(Icons.business_outlined, profile['name']?.toString() ?? 'Rental profile', 'Rental profile · ${profile['type'] ?? ''}')),
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

  Widget _metric(String label, String value, IconData icon) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(leading: CircleAvatar(backgroundColor: const Color(0xFFE7F8E7), child: Icon(icon, color: const Color(0xFF19A75C))),
          title: Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)), subtitle: Text(label)),
      );

  Widget _dataCard(IconData icon, String title, String detail) => Card(
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
