import 'package:flutter/material.dart';

import '../../../services/tante_api.dart';
import '../widgets/lease_terms_editor.dart';

const _leaseTabs = [
  'Tenant',
  'Unit',
  'Dates',
  'Rent',
  'Terms and conditions',
  'Payment',
];

class LeaseDetailsPage extends StatefulWidget {
  const LeaseDetailsPage({
    super.key,
    required this.leaseId,
    required this.token,
    required this.api,
    this.rentalProfileId,
    this.payerUserId,
  });

  final int leaseId;
  final String token;
  final TanteApi api;
  final int? rentalProfileId;
  final int? payerUserId;

  @override
  State<LeaseDetailsPage> createState() => _LeaseDetailsPageState();
}

class _LeaseDetailsPageState extends State<LeaseDetailsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  Map<String, dynamic>? _lease;
  Future<RentalUnitDetails>? _unitFuture;
  Future<Map<String, dynamic>>? _paymentFuture;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool _loadingUnits = false;

  bool get _canEdit {
    final status = _lease?['status']?.toString().toUpperCase();
    return status != 'ACTIVE' && status != 'ENDED';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _leaseTabs.length, vsync: this)
      ..addListener(_onTabChanged);
    _loadLease();
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && _tabController.index == 5) {
      _loadPaymentSummary();
    }
  }

  Future<void> _loadLease() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lease = await widget.api.getLeaseDetails(
        widget.leaseId,
        widget.token,
      );
      if (!mounted) return;
      final unitId = _intValue(lease['unitId']);
      setState(() {
        _lease = lease;
        _unitFuture = unitId == null
            ? null
            : widget.api.getUnitDetails(unitId, token: widget.token);
        _loading = false;
      });
      if (_tabController.index == 5) _loadPaymentSummary();
    } on TanteApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  void _loadPaymentSummary() {
    if (_paymentFuture != null) return;
    setState(() {
      _paymentFuture = widget.api.getLeaseRentSummary(
        widget.leaseId,
        widget.token,
      );
    });
  }

  Future<void> _saveLease(
    Future<Map<String, dynamic>> Function() request,
  ) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final lease = await request();
      if (!mounted) return;
      setState(() {
        _lease = {...?_lease, ...lease};
        final unitId = _intValue(_lease?['unitId']);
        _unitFuture = unitId == null
            ? null
            : widget.api.getUnitDetails(unitId, token: widget.token);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lease updated successfully.')),
      );
    } on TanteApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editDates() async {
    final lease = _lease!;
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => _LeaseDatesDialog(
        startDate: _dateValue(lease['startDate']),
        endDate: _dateValue(lease['endDate']),
      ),
    );
    if (result == null || !mounted) return;
    await _saveLease(
      () => widget.api.updateLeaseDates(
        leaseId: widget.leaseId,
        startDate: result.$1,
        endDate: result.$2,
        token: widget.token,
      ),
    );
  }

  Future<void> _editRent() async {
    final lease = _lease!;
    final rent = lease['rent'] is Map
        ? Map<String, dynamic>.from(lease['rent'] as Map)
        : <String, dynamic>{};
    final result = await showDialog<(double, String, String, bool)>(
      context: context,
      builder: (context) => _LeaseRentDialog(
        amount: rent['amount']?.toString() ?? '',
        currency: rent['currency']?.toString() ?? 'TZS',
        frequency: rent['frequency']?.toString().toUpperCase() ?? 'MONTHLY',
        fullLeasePaymentRequired: lease['fullLeasePaymentRequired'] == true,
      ),
    );
    if (result == null || !mounted) return;
    await _saveLease(
      () => widget.api.updateLeaseRent(
        leaseId: widget.leaseId,
        amount: result.$1,
        currency: result.$2,
        frequency: result.$3,
        fullLeasePaymentRequired: result.$4,
        token: widget.token,
      ),
    );
  }

  Future<void> _editTerms() async {
    final terms = await showDialog<String>(
      context: context,
      builder: (context) => RichHtmlEditorDialog(
        title: 'Edit lease terms',
        hintText: 'Write lease terms here...',
        html: _lease?['leaseTerms']?.toString() ?? '',
      ),
    );
    if (terms == null || !mounted) return;
    await _saveLease(
      () => widget.api.updateLeaseTerms(
        leaseId: widget.leaseId,
        leaseTerms: terms,
        token: widget.token,
      ),
    );
  }

  Future<void> _assignUnit() async {
    final rentalProfileId = widget.rentalProfileId;
    if (rentalProfileId == null || _loadingUnits || _saving) return;
    setState(() => _loadingUnits = true);
    try {
      final units = await widget.api.getAvailableLeaseUnits(
        rentalProfileId,
        widget.token,
      );
      if (!mounted) return;
      setState(() => _loadingUnits = false);
      if (units.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No available units were found.')),
        );
        return;
      }
      final unit = await showDialog<LeaseUnitOption>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select an available unit'),
          content: SizedBox(
            width: 440,
            height: 360,
            child: ListView.separated(
              itemCount: units.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final option = units[index];
                return ListTile(
                  key: ValueKey('lease-unit-${option.id}'),
                  title: Text('Unit ${option.unitNumber}'),
                  subtitle: Text(
                    '${option.propertyName} · ${option.buildingName}\n'
                    '${_readable(option.type)} · ${option.rentAmount} rent',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, option),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (unit == null || !mounted) return;
      await _saveLease(
        () => widget.api.assignLeaseUnit(
          leaseId: widget.leaseId,
          unitId: unit.id,
          token: widget.token,
        ),
      );
    } on TanteApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _loadingUnits = false);
    }
  }

  bool _canRecordPayment(Map block) {
    final status = _lease?['status']?.toString().toUpperCase();
    final blockStatus = block['status']?.toString().toUpperCase();
    return widget.rentalProfileId != null &&
        widget.payerUserId != null &&
        blockStatus != 'PAID' &&
        status != 'ENDED' &&
        status != 'PENDING_TENANT_APPROVAL' &&
        status != 'TERMINATED';
  }

  Future<void> _recordPayment(Map block) async {
    final paymentBlockId = _intValue(block['id']);
    final amount = _doubleValue(block['amount']);
    if (paymentBlockId == null ||
        amount == null ||
        widget.rentalProfileId == null ||
        widget.payerUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment details or landlord account are unavailable.'),
        ),
      );
      return;
    }
    final leaseRent = _lease?['rent'];
    final currency = leaseRent is Map
        ? leaseRent['currency']?.toString() ?? 'TZS'
        : 'TZS';
    final result = await showDialog<(double, String, String, String)>(
      context: context,
      builder: (context) =>
          _RecordPaymentDialog(amount: amount, currency: currency),
    );
    if (result == null || !mounted) return;
    try {
      await widget.api.recordLeasePayment(
        rentalProfileId: widget.rentalProfileId!,
        paymentBlockId: paymentBlockId,
        amount: result.$1,
        currency: currency,
        payerUserId: widget.payerUserId!,
        method: result.$2,
        reference: result.$3,
        note: result.$4,
        token: widget.token,
      );
      if (!mounted) return;
      setState(() => _paymentFuture = null);
      _loadPaymentSummary();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded successfully.')),
      );
    } on TanteApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Lease ${_lease?['referenceNumber'] ?? widget.leaseId}',
          overflow: TextOverflow.ellipsis,
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _leaseTabs.map((tab) => Tab(text: tab)).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _loadError()
          : _lease == null
          ? const Center(child: Text('Lease details are unavailable.'))
          : TabBarView(
              controller: _tabController,
              children: [
                _tenantTab(),
                _unitTab(),
                _datesTab(),
                _rentTab(),
                _termsTab(),
                _paymentTab(),
              ],
            ),
    );
  }

  Widget _loadError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _loadLease, child: const Text('Retry')),
        ],
      ),
    ),
  );

  Widget _tenantTab() {
    final tenant = _lease?['tenant'] is Map
        ? Map<String, dynamic>.from(_lease!['tenant'] as Map)
        : null;
    final invitations = _lease?['invitations'] is List
        ? (_lease!['invitations'] as List).whereType<Map>().toList()
        : const <Map>[];
    return _tabContent(
      children: [
        _sectionTitle('Tenant'),
        if (tenant == null)
          const _InformationCard(
            icon: Icons.person_outline,
            title: 'No tenant assigned',
            detail: 'No tenant is linked to this lease.',
          )
        else
          _InformationCard(
            icon: Icons.person_outline,
            title: '${tenant['firstName'] ?? ''} ${tenant['lastName'] ?? ''}'
                .trim(),
            detail: [
              tenant['email'],
              tenant['phoneNumber'],
            ].where((value) => value != null && '$value'.isNotEmpty).join('\n'),
          ),
        _sectionTitle('Invitations'),
        if (invitations.isEmpty)
          const _InformationCard(
            icon: Icons.mail_outline,
            title: 'No invitations',
            detail: 'There are no tenant invitations for this lease.',
          )
        else
          ...invitations.map(
            (invitation) => _InformationCard(
              icon: Icons.mail_outline,
              title:
                  '${invitation['firstName'] ?? ''} ${invitation['lastName'] ?? ''}'
                      .trim(),
              detail:
                  '${invitation['email'] ?? invitation['phoneNumber'] ?? ''}\n'
                  'Status: ${_readable(invitation['status'])}',
            ),
          ),
      ],
    );
  }

  Widget _unitTab() {
    final unitFuture = _unitFuture;
    if (unitFuture == null) {
      return _tabContent(
        children: [
          const _InformationCard(
            icon: Icons.home_work_outlined,
            title: 'No unit assigned',
            detail: 'This lease is not linked to a rental unit.',
          ),
          if (widget.rentalProfileId != null)
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _loadingUnits || _saving ? null : _assignUnit,
                icon: _loadingUnits
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_home_work_outlined),
                label: Text(
                  _loadingUnits ? 'Loading units...' : 'Assign a unit',
                ),
              ),
            ),
        ],
      );
    }
    return FutureBuilder<RentalUnitDetails>(
      future: unitFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorContent(
            snapshot.error is TanteApiException
                ? (snapshot.error as TanteApiException).message
                : 'Unable to load unit details.',
          );
        }
        final unit = snapshot.data!;
        return _tabContent(
          children: [
            _sectionTitle('Assigned unit'),
            _InformationCard(
              icon: Icons.home_work_outlined,
              title: 'Unit ${unit.unitNumber}',
              detail: [
                'Property: ${unit.propertyName}',
                'Building: ${unit.buildingName}',
                'Type: ${_readable(unit.type)}',
                'Bedrooms: ${unit.bedrooms}',
                'Bathrooms: ${unit.bathrooms}',
                'Parking spaces: ${unit.parkingSpaces}',
                'Status: ${_readable(unit.status)}',
                if (unit.address.isNotEmpty)
                  'Address: ${unit.address.join(', ')}',
              ].join('\n'),
            ),
          ],
        );
      },
    );
  }

  Widget _datesTab() {
    final startDate = _dateValue(_lease?['startDate']);
    final endDate = _dateValue(_lease?['endDate']);
    return _tabContent(
      children: [
        _sectionTitle('Lease dates'),
        _InformationCard(
          icon: Icons.calendar_month_outlined,
          title: 'Start date',
          detail: startDate,
        ),
        _InformationCard(
          icon: Icons.event_outlined,
          title: 'End date',
          detail: endDate,
        ),
        _editButton(_editDates),
      ],
    );
  }

  Widget _rentTab() {
    final rent = _lease?['rent'] is Map
        ? Map<String, dynamic>.from(_lease!['rent'] as Map)
        : const <String, dynamic>{};
    return _tabContent(
      children: [
        _sectionTitle('Rent'),
        _InformationCard(
          icon: Icons.payments_outlined,
          title: 'Rent amount',
          detail:
              '${rent['currency'] ?? ''} ${rent['amount'] ?? '—'} ${_readable(rent['frequency'])}'
                  .trim(),
        ),
        _InformationCard(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Payment requirement',
          detail: _lease?['fullLeasePaymentRequired'] == true
              ? 'Full lease payment required'
              : 'Regular payments',
        ),
        _editButton(_editRent),
      ],
    );
  }

  Widget _termsTab() {
    final terms = _lease?['leaseTerms']?.toString().trim() ?? '';
    return _tabContent(
      children: [
        _sectionTitle('Terms and conditions'),
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.gavel_outlined, color: Color(0xFF19A75C)),
                    SizedBox(width: 8),
                    Text(
                      'Lease terms',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (terms.isEmpty)
                  Text(
                    'No terms have been added.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                else
                  RichHtmlContent(html: terms),
              ],
            ),
          ),
        ),
        _editButton(_editTerms),
      ],
    );
  }

  Widget _paymentTab() {
    if (_paymentFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<Map<String, dynamic>>(
      future: _paymentFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _errorContent(
            snapshot.error is TanteApiException
                ? (snapshot.error as TanteApiException).message
                : 'Unable to load lease payment details.',
            onRetry: () {
              setState(() => _paymentFuture = null);
              _loadPaymentSummary();
            },
          );
        }
        final summary = snapshot.data!;
        final blocks = (summary['paymentBlocks'] as List).whereType<Map>();
        return _tabContent(
          children: [
            _sectionTitle('Payment summary'),
            _InformationCard(
              icon: Icons.receipt_long_outlined,
              title: 'Expected',
              detail: _money(
                summary['totalExpectedAmount'],
                summary,
                _lease?['rent'],
              ),
            ),
            _InformationCard(
              icon: Icons.check_circle_outline,
              title: 'Paid',
              detail: _money(
                summary['totalPaidAmount'],
                summary,
                _lease?['rent'],
              ),
            ),
            _InformationCard(
              icon: Icons.pending_outlined,
              title: 'Outstanding',
              detail: _money(
                summary['totalOutstandingAmount'],
                summary,
                _lease?['rent'],
              ),
            ),
            _sectionTitle('Payment periods'),
            if (blocks.isEmpty)
              const _InformationCard(
                icon: Icons.event_note_outlined,
                title: 'No payment periods',
                detail: 'There are no payment blocks for this lease yet.',
              )
            else
              ...blocks.map((rawBlock) {
                final block = Map<String, dynamic>.from(rawBlock);
                final canRecord = _canRecordPayment(block);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InformationCard(
                      icon: Icons.event_note_outlined,
                      title:
                          '${_dateValue(block['startDate'])} – ${_dateValue(block['endDate'])}',
                      detail: [
                        'Due ${_dateValue(block['dueDate'])}',
                        'Amount: ${_money(block['amount'], summary, _lease?['rent'])}',
                        'Paid: ${_money(block['paidAmount'], summary, _lease?['rent'])}',
                        'Outstanding: ${_money(block['outstandingAmount'], summary, _lease?['rent'])}',
                        'Status: ${_readable(block['status'])}',
                      ].join('\n'),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: OutlinedButton.icon(
                        onPressed: canRecord
                            ? () => _recordPayment(block)
                            : null,
                        icon: const Icon(Icons.payments_outlined),
                        label: const Text('Record payment'),
                      ),
                    ),
                  ],
                );
              }),
          ],
        );
      },
    );
  }

  Widget _editButton(VoidCallback onPressed) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: _canEdit
          ? FilledButton.icon(
              onPressed: _saving ? null : onPressed,
              icon: const Icon(Icons.edit_outlined),
              label: Text(_saving ? 'Saving...' : 'Edit'),
            )
          : const Text(
              'Editing is unavailable for this lease status.',
              key: ValueKey('lease-edit-restricted'),
            ),
    ),
  );

  Widget _tabContent({required List<Widget> children}) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
    children: children,
  );

  Widget _errorContent(String message, {VoidCallback? onRetry}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    ),
  );

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Color(0xFF102F4C),
      ),
    ),
  );
}

