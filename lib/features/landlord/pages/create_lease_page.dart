import 'package:flutter/material.dart';
import 'package:tante/features/landlord/widgets/lease_terms_editor.dart';
import 'package:tante/services/tante_api.dart';

class CreateLeasePage extends StatefulWidget {
  const CreateLeasePage({
    super.key,
    required this.api,
    required this.rentalProfileId,
    required this.token,
  });

  final TanteApi api;
  final int rentalProfileId;
  final String token;

  @override
  State<CreateLeasePage> createState() => _CreateLeasePageState();
}

class _CreateLeasePageState extends State<CreateLeasePage> {
  static const _steps = [
    'Tenant details',
    'Property details',
    'Rent details',
    'Dates',
    'Terms',
    'Review',
  ];

  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _rentController = TextEditingController();
  late Future<List<LeaseUnitOption>> _unitsFuture;
  int _currentStep = 0;
  int? _selectedUnitId;
  DateTime? _startDate;
  DateTime? _endDate;
  String _rentFrequency = 'MONTHLY';
  bool _fullLeasePaymentRequired = false;
  String _leaseTerms = '';
  bool _submitting = false;
  Map<String, dynamic>? _createdLease;

  @override
  void initState() {
    super.initState();
    _unitsFuture = _loadUnits();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _rentController.dispose();
    super.dispose();
  }

  Future<List<LeaseUnitOption>> _loadUnits() {
    return widget.api.getAvailableLeaseUnits(
      widget.rentalProfileId,
      widget.token,
    );
  }

  Future<void> _editTerms() async {
    final terms = await showDialog<String>(
      context: context,
      builder: (context) => RichHtmlEditorDialog(
        title: 'Edit lease terms',
        hintText: 'Write lease terms here...',
        html: _leaseTerms,
      ),
    );
    if (terms != null && mounted) setState(() => _leaseTerms = terms);
  }

  void _continue() {
    if (_submitting) return;
    if (_currentStep == 3 && !_validateDates()) return;
    if (_currentStep != 1 &&
        _currentStep != 4 &&
        !_formKey.currentState!.validate()) {
      return;
    }
    if (_currentStep < _steps.length - 1) {
      setState(() => _currentStep++);
    } else {
      _createLease();
    }
  }

  bool _validateDates() {
    final start = _startDate;
    final end = _endDate;
    if (start == null || end == null) {
      _showMessage('Select both the start date and end date.');
      return false;
    }
    if (!start.isBefore(end)) {
      _showMessage('The end date must be after the start date.');
      return false;
    }
    return true;
  }

