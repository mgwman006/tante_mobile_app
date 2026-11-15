import 'package:flutter/material.dart';
import 'package:tante/tante_colors.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  String _location = 'Dar es Salaam';
  String _unitType = '';

  void _openLogin(String role) {
    Navigator.pushNamed(context, '/login', arguments: role);
  }

  void _searchListings() {
    final filters = <String, String>{'location': _location};
    if (_unitType.isNotEmpty) filters['type'] = _unitType;
    Navigator.pushNamed(context, '/listings', arguments: filters);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          key: const ValueKey('landing-page-scroll'),
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          children: [
            _buildHeader(),
            _buildHero(),
            _buildQuickSearch(),
            _buildServices(),
            _buildStats(),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Tante. Better rental relationships. Together.',
                textAlign: TextAlign.center,
                style: TextStyle(color: TanteColors.mutedText, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: TanteColors.navy,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Text.rich(
            TextSpan(
              text: 'tante',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.5,
              ),
              children: const [
                TextSpan(
                  text: '.',
                  style: TextStyle(color: TanteColors.lime),
                ),
              ],
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _openLogin('Tenant'),
            child: const Text('Sign in'),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return SizedBox(
      height: 490,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/hero-bg.avif', fit: BoxFit.cover),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xF20C2E47),
                  Color(0xC70C2E47),
                  Color(0x300C2E47),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 34, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Find your next place.\nBuild better rental\nrelationships.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Discover rental properties, arrange viewings\nand manage your rental journey with Tante.',
                  style: TextStyle(color: Colors.white, height: 1.5),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _searchListings,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Find a property'),
                  style: FilledButton.styleFrom(
                    backgroundColor: TanteColors.gold,
                    foregroundColor: TanteColors.text,
                    minimumSize: const Size(190, 48),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => _openLogin('Tenant'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    minimumSize: const Size(210, 46),
                  ),
                  child: const Text("I'm a tenant"),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => _openLogin('Landlord'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: TanteColors.gold),
                    minimumSize: const Size(210, 46),
                  ),
                  child: const Text("I'm a landlord / agent"),
                ),
                const Spacer(),
                const Text(
                  'Connecting people, properties and businesses through trusted rental relationships.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.search_rounded, color: TanteColors.green),
                  const SizedBox(width: 8),
                  Text(
                    'Quick search',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Find available properties in your area.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _location,
                decoration: const InputDecoration(labelText: 'Location'),
                items: const [
                  DropdownMenuItem(
                    value: 'Dar es Salaam',
                    child: Text('Dar es Salaam'),
                  ),
                  DropdownMenuItem(value: 'Arusha', child: Text('Arusha')),
                  DropdownMenuItem(value: 'Mwanza', child: Text('Mwanza')),
                ],
                onChanged: (value) =>
                    setState(() => _location = value ?? _location),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _unitType,
                decoration: const InputDecoration(labelText: 'Unit type'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('Any unit type')),
                  DropdownMenuItem(value: 'FLAT', child: Text('Flat')),
                  DropdownMenuItem(value: 'HOUSE', child: Text('House')),
                  DropdownMenuItem(value: 'ROOM', child: Text('Room')),
                  DropdownMenuItem(value: 'OFFICE', child: Text('Office')),
                  DropdownMenuItem(value: 'SHOP', child: Text('Shop')),
                ],
                onChanged: (value) => setState(() => _unitType = value ?? ''),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _searchListings,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Search homes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServices() {
    const services = [
      (
        Icons.home_work_outlined,
        'Property discovery',
        'Explore rentals and connect with property representatives.',
      ),
      (
        Icons.calendar_month_outlined,
        'Viewing management',
        'Coordinate appointments and schedule viewings.',
      ),
      (
        Icons.description_outlined,
        'Lease management',
        'Create, review and manage rental agreements.',
      ),
      (
        Icons.query_stats_rounded,
        'Rental management',
        'Track tenants, rent obligations and rental records.',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Everything connected to the rental journey.',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'From discovery to a rental agreement, Tante has you covered.',
          ),
          const SizedBox(height: 14),
          ...services.map(
            (service) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: TanteColors.lime.withValues(alpha: .25),
                  foregroundColor: TanteColors.navy,
                  child: Icon(service.$1),
                ),
                title: Text(
                  service.$2,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(service.$3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    const stats = [
      ('2,400+', 'Satisfied landlords'),
      ('18,000+', 'Properties listed'),
      ('TSh 2.1B+', 'Rent processed'),
      ('98.4%', 'Collection rate'),
    ];
    return Container(
      color: TanteColors.navy,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        runSpacing: 20,
        children: stats
            .map(
              (stat) => SizedBox(
                width: 145,
                child: Column(
                  children: [
                    Text(
                      stat.$1,
                      style: const TextStyle(
                        color: TanteColors.lime,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      stat.$2,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