class _LeaseDatesDialog extends StatefulWidget {
  const _LeaseDatesDialog({required this.startDate, required this.endDate});

  final String startDate;
  final String endDate;

  @override
  State<_LeaseDatesDialog> createState() => _LeaseDatesDialogState();
}

class _LeaseDatesDialogState extends State<_LeaseDatesDialog> {
  late final _formKey = GlobalKey<FormState>();
  late final _startController = TextEditingController(text: widget.startDate);
  late final _endController = TextEditingController(text: widget.endDate);
  String? _dateError;

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit lease dates'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dateField(_startController, 'Start date'),
          const SizedBox(height: 12),
          _dateField(_endController, 'End date'),
          if (_dateError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _dateError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          final start = DateTime.parse(_startController.text.trim());
          final end = DateTime.parse(_endController.text.trim());
          if (!end.isAfter(start)) {
            setState(() {
              _dateError = 'End date must be after the start date.';
            });
            return;
          }
          Navigator.pop(context, (
            _startController.text.trim(),
            _endController.text.trim(),
          ));
        },
        child: const Text('Save'),
      ),
    ],
  );

  Widget _dateField(TextEditingController controller, String label) =>
      TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label, hintText: 'YYYY-MM-DD'),
        validator: (value) => DateTime.tryParse(value?.trim() ?? '') == null
            ? 'Enter a valid date (YYYY-MM-DD).'
            : null,
      );
}

