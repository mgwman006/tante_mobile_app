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
  Map<String, dynamic>? _selectedProfile;
  bool _loadingProfiles = true;
  bool _loadingDashboard = false;
  String? _error;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    setState(() {
      _loadingProfiles = true;
      _error = null;
    });
    try {
      final profiles = await _api.getRentalProfiles(widget.session);
      if (!mounted) return;
      final selectedId = _selectedProfile?['id']?.toString();
      final selected = profiles.where((profile) => profile['id']?.toString() == selectedId).firstOrNull;
      setState(() {
        _profiles = profiles;
        _selectedProfile = selected;
        _loadingProfiles = false;
      });
      if (selected != null) await _loadProfileDashboard(selected);
    } on TanteApiException catch (error) {
      if (mounted){
        setState(() {
                _error = error.message;
                _loadingProfiles = false;
              });
      } 
    }
  }

  Future<void> _loadProfileDashboard(Map<String, dynamic> profile) async {
    final id = _asInt(profile['id']);
    if (id == null) return;
    setState(() {
      _selectedProfile = profile;
      _loadingDashboard = true;
      _error = null;
    });
    try {
      final properties = await _api.getProperties(id, widget.session.token);
      final leases = await _api.getLandlordLeases(id, widget.session.token);
      if (!mounted) return;
      setState(() {
        _properties = properties;
        _leases = leases;
        _loadingDashboard = false;
        _tab = 0;
      });
    } on TanteApiException catch (error) {
      if (mounted) {
        setState(() {
        _error = error.message;
        _loadingDashboard = false;
      });
      }
    }
  }

  Future<void> _createProfile() async {
    final profile = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateRentalProfileDialog(
        api: _api,
        session: widget.session,
      ),
    );
    if (!mounted || profile == null) return;
    final profiles = [..._profiles, profile];
    setState(() {
      _profiles = profiles;
      _error = null;
    });
    await _loadProfileDashboard(profile);
  }

  Future<void> _switchProfile() async {
    final profile = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Text('Choose a rental profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            ..._profiles.map((item) => ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: Text(item['name']?.toString() ?? 'Rental profile'),
                  subtitle: Text(_profileType(item['type'])),
                  trailing: item['id'] == _selectedProfile?['id'] ? const Icon(Icons.check_circle, color: Color(0xFF19A75C)) : null,
                  onTap: () => Navigator.pop(context, item),
                )),
            ListTile(
              leading: const Icon(Icons.add_business_outlined),
              title: const Text('Create rental profile'),
              onTap: () => Navigator.pop(context, <String, dynamic>{'__create__': true}),
            ),
          ],
        ),
      ),
    );
    if (!mounted || profile == null) return;
    if (profile['__create__'] == true) {
      await _createProfile();
    } else {
      await _loadProfileDashboard(profile);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfiles) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _selectedProfile == null) return _errorState();
    if (_selectedProfile == null) return _profilePicker();

    final pages = [_overview(), _propertyPage(), _leasePage(), _accountPage()];
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('tante', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .5)),
            Text(_selectedProfile?['name']?.toString() ?? 'Rental profile', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          IconButton(tooltip: 'Switch rental profile', onPressed: _switchProfile, icon: const Icon(Icons.swap_horiz_rounded)),
          IconButton(tooltip: 'Refresh', onPressed: _loadProfiles, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _loadingDashboard
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

  Widget _profilePicker() => Scaffold(
        appBar: AppBar(title: const Text('Choose a rental profile')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text('Welcome to Tante', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Color(0xFF102F4C))),
            const SizedBox(height: 8),
            const Text('Select a landlord or agent profile to continue, or create a new profile.'),
            const SizedBox(height: 20),
            if (_profiles.isEmpty) ...[
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(children: [
                    Icon(Icons.business_outlined, size: 38, color: Color(0xFF19A75C)),
                    SizedBox(height: 12),
                    Text('No rental profiles yet', style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text('Create a profile to manage properties and rental activity.', textAlign: TextAlign.center),
                  ]),
                ),
              ),
            ],
            ..._profiles.map((profile) => Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.business_outlined)),
                    title: Text(profile['name']?.toString() ?? 'Rental profile', style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${_profileType(profile['type'])} profile${profile['organizationName'] == null ? '' : ' · ${profile['organizationName']}'}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _loadProfileDashboard(profile),
                  ),
                )),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _createProfile,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create rental profile'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Log out'),
            ),
          ],
        ),
      );

  Widget _overview() => _page(
        title: 'Your rental overview',
        subtitle: 'Live information for ${_selectedProfile?['name'] ?? 'your rental profile'}.',
        children: [
          _metric('Properties', '${_properties.length}', Icons.apartment_rounded),
          _metric('Leases', '${_leases.length}', Icons.description_outlined),
          _heading('Quick actions'),
          _action(Icons.apartment_rounded, 'View properties', 'See properties linked to this rental profile', () => setState(() => _tab = 1)),
          _action(Icons.description_outlined, 'Manage leases', 'Review current lease agreements', () => setState(() => _tab = 2)),
        ],
      );

  Widget _propertyPage() => _page(
        title: 'Your properties',
        subtitle: 'Property details loaded from Property Manager.',
        children: _properties.isEmpty
            ? [_empty('No properties are linked to this rental profile yet.')]
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
            ? [_empty('No leases are linked to this rental profile yet.')]
            : _leases.map((lease) => _dataCard(
                  Icons.description_outlined,
                  'Lease ${lease['referenceNumber'] ?? lease['id'] ?? ''}',
                  'Status: ${lease['status'] ?? '—'}\nUnit: ${lease['unitId'] ?? '—'}\nTerm: ${lease['startDate'] ?? '—'} – ${lease['endDate'] ?? '—'}',
                )).toList(),
      );

  Widget _accountPage() => _page(
        title: 'Account',
        subtitle: 'Your Tante landlord or agent account.',
        children: [
          _dataCard(Icons.business_outlined, _selectedProfile?['name']?.toString() ?? 'Rental profile', '${_profileType(_selectedProfile?['type'])} rental profile'),
          _dataCard(Icons.phone_outlined, 'Phone number', _selectedProfile?['phoneNumber']?.toString() ?? widget.session.phoneNumber),
          if ((_selectedProfile?['email']?.toString() ?? '').isNotEmpty)
            _dataCard(Icons.email_outlined, 'Email', _selectedProfile!['email'].toString()),
          OutlinedButton.icon(onPressed: _switchProfile, icon: const Icon(Icons.swap_horiz_rounded), label: const Text('Switch rental profile')),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ],
      );

  Widget _errorState() => Scaffold(
        appBar: AppBar(title: const Text('tante')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_off_outlined, size: 44, color: Color(0xFF3E5674)),
              const SizedBox(height: 12),
              Text(_error ?? 'Something went wrong.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _selectedProfile == null ? _loadProfiles : () => _loadProfileDashboard(_selectedProfile!), child: const Text('Try again')),
              if (_selectedProfile != null) TextButton(onPressed: () => setState(() { _selectedProfile = null; _error = null; }), child: const Text('Choose another profile')),
            ]),
          ),
        ),
      );

  Widget _page({required String title, required String subtitle, required List<Widget> children}) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Color(0xFF102F4C))),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Color(0xFF3E5674))),
          const SizedBox(height: 22),
          ...children,
        ],
      );

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF102F4C))),
      );

  Widget _metric(String label, String value, IconData icon) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: const Color(0xFFE7F8E7), child: Icon(icon, color: const Color(0xFF19A75C))),
          title: Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          subtitle: Text(label),
        ),
      );

  Widget _dataCard(IconData icon, String title, String detail) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          leading: CircleAvatar(backgroundColor: const Color(0xFFE7F8E7), child: Icon(icon, color: const Color(0xFF19A75C))),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(detail),
        ),
      );

  Widget _action(IconData icon, String title, String subtitle, VoidCallback onTap) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(leading: Icon(icon, color: const Color(0xFF19A75C)), title: Text(title), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right), onTap: onTap),
      );

  Widget _empty(String message) => Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text(message, textAlign: TextAlign.center)));

  int? _asInt(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

  static String _profileType(dynamic value) {
    final type = value?.toString().toUpperCase() ?? '';
    return switch (type) {
      'INDIVIDUAL' => 'Individual',
      'BUSINESS' => 'Business',
      'ENTERPRISE' => 'Enterprise',
      _ => type.isEmpty ? 'Rental' : type,
    };
  }
}

