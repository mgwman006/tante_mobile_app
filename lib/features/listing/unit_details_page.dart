import 'package:flutter/material.dart';
import '../../login.dart';
import '../../services/tante_api.dart';
import '../../tante_colors.dart';

class UnitDetailsPage extends StatefulWidget {
  const UnitDetailsPage({super.key, required this.unitId, this.api});

  final int unitId;
  final TanteApi? api;

  @override
  State<UnitDetailsPage> createState() => _UnitDetailsPageState();
}

class _UnitDetailsPageState extends State<UnitDetailsPage> {
  late final TanteApi _api;
  late Future<RentalUnitDetails> _unitFuture;
  AuthSession? _session;
  Map<String, dynamic>? _rentalProfile;
  bool _profileLoading = false;
  bool _bookingSubmitting = false;
  String? _profileError;
  int _currentImage = 0;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? TanteApi();
    _unitFuture = _api.getUnitDetails(widget.unitId);
  }

  void _reload() {
    setState(() {
      _currentImage = 0;
      _unitFuture = _api.getUnitDetails(widget.unitId);
    });
  }

  Future<void> _signInToListing(
    RentalUnitDetails unit, {
    bool continueToBooking = false,
  }) async {
    final session = await Navigator.pushNamed<AuthSession>(
      context,
      '/login',
      arguments: const LoginRouteArgs(
        role: 'Tenant',
        returnToPreviousRoute: true,
      ),
    );
    if (!mounted || session == null) return;
    setState(() {
      _session = session;
      _rentalProfile = null;
      _profileError = null;
      _profileLoading = true;
    });
    await _loadRentalProfile(unit, session);
    if (continueToBooking && mounted && _rentalProfile != null) {
      await _showViewingRequestDialog(unit);
    }
  }

  Future<void> _loadRentalProfile(
    RentalUnitDetails unit,
    AuthSession session,
  ) async {
    setState(() {
      _rentalProfile = null;
      _profileError = null;
      _profileLoading = true;
    });
    try {
      final profile = await _api.getRentalProfileDetails(
        unit.rentalProfileId,
        session.token,
      );
      if (mounted) setState(() => _rentalProfile = profile);
    } on TanteApiException catch (error) {
      if (mounted) setState(() => _profileError = error.message);
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  Future<void> _scheduleViewing(RentalUnitDetails unit) async {
    if (_session == null) {
      await _signInToListing(unit, continueToBooking: true);
      return;
    }
    if (_rentalProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_profileError ?? 'Agency details are still loading.'),
        ),
      );
      return;
    }
    await _showViewingRequestDialog(unit);
  }

  Future<void> _showViewingRequestDialog(RentalUnitDetails unit) async {
    final serviceFee = _viewingServiceFee;
    if (serviceFee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The viewing fee is unavailable. Please try again later.',
          ),
        ),
      );
      return;
    }

    DateTime? startTime;
    var notes = '';
    final formKey = GlobalKey<FormState>();
    final shouldSubmit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request a viewing'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Request a time to see Unit ${unit.unitNumber}.'),
                  const SizedBox(height: 8),
                  Text('Viewing fee: ${_formatRent(serviceFee)}'),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final date = await showDatePicker(
                        context: context,
                        initialDate: startTime ?? now,
                        firstDate: DateTime(now.year, now.month, now.day),
                        lastDate: DateTime(now.year + 2),
                      );
                      if (date == null || !context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: startTime == null
                            ? const TimeOfDay(hour: 10, minute: 0)
                            : TimeOfDay.fromDateTime(startTime!),
                      );
                      if (time == null) return;
                      setDialogState(() {
                        startTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    },
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: Text(
                      startTime == null
                          ? 'Choose date and time'
                          : _formatDateTime(startTime!),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    maxLength: 500,
                    maxLines: 3,
                    onChanged: (value) => notes = value,
                    decoration: const InputDecoration(
                      labelText: 'Note to the property manager (optional)',
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _bookingSubmitting
                  ? null
                  : () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _bookingSubmitting
                  ? null
                  : () {
                      if (startTime == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Choose a date and time.'),
                          ),
                        );
                        return;
                      }
                      if (startTime!.isBefore(DateTime.now())) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Choose a future date and time.'),
                          ),
                        );
                        return;
                      }
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(dialogContext, true);
                      }
                    },
              child: const Text('Send request'),
            ),
          ],
        ),
      ),
    );
    if (shouldSubmit != true || startTime == null || !mounted) return;

    final session = _session;
    if (session == null) return;
    setState(() => _bookingSubmitting = true);
    try {
      final booking = await _api.createViewingBooking(
        rentalProfileId: unit.rentalProfileId,
        unitId: unit.id,
        startTime: startTime!,
        requesterUserAccountId: session.userId,
        serviceFee: serviceFee,
        token: session.token,
        notes: notes,
      );
      if (!mounted) return;
      final reference = booking['reference']?.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            reference == null || reference.isEmpty
                ? 'Viewing request sent. The property manager will follow up.'
                : 'Viewing request sent. Reference: $reference',
          ),
        ),
      );
    } on TanteApiException catch (error) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.red),
            title: const Text('Viewing request failed'),
            content: SelectableText(error.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _bookingSubmitting = false);
    }
  }

  double? get _viewingServiceFee {
    final value = _rentalProfile?['viewingServiceFee'];
    if (value is num) return value.toDouble();
    return value == null ? null : double.tryParse(value.toString());
  }

  String _formatDateTime(DateTime value) {
    final date = MaterialLocalizations.of(context).formatMediumDate(value);
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(value));
    return '$date at $time';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home details'),
        leading: ModalRoute.of(context)?.canPop == true
            ? IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
      ),
      body: FutureBuilder<RentalUnitDetails>(
        future: _unitFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _buildError(snapshot.error);
          }
          final unit = snapshot.data;
          if (unit == null) {
            return _buildUnavailable();
          }
          return _buildDetails(unit);
        },
      ),
    );
  }

  Widget _buildError(Object? error) {
    final message = error is TanteApiException
        ? error.message
        : 'Could not load this listing. Check your connection and try again.';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              color: TanteColors.mutedText,
              size: 44,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnavailable() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.home_outlined,
              color: TanteColors.mutedText,
              size: 44,
            ),
            const SizedBox(height: 12),
            const Text('This listing is no longer available.'),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.maybePop(context),
              child: const Text('Back to listings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetails(RentalUnitDetails unit) {
    final address = unit.address.isEmpty
        ? 'Location available on request'
        : unit.address.join(', ');
    final title = '${unit.propertyName} | Unit ${unit.unitNumber}';
    final description = unit.propertyDescription?.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
      children: [
        _buildGallery(unit),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${_formatRent(unit.rentAmount)} / month',
                        style: const TextStyle(
                          color: TanteColors.green,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    _statusBadge(unit.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: TanteColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 19,
                      color: TanteColors.mutedText,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(color: TanteColors.mutedText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  description == null || description.isEmpty
                      ? 'Contact the rental manager to learn more about this home.'
                      : description,
                  style: const TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Unit details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _detailRow('Unit type', _formatLabel(unit.type)),
                _detailRow('Bedrooms', '${unit.bedrooms}'),
                _detailRow('Bathrooms', '${unit.bathrooms}'),
                _detailRow('Parking spaces', '${unit.parkingSpaces}'),
                _detailRow(
                  'Room size',
                  unit.roomSize == null
                      ? 'Not provided'
                      : '${unit.roomSize} ${unit.sizeUnit ?? ''}'.trim(),
                ),
                _detailRow('Building / block number', '${unit.buildingNumber}'),
                if (unit.buildingName.isNotEmpty)
                  _detailRow('Building', unit.buildingName),
                _detailRow('Floor number', '${unit.floorNumber}', last: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      color: TanteColors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Agency',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_session == null) ...[
                  Text(
                    'This listing is managed by agency ${unit.rentalProfileId}.',
                    style: const TextStyle(height: 1.5),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sign in to view agency contact details and ask about this home.',
                    style: TextStyle(color: TanteColors.mutedText, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => _signInToListing(unit),
                    child: const Text('Sign in'),
                  ),
                ] else if (_profileLoading) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ] else if (_profileError != null) ...[
                  Text(
                    _profileError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  TextButton(
                    onPressed: _session == null
                        ? () => _signInToListing(unit)
                        : () => _loadRentalProfile(unit, _session!),
                    child: const Text('Try loading agency details again'),
                  ),
                ] else if (_rentalProfile != null) ...[
                  _detailRow(
                    'Name',
                    _rentalProfile!['name']?.toString() ?? 'Not provided',
                  ),
                  _detailRow(
                    'Agency type',
                    _formatLabel(_rentalProfile!['type']?.toString()),
                  ),
                  if (_rentalProfile!['phoneNumber'] != null)
                    _detailRow(
                      'Phone number',
                      _rentalProfile!['phoneNumber'].toString(),
                    ),
                  if (_rentalProfile!['email'] != null)
                    _detailRow('Email', _rentalProfile!['email'].toString()),
                  _detailRow(
                    'Viewing fee',
                    _viewingServiceFee == null
                        ? 'Currently unavailable'
                        : _formatRent(_viewingServiceFee!),
                    last: true,
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _bookingSubmitting
                        ? null
                        : () => _scheduleViewing(unit),
                    icon: const Icon(Icons.event_available_outlined),
                    label: Text(
                      _bookingSubmitting
                          ? 'Sending request...'
                          : _session == null
                          ? 'Sign in to schedule viewing'
                          : 'Schedule a viewing',
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Virtual viewing is coming soon.'),
                      ),
                    ),
                    child: const Text('Virtual viewing'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGallery(RentalUnitDetails unit) {
    if (unit.images.isEmpty) {
      return Container(
        height: 230,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            colors: [Color(0xFFCCFBF1), Color(0xFF99F6E4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.apartment_rounded,
                size: 54,
                color: TanteColors.navy,
              ),
              const SizedBox(height: 8),
              Text(
                'Unit ${unit.unitNumber}',
                style: const TextStyle(
                  color: TanteColors.navy,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 260,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              itemCount: unit.images.length,
              onPageChanged: (index) => setState(() => _currentImage = index),
              itemBuilder: (context, index) => Image.network(
                unit.images[index].url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFFE2E8F0),
                  child: const Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: TanteColors.mutedText,
                      size: 44,
                    ),
                  ),
                ),
              ),
            ),
            if (unit.images.length > 1)
              Positioned(
                right: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    child: Text(
                      '${_currentImage + 1} / ${unit.images.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String? status) {
    final available = status == 'AVAILABLE';
    return Chip(
      label: Text(_formatLabel(status)),
      backgroundColor: available
          ? const Color(0xFFE7F7ED)
          : const Color(0xFFFFF3D6),
      labelStyle: TextStyle(
        color: available ? const Color(0xFF147A43) : const Color(0xFF805A00),
        fontWeight: FontWeight.w600,
      ),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _detailRow(String label, String value, {bool last = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: TanteColors.mutedText),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: TanteColors.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!last) const Divider(height: 1),
      ],
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

  String _formatLabel(String? value) {
    if (value == null || value.isEmpty) return 'Not provided';
    return value
        .toLowerCase()
        .split('_')
        .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}
