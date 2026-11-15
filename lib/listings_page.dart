import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tante/services/tante_api.dart';
import 'package:tante/tante_colors.dart';

class ListingsPage extends StatefulWidget {
  const ListingsPage({super.key, this.initialFilters = const {}, this.api});

  final Map<String, String> initialFilters;
  final TanteApi? api;

  @override
  State<ListingsPage> createState() => _ListingsPageState();
}

class _ListingsPageState extends State<ListingsPage> {
  late final TanteApi _api;
  late final TextEditingController _cityController;
  late final TextEditingController _minRentController;
  late final TextEditingController _maxRentController;
  late String _type;
  late String _minBedrooms;
  List<RentalListing> _listings = const [];
  int _totalElements = 0;
  int _pageNumber = 0;
  int _loadRequestId = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? TanteApi();
    _cityController = TextEditingController(
      text: widget.initialFilters['city'] ?? '',
    );
    _minRentController = TextEditingController(
      text: widget.initialFilters['minRent'] ?? '',
    );
    _maxRentController = TextEditingController(
      text: widget.initialFilters['maxRent'] ?? '',
    );
    _type = widget.initialFilters['type'] ?? '';
    _minBedrooms = '';
    _loadListings();
  }

  @override
  void dispose() {
    _cityController.dispose();
    _minRentController.dispose();
    _maxRentController.dispose();
    super.dispose();
  }

  Future<void> _loadListings() async {
    final requestId = ++_loadRequestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final page = await _api.getListedUnits(
        page: _pageNumber,
        city: _cityController.text,
        type: _type,
        minBedrooms: int.tryParse(_minBedrooms) ?? 0,
        minRent: _minRentController.text.trim(),
        maxRent: _maxRentController.text.trim(),
      );
      if (!mounted || requestId != _loadRequestId) return;
      setState(() {
        _listings = page.items;
        _totalElements = page.totalElements;
      });
    } on TanteApiException catch (error) {
      if (mounted && requestId == _loadRequestId) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted && requestId == _loadRequestId) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyFilters() {
    setState(() => _pageNumber = 0);
    _loadListings();
  }

  void _changePage(int offset) {
    setState(() => _pageNumber += offset);
    _loadListings();
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_totalElements / 12).ceil();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: TanteColors.navy,
        title: const Text(
          'tante.',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.fromLTRB(22, 30, 22, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A BETTER WAY TO FIND YOUR NEXT PLACE',
                  style: TextStyle(
                    color: TanteColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    text: 'A place to call ',
                    children: const [
                      TextSpan(
                        text: 'yours.',
                        style: TextStyle(
                          color: TanteColors.green,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    color: TanteColors.text,
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Thoughtful homes, ready when you are. Find a space that feels like the start of something.',
                  style: TextStyle(color: TanteColors.mutedText, height: 1.5),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 24, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FIND YOUR FIT',
                  style: TextStyle(
                    color: TanteColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Homes for rent',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  '$_totalElements place${_totalElements == 1 ? '' : 's'} to explore',
                ),
                const SizedBox(height: 14),
                _buildFilters(),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_errorMessage != null)
                  _buildError()
                else if (_listings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.home_outlined,
                            size: 44,
                            color: TanteColors.mutedText,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No homes match those filters yet. Try adjusting your search.',
                          ),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ..._listings.asMap().entries.map(
                    (entry) => _buildListingCard(entry.value, entry.key),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: _pageNumber > 0
                            ? () => _changePage(-1)
                            : null,
                        child: const Text('Previous'),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          '${_pageNumber + 1} of ${totalPages == 0 ? 1 : totalPages}',
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _pageNumber + 1 < totalPages
                            ? () => _changePage(1)
                            : null,
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: _cityController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _applyFilters(),
              decoration: const InputDecoration(
                labelText: 'City',
                hintText: 'Any city',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Unit type'),
              items: const [
                DropdownMenuItem(value: '', child: Text('Any type')),
                DropdownMenuItem(value: 'FLAT', child: Text('Flat')),
                DropdownMenuItem(value: 'HOUSE', child: Text('House')),
                DropdownMenuItem(value: 'ROOM', child: Text('Room')),
                DropdownMenuItem(value: 'OFFICE', child: Text('Office')),
                DropdownMenuItem(value: 'SHOP', child: Text('Shop')),
              ],
              onChanged: (value) => setState(() => _type = value ?? ''),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _minBedrooms,
              decoration: const InputDecoration(labelText: 'Bedrooms'),
              items: const [
                DropdownMenuItem(value: '', child: Text('Any number')),
                DropdownMenuItem(value: '1', child: Text('1+')),
                DropdownMenuItem(value: '2', child: Text('2+')),
                DropdownMenuItem(value: '3', child: Text('3+')),
                DropdownMenuItem(value: '4', child: Text('4+')),
              ],
              onChanged: (value) => setState(() => _minBedrooms = value ?? ''),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minRentController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Min. rent',
                      prefixText: 'TSh ',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _maxRentController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Max. rent',
                      prefixText: 'TSh ',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _isLoading ? null : _applyFilters,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Search homes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: TanteColors.mutedText,
              size: 36,
            ),
            const SizedBox(height: 10),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadListings,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingCard(RentalListing listing, int index) {
    final location = [
      listing.streetName,
      listing.city,
      listing.region,
    ].where((part) => part.isNotEmpty).join(', ');
    final title = '${listing.propertyName} | Unit ${listing.unitNumber}';
    final colors = [
      const [Color(0xFFCCFBF1), Color(0xFF99F6E4)],
      const [Color(0xFFFEF3C7), Color(0xFFFCD34D)],
      const [Color(0xFFDBEAFE), Color(0xFFBFDBFE)],
      const [Color(0xFFF1F5F9), Color(0xFFCBD5E1)],
    ][index % 4];
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 16,
                  top: 14,
                  child: Chip(
                    label: Text(listing.status.toLowerCase()),
                    backgroundColor: Colors.white.withValues(alpha: .9),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                Center(
                  child: Icon(
                    Icons.apartment_rounded,
                    size: 58,
                    color: TanteColors.navy.withValues(alpha: .45),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: TanteColors.mutedText,
                    ),
                    Expanded(
                      child: Text(
                        location.isEmpty
                            ? 'Location available on request'
                            : location,
                        style: const TextStyle(color: TanteColors.mutedText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  children: [
                    Text('${listing.bedrooms} bed'),
                    Text('${listing.bathrooms} bath'),
                    Text(listing.type.toLowerCase().replaceAll('_', ' ')),
                  ],
                ),
                const Divider(height: 24),
                Text(
                  '${_formatRent(listing.rentAmount)} / month',
                  style: const TextStyle(
                    color: TanteColors.green,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatRent(double amount) {
    final digits = amount.round().toString();
    final grouped = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return 'TSh $grouped';
  }
}