class _LeaseRentDialog extends StatefulWidget {
  const _LeaseRentDialog({
    required this.amount,
    required this.currency,
    required this.frequency,
    required this.fullLeasePaymentRequired,
  });

  final String amount;
  final String currency;
  final String frequency;
  final bool fullLeasePaymentRequired;

  @override
  State<_LeaseRentDialog> createState() => _LeaseRentDialogState();
}

class _LeaseRentDialogState extends State<_LeaseRentDialog> {
  late final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(text: widget.amount);
  late final _currencyController = TextEditingController(text: widget.currency);
  late String _frequency = widget.frequency;
  late bool _fullLeasePaymentRequired = widget.fullLeasePaymentRequired;

  @override
  void dispose() {
    _amountController.dispose();
    _currencyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit rent'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount'),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                return amount == null || amount <= 0
                    ? 'Enter a valid rent amount.'
                    : null;
              },
            ),
            TextFormField(
              controller: _currencyController,
              decoration: const InputDecoration(labelText: 'Currency'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a currency.'
                  : null,
            ),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Rent frequency'),
              items: const [
                DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
                DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
                DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
                DropdownMenuItem(value: 'YEARLY', child: Text('Yearly')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _frequency = value);
              },
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Full lease payment required'),
              value: _fullLeasePaymentRequired,
              onChanged: (value) =>
                  setState(() => _fullLeasePaymentRequired = value ?? false),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, (
            double.parse(_amountController.text.trim()),
            _currencyController.text.trim(),
            _frequency,
            _fullLeasePaymentRequired,
          ));
        },
        child: const Text('Save'),
      ),
    ],
  );
}

