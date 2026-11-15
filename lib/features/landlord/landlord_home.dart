import 'package:flutter/material.dart';
import 'package:tante/services/tante_api.dart';

import 'dialogs/create_rental_profile_dialog.dart';
import 'pages/landlord_account_page.dart';
import 'pages/create_property_page.dart';
import 'pages/landlord_leases_page.dart';
import 'pages/landlord_overview_page.dart';
import 'pages/landlord_properties_page.dart';
import 'pages/rental_profile_picker_page.dart';
import 'rental_profile_utils.dart';
import 'widgets/rental_profile_switcher.dart';

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
      final selected = profiles
          .where((profile) => profile['id']?.toString() == selectedId)
          .firstOrNull;
      setState(() {
        _profiles = profiles;
        _selectedProfile = selected;
        _loadingProfiles = false;
      });
      if (selected != null) await _loadProfileDashboard(selected);
    } on TanteApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loadingProfiles = false;
        });
      }
    }
  }

  Future<void> _loadProfileDashboard(Map<String, dynamic> profile) async {
    final id = rentalProfileIdFrom(profile['id']);
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
      builder: (context) =>
          CreateRentalProfileDialog(api: _api, session: widget.session),
    );
    if (!mounted || profile == null) return;
    setState(() {
      _profiles = [..._profiles, profile];
      _error = null;
    });
    await _loadProfileDashboard(profile);
  }

  Future<void> _addProperty() async {
    final rentalProfileId = rentalProfileIdFrom(_selectedProfile?['id']);
    if (rentalProfileId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a rental profile first.')),
      );
      return;
    }
    final property = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (context) => CreatePropertyPage(
          api: _api,
          session: widget.session,
          rentalProfileId: rentalProfileId,
        ),
      ),
    );
    if (!mounted || property == null) return;
    setState(() => _properties = [..._properties, property]);
  }

  Future<void> _switchProfile() async {
    final profile = await showRentalProfileSwitcher(
      context: context,
      profiles: _profiles,
      selectedProfileId: _selectedProfile?['id'],
    );
    if (!mounted || profile == null) return;
    if (profile['__create__'] == true) {
      await _createProfile();
    } else {
      await _loadProfileDashboard(profile);
    }
  }

  void _logOut() {
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingProfiles) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _selectedProfile == null) return _errorState();
    if (_selectedProfile == null) return _profilePicker();

    final profile = _selectedProfile!;
    final pages = [
      LandlordOverviewPage(
        profileName: profile['name']?.toString() ?? 'your rental profile',
        propertyCount: _properties.length,
        leaseCount: _leases.length,
        onOpenProperties: () => setState(() => _tab = 1),
        onOpenLeases: () => setState(() => _tab = 2),
      ),
      LandlordPropertiesPage(
        properties: _properties,
        onAddProperty: _addProperty,
      ),
      LandlordLeasesPage(leases: _leases),
      LandlordAccountPage(
        profile: profile,
        fallbackPhoneNumber: widget.session.phoneNumber,
        onSwitchProfile: _switchProfile,
        onLogout: _logOut,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'tante',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .5),
            ),
            Text(
              profile['name']?.toString() ?? 'Rental profile',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Switch rental profile',
            onPressed: _switchProfile,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadProfiles,
            icon: const Icon(Icons.refresh_rounded),
          ),
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
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.apartment_rounded),
            label: 'Properties',
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
    );
  }

  Widget _profilePicker() => RentalProfilePickerPage(
    profiles: _profiles,
    onSelectProfile: _loadProfileDashboard,
    onCreateProfile: _createProfile,
    onLogout: _logOut,
  );

  Widget _errorState() => Scaffold(
    appBar: AppBar(title: const Text('tante')),
    body: Center(
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
            Text(
              _error ?? 'Something went wrong.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _selectedProfile == null
                  ? _loadProfiles
                  : () => _loadProfileDashboard(_selectedProfile!),
              child: const Text('Try again'),
            ),
            if (_selectedProfile != null)
              TextButton(
                onPressed: () => setState(() {
                  _selectedProfile = null;
                  _error = null;
                }),
                child: const Text('Choose another profile'),
              ),
          ],
        ),
      ),
    ),
  );
}