class _CreateRentalProfileDialog extends StatefulWidget {
  const _CreateRentalProfileDialog({required this.api, required this.session});
  final TanteApi api;
  final AuthSession session;

  @override
  State<_CreateRentalProfileDialog> createState() => _CreateRentalProfileDialogState();
}

class _CreateRentalProfileDialogState extends State<_CreateRentalProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController();
  late final _phoneController = TextEditingController(text: widget.session.phoneNumber);
  late final _emailController = TextEditingController(text: widget.session.email ?? '');
  String _type = 'INDIVIDUAL';
  int? _organizationId;
  bool _saving = false;

  List<Map<String, dynamic>> get _organizations => widget.session.memberships.where((membership) {
        final id = membership['organizationId'];
        return id is num ? id > 0 : int.tryParse(id?.toString() ?? '') != null && int.parse(id.toString()) > 0;
      }).toList();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final profile = await widget.api.createRentalProfile(
        session: widget.session,
        name: _nameController.text,
        phoneNumber: _phoneController.text,
        email: _emailController.text,
        type: _type,
        organizationId: _type == 'BUSINESS' ? _organizationId : null,
      );
      if (mounted) Navigator.pop(context, profile);
    } on TanteApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasOrganizations = _organizations.isNotEmpty;
    return AlertDialog(
      title: const Text('Create rental profile'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Create a profile to manage rental units and collect rent efficiently.'),
            const SizedBox(height: 18),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Rental profile name', prefixIcon: Icon(Icons.business_outlined)),
              validator: (value) => value == null || value.trim().isEmpty ? 'Enter a profile name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number', prefixIcon: Icon(Icons.phone_outlined)),
              validator: (value) => value == null || value.trim().isEmpty ? 'Enter a phone number' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email (optional)', prefixIcon: Icon(Icons.email_outlined)),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return 'Enter a valid email address';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Rental profile type', prefixIcon: Icon(Icons.category_outlined)),
              items: const [
                DropdownMenuItem(value: 'INDIVIDUAL', child: Text('Individual')),
                DropdownMenuItem(value: 'BUSINESS', child: Text('Business')),
              ],
              onChanged: _saving ? null : (value) => setState(() {
                _type = value ?? 'INDIVIDUAL';
                if (_type != 'BUSINESS') _organizationId = null;
              }),
            ),
            if (_type == 'BUSINESS') ...[
              const SizedBox(height: 12),
              if (hasOrganizations)
                DropdownButtonFormField<int>(
                  initialValue: _organizationId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Organization', prefixIcon: Icon(Icons.groups_outlined)),
                  items: _organizations.map((membership) {
                    final rawId = membership['organizationId'];
                    final id = rawId is num ? rawId.toInt() : int.parse(rawId.toString());
                    final name = membership['organizationName']?.toString();
                    return DropdownMenuItem(value: id, child: Text(name?.isNotEmpty == true ? name! : 'Organization $id'));
                  }).toList(),
                  onChanged: _saving ? null : (value) => setState(() => _organizationId = value),
                  validator: (value) => value == null ? 'Select an organization' : null,
                )
              else
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('A business profile requires an organization membership on your account.', style: TextStyle(color: Colors.red)),
                ),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving || (_type == 'BUSINESS' && !hasOrganizations) ? null : _submit,
          child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Create profile'),
        ),
      ],
    );
  }
}