class _RecordPaymentDialog extends StatefulWidget {
  const _RecordPaymentDialog({required this.amount, required this.currency});

  final double amount;
  final String currency;

  @override
  State<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<_RecordPaymentDialog> {
  late final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(
    text: widget.amount.toString(),
  );
  late final _referenceController = TextEditingController();
  late final _noteController = TextEditingController();
  String _method = 'CASH';

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Record payment'),
    content: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Amount (${widget.currency})',
                helperText:
                    'The backend requires the full payment-block amount.',
              ),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                if (amount == null || amount <= 0) {
                  return 'Enter a valid payment amount.';
                }
                if ((amount - widget.amount).abs() > 0.001) {
                  return 'Amount must equal ${widget.amount}.';
                }
                return null;
              },
            ),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Payment method'),
              items: const [
                DropdownMenuItem(value: 'CASH', child: Text('Cash')),
                DropdownMenuItem(
                  value: 'BANK_TRANSFER',
                  child: Text('Bank transfer'),
                ),
                DropdownMenuItem(
                  value: 'MOBILE_MONEY',
                  child: Text('Mobile money'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _method = value);
              },
            ),
            TextFormField(
              controller: _referenceController,
              decoration: const InputDecoration(labelText: 'Reference'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a payment reference.'
                  : null,
            ),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              minLines: 1,
              maxLines: 3,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (!_formKey.currentState!.validate()) return;
          Navigator.pop(context, (
            double.parse(_amountController.text.trim()),
            _method,
            _referenceController.text.trim(),
            _noteController.text.trim(),
          ));
        },
        child: const Text('Submit'),
      ),
    ],
  );
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF19A75C)),
      title: Text(title.isEmpty ? 'Not available' : title),
      subtitle: detail.isEmpty ? null : Text(detail),
    ),
  );
}

String _dateValue(Object? value) {
  final text = value?.toString() ?? '';
  final date = DateTime.tryParse(text);
  if (date == null) return text.isEmpty ? '—' : text;
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String _readable(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return '—';
  return text
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0]}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

String _money(Object? amount, Map<String, dynamic> summary, Object? rent) {
  final leaseRent = rent is Map ? rent : null;
  final currency =
      summary['currency']?.toString() ??
      (leaseRent is Map ? leaseRent['currency']?.toString() : null) ??
      'TZS';
  final value = amount?.toString() ?? '—';
  return '$currency $value'.trim();
}

int? _intValue(Object? value) {
  final parsed = value is num
      ? value.toInt()
      : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
}

double? _doubleValue(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