  Future<void> _createLease() async {
    setState(() => _submitting = true);
    try {
      final lease = await widget.api.createLandlordLease(
        rentalProfileId: widget.rentalProfileId,
        tenantFirstName: _firstNameController.text,
        tenantLastName: _lastNameController.text,
        tenantPhoneNumber: _phoneController.text,
        startDate: _formatDate(_startDate!),
        endDate: _formatDate(_endDate!),
        rentAmount: double.parse(_rentController.text.trim()),
        rentFrequency: _rentFrequency,
        fullLeasePaymentRequired: _fullLeasePaymentRequired,
        token: widget.token,
        unitId: _selectedUnitId,
        leaseTerms: sanitizeRichHtml(_leaseTerms),
      );
      if (mounted) setState(() => _createdLease = lease);
    } on TanteApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _required(String? value, String label) {
    return value == null || value.trim().isEmpty ? 'Enter $label.' : null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.replaceAll(RegExp(r'[\s-]'), '') ?? '';
    if (!RegExp(r'^(\+255|255|0)[678]\d{8}$').hasMatch(phone)) {
      return 'Enter a valid Tanzanian mobile number.';
    }
    return null;
  }

  String? _validateRent(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    if (amount == null || !amount.isFinite || amount <= 0) {
      return 'Enter a valid rent amount greater than zero.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final createdLease = _createdLease;
    return Scaffold(
      appBar: AppBar(
        title: Text(createdLease == null ? 'Create lease' : 'Lease created'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _submitting ? null : () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: createdLease == null
            ? _buildForm()
            : _buildSuccess(createdLease),
      ),
      bottomNavigationBar: createdLease == null
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => setState(() => _currentStep--),
                      child: const Text('Back'),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting ? null : _continue,
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _currentStep == _steps.length - 1
                                  ? 'Create lease'
                                  : 'Next',
                            ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text(
            'Step ${_currentStep + 1} of ${_steps.length}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (_currentStep + 1) / _steps.length),
          const SizedBox(height: 20),
          Text(
            _steps[_currentStep],
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _buildStepContent(),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    return switch (_currentStep) {
      0 => _buildTenantStep(),
      1 => _buildPropertyStep(),
      2 => _buildRentStep(),
      3 => _buildDatesStep(),
      4 => _buildTermsStep(),
      _ => _buildReviewStep(),
    };
  }

  Widget _buildTenantStep() => Column(
    children: [
      TextFormField(
        key: const ValueKey('lease-tenant-first-name'),
        controller: _firstNameController,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Tenant first name'),
        validator: (value) => _required(value, "the tenant's first name"),
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: const ValueKey('lease-tenant-last-name'),
        controller: _lastNameController,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Tenant last name'),
        validator: (value) => _required(value, "the tenant's last name"),
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: const ValueKey('lease-tenant-phone'),
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: 'Tenant phone number'),
        validator: _validatePhone,
      ),
    ],
  );

  Widget _buildPropertyStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Choose an available unit, or skip this step and assign one later.',
      ),
      const SizedBox(height: 16),
      FutureBuilder<List<LeaseUnitOption>>(
        future: _unitsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            final error = snapshot.error;
            final message = error is TanteApiException
                ? error.message
                : 'Could not load available units.';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: TextStyle(color: Colors.red.shade700)),
                TextButton.icon(
                  onPressed: () => setState(() => _unitsFuture = _loadUnits()),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            );
          }
          final units = snapshot.data ?? const <LeaseUnitOption>[];
          if (units.isEmpty) return const Text('No available units to select.');
          return DropdownButtonFormField<int>(
            key: const ValueKey('lease-unit-picker'),
            initialValue: _selectedUnitId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Available unit'),
            hint: const Text('Skip for now'),
            items: units
                .map(
                  (unit) => DropdownMenuItem(
                    value: unit.id,
                    child: Text(
                      '${unit.propertyName} · ${unit.buildingName} · ${unit.unitNumber}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (id) {
              setState(() {
                _selectedUnitId = id;
                final selected = units
                    .where((unit) => unit.id == id)
                    .firstOrNull;
                if (selected != null) {
                  _rentController.text = selected.rentAmount.toStringAsFixed(
                    selected.rentAmount.truncateToDouble() ==
                            selected.rentAmount
                        ? 0
                        : 2,
                  );
                }
              });
            },
          );
        },
      ),
      if (_selectedUnitId != null)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _selectedUnitId = null),
            child: const Text('Remove selected unit'),
          ),
        ),
    ],
  );

  Widget _buildRentStep() => Column(
    children: [
      TextFormField(
        key: const ValueKey('lease-rent-amount'),
        controller: _rentController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(
          labelText: 'Rent amount',
          suffixText: 'TZS',
        ),
        validator: _validateRent,
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        key: const ValueKey('lease-rent-frequency'),
        initialValue: _rentFrequency,
        decoration: const InputDecoration(labelText: 'Payment frequency'),
        items: const [
          DropdownMenuItem(value: 'YEARLY', child: Text('Per year')),
          DropdownMenuItem(value: 'MONTHLY', child: Text('Per month')),
          DropdownMenuItem(value: 'WEEKLY', child: Text('Per week')),
          DropdownMenuItem(value: 'DAILY', child: Text('Per day')),
        ],
        onChanged: (value) =>
            setState(() => _rentFrequency = value ?? 'MONTHLY'),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Full lease payment required'),
        value: _fullLeasePaymentRequired,
        onChanged: (value) => setState(() => _fullLeasePaymentRequired = value),
      ),
    ],
  );

  Widget _buildDatesStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        key: const ValueKey('lease-start-date-picker'),
        onPressed: _selectStartDate,
        icon: const Icon(Icons.calendar_today_outlined),
        label: _dateButtonLabel('Start date', _startDate),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(16),
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        key: const ValueKey('lease-end-date-picker'),
        onPressed: _startDate == null ? null : _selectEndDate,
        icon: const Icon(Icons.event_outlined),
        label: _dateButtonLabel('End date', _endDate),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.all(16),
        ),
      ),
      if (_startDate == null) ...[
        const SizedBox(height: 8),
        Text(
          'Choose a start date before selecting the end date.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ],
  );

  Future<void> _selectStartDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _startDate ?? today,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'Select lease start date',
    );
    if (selectedDate == null || !mounted) return;
    setState(() {
      _startDate = DateUtils.dateOnly(selectedDate);
      if (_endDate != null && !_startDate!.isBefore(_endDate!)) {
        _endDate = null;
      }
    });
  }

  Future<void> _selectEndDate() async {
    final startDate = _startDate;
    if (startDate == null) return;
    final earliestEndDate = startDate.add(const Duration(days: 1));
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _endDate != null && !_endDate!.isBefore(earliestEndDate)
          ? _endDate!
          : earliestEndDate,
      firstDate: earliestEndDate,
      lastDate: DateTime(2100),
      helpText: 'Select lease end date',
    );
    if (selectedDate != null && mounted) {
      setState(() => _endDate = DateUtils.dateOnly(selectedDate));
    }
  }

  Widget _dateButtonLabel(String label, DateTime? date) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      const SizedBox(height: 4),
      Text(
        date == null ? 'Choose date' : _formatDate(date),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Widget _buildTermsStep() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Add any additional conditions for this lease (optional).'),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _editTerms,
        icon: const Icon(Icons.edit_outlined),
        label: Text(
          _leaseTerms.trim().isEmpty ? 'Add lease terms' : 'Edit lease terms',
        ),
      ),
      if (_leaseTerms.trim().isNotEmpty) ...[
        const Divider(),
        RichHtmlContent(html: _leaseTerms),
      ],
    ],
  );

  Widget _buildReviewStep() {
    final unitFuture = _unitsFuture;
    return FutureBuilder<List<LeaseUnitOption>>(
      future: unitFuture,
      builder: (context, snapshot) {
        final unit = snapshot.data
            ?.where((item) => item.id == _selectedUnitId)
            .firstOrNull;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _reviewItem(
              'Tenant',
              '${_firstNameController.text} ${_lastNameController.text}',
            ),
            _reviewItem('Phone number', _phoneController.text),
            _reviewItem(
              'Unit',
              unit == null
                  ? 'Not assigned'
                  : '${unit.propertyName} · ${unit.buildingName} · ${unit.unitNumber}',
            ),
            _reviewItem(
              'Rent',
              '${_rentController.text} TZS ${_frequencyLabel(_rentFrequency)}',
            ),
            _reviewItem(
              'Lease term',
              '${_formatDate(_startDate!)} – ${_formatDate(_endDate!)}',
            ),
            _reviewItem(
              'Full payment required',
              _fullLeasePaymentRequired ? 'Yes' : 'No',
            ),
            const SizedBox(height: 12),
            const Text(
              'Terms and conditions',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            if (_leaseTerms.trim().isEmpty)
              const Text('Not provided')
            else
              RichHtmlContent(html: _leaseTerms),
          ],
        );
      },
    );
  }

  Widget _reviewItem(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );

  String _frequencyLabel(String frequency) => switch (frequency) {
    'YEARLY' => 'per year',
    'WEEKLY' => 'per week',
    'DAILY' => 'per day',
    _ => 'per month',
  };

  Widget _buildSuccess(Map<String, dynamic> lease) {
    final reference = lease['referenceNumber']?.toString();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Lease created',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (reference?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text('Lease reference: $reference'),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.pop(context, lease),
              child: const Text('Go to list'),
            ),
          ],
        ),
      ),
    );
  }
}
