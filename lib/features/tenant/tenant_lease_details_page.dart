import 'package:flutter/material.dart';

import '../../services/tante_api.dart';
import '../landlord/widgets/lease_terms_editor.dart';

class TenantLeaseDetailsPage extends StatefulWidget {
  const TenantLeaseDetailsPage({
    super.key,
    required this.leaseId,
    required this.tenantId,
    required this.session,
    required this.api,
  });

  final int leaseId;
  final int tenantId;
  final AuthSession session;
  final TanteApi api;

  @override
  State<TenantLeaseDetailsPage> createState() => _TenantLeaseDetailsPageState();
}

class _TenantLeaseDetailsPageState extends State<TenantLeaseDetailsPage> {
  Map<String, dynamic>? _lease;
  Map<String, dynamic>? _summary;
  String? _error;
  String? _summaryError;
  bool _loading = true;
  bool _loadingSummary = false;
  bool _savingPayment = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final lease = await widget.api.getLeaseDetails(
        widget.leaseId,
        widget.session.token,
      );
      if (!mounted) return;
      setState(() {
        _lease = lease;
        _loading = false;
      });
      await _loadSummary();
    } on TanteApiException catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadSummary() async {
    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });
    try {
      final summary = await widget.api.getLeaseRentSummary(
        widget.leaseId,
        widget.session.token,
      );
      if (mounted) setState(() => _summary = summary);
    } on TanteApiException catch (error) {
      if (mounted) setState(() => _summaryError = error.message);
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _recordPayment(Map block) async {
    final blockId = _intValue(block['id']);
    final amount = _doubleValue(block['outstandingAmount']);
    if (blockId == null || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment details are unavailable.')),
      );
      return;
    }
    final rent = _lease?['rent'] is Map
        ? Map<String, dynamic>.from(_lease!['rent'] as Map)
        : const <String, dynamic>{};
    final currency = rent['currency']?.toString() ?? 'TZS';
    final details = await showDialog<_TenantPaymentDetails>(
      context: context,
      builder: (context) =>
          _TenantPaymentDialog(amount: amount, currency: currency),
    );
    if (details == null || !mounted || _savingPayment) return;

    setState(() => _savingPayment = true);
    try {
      final confirmation = await widget.api.recordTenantLeasePayment(
        tenantId: widget.tenantId,
        paymentBlockId: blockId,
        amount: amount,
        currency: currency,
        payerUserId: widget.session.userId,
        method: details.method,
        reference: details.reference,
        note: details.note,
        token: widget.session.token,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(confirmation)));
      await _loadSummary();
    } on TanteApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _savingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lease ${_lease?['referenceNumber'] ?? widget.leaseId}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _errorState()
          : _lease == null
          ? const Center(child: Text('Lease details are unavailable.'))
          : _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final lease = _lease!;
    final rent = lease['rent'] is Map
        ? Map<String, dynamic>.from(lease['rent'] as Map)
        : const <String, dynamic>{};
    final expected = _doubleValue(_summary?['totalExpectedAmount']) ?? 0;
    final paid = _doubleValue(_summary?['totalPaidAmount']) ?? 0;
    final outstanding = _doubleValue(_summary?['totalOutstandingAmount']) ?? 0;
    final blocks = _summary?['paymentBlocks'] is List
        ? (_summary!['paymentBlocks'] as List).whereType<Map>().toList()
        : const <Map>[];
    final progress = expected <= 0 ? 0.0 : (paid / expected).clamp(0.0, 1.0);
    final tenant = lease['tenant'] is Map
        ? Map<String, dynamic>.from(lease['tenant'] as Map)
        : const <String, dynamic>{};

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lease ${lease['referenceNumber'] ?? lease['id']}',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                _statusChip(lease['status']),
              ],
            ),
          ),
        ),
        _sectionTitle(context, 'Lease information'),
        _detailsCard([
          _detail('Unit', lease['unitId']),
          _detail(
            'Tenant',
            '${tenant['firstName'] ?? ''} ${tenant['lastName'] ?? ''}'.trim(),
          ),
          _detail('Phone number', tenant['phoneNumber']),
          _detail('Email', tenant['email']),
          _detail('Start date', lease['startDate']),
          _detail('End date', lease['endDate']),
        ]),
        _sectionTitle(context, 'Rent terms'),
        _detailsCard([
          _detail('Rent', '${rent['amount'] ?? '—'} ${rent['currency'] ?? ''}'),
          _detail('Frequency', _readable(rent['frequency'])),
          _detail(
            'Payment requirement',
            lease['fullLeasePaymentRequired'] == true
                ? 'Full lease payment required'
                : 'Installments allowed',
          ),
        ]),
        _sectionTitle(context, 'Terms and conditions'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: (lease['leaseTerms']?.toString().trim().isNotEmpty ?? false)
                ? RichHtmlContent(html: lease['leaseTerms'].toString())
                : const Text('No lease terms and conditions were provided.'),
          ),
        ),
        _sectionTitle(context, 'Rent summary'),
        if (_loadingSummary)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_summaryError != null)
          Card(
            child: ListTile(
              title: const Text('Rent summary is unavailable'),
              subtitle: Text(_summaryError!),
              trailing: IconButton(
                tooltip: 'Retry rent summary',
                onPressed: _loadSummary,
                icon: const Icon(Icons.refresh),
              ),
            ),
          )
        else ...[
          _summaryCard('Total rent', expected, rent, Colors.blueGrey),
          _summaryCard('Paid', paid, rent, Colors.green),
          _summaryCard('Outstanding', outstanding, rent, Colors.deepOrange),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LinearProgressIndicator(value: progress),
            ),
          ),
          _sectionTitle(context, 'Payment schedule'),
          if (blocks.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No rent payment schedule is available.'),
              ),
            )
          else
            ...blocks.map((block) => _paymentBlock(block, rent)),
        ],
      ],
    );
  }

  Widget _paymentBlock(Map block, Map<String, dynamic> rent) {
    final amount = _doubleValue(block['amount']);
    final paid = _doubleValue(block['paidAmount']);
    final outstanding = _doubleValue(block['outstandingAmount']);
    final canRecord =
        outstanding != null &&
        outstanding > 0 &&
        block['status']?.toString().toUpperCase() != 'PAID' &&
        _lease?['status']?.toString().toUpperCase() != 'ENDED';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_date(block['startDate'])} – ${_date(block['endDate'])}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('Due ${_date(block['dueDate'])}'),
            Text('Amount: ${_money(amount, rent)}'),
            Text('Paid: ${_money(paid, rent)}'),
            Text('Outstanding: ${_money(outstanding, rent)}'),
            const SizedBox(height: 8),
            _statusChip(block['status']),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: canRecord && !_savingPayment
                  ? () => _recordPayment(block)
                  : null,
              icon: const Icon(Icons.payments_outlined),
              label: Text(_savingPayment ? 'Recording...' : 'Record payment'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(
    String title,
    double amount,
    Map<String, dynamic> rent,
    Color color,
  ) => Card(
    child: ListTile(
      title: Text(title),
      trailing: Text(
        _money(amount, rent),
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
    ),
  );

  Widget _detailsCard(List<Widget?> details) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: details.whereType<Widget>().toList()),
    ),
  );

  Widget? _detail(String label, Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty || text == 'null') return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _statusChip(Object? value) {
    final status = value?.toString() ?? 'UNKNOWN';
    final color = switch (status.toUpperCase()) {
      'ACTIVE' || 'PAID' => Colors.green,
      'PENDING' || 'PENDING_TENANT_APPROVAL' || 'DUE' => Colors.orange,
      'ENDED' || 'TERMINATED' || 'OVERDUE' => Colors.red,
      _ => Colors.blueGrey,
    };
    return Chip(
      label: Text(_readable(status)),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: .12),
      labelStyle: TextStyle(color: color.shade800),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
    child: Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Widget _errorState() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('Try again')),
        ],
      ),
    ),
  );

  String _money(double? amount, Map<String, dynamic> rent) => amount == null
      ? 'Not available'
      : '${rent['currency'] ?? 'TZS'} ${_number(amount)}';

  String _number(num value) => value.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );

  String _date(Object? value) {
    final raw = value?.toString() ?? '';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw.isEmpty ? 'Not set' : raw;
    final date = parsed.toLocal();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _TenantPaymentDetails {
  const _TenantPaymentDetails({
    required this.method,
    required this.reference,
    required this.note,
  });

  final String method;
  final String reference;
  final String note;
}

class _TenantPaymentDialog extends StatefulWidget {
  const _TenantPaymentDialog({required this.amount, required this.currency});

  final double amount;
  final String currency;

  @override
  State<_TenantPaymentDialog> createState() => _TenantPaymentDialogState();
}

class _TenantPaymentDialogState extends State<_TenantPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();
  String _method = 'CASH';

  @override
  void dispose() {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount: ${widget.currency} ${widget.amount.round()}'),
            const SizedBox(height: 16),
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
              decoration: const InputDecoration(
                labelText: 'Reference (optional)',
              ),
            ),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
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
          Navigator.pop(
            context,
            _TenantPaymentDetails(
              method: _method,
              reference: _referenceController.text.trim(),
              note: _noteController.text.trim(),
            ),
          );
        },
        child: const Text('Submit payment'),
      ),
    ],
  );
}

int? _intValue(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

double? _doubleValue(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

String _readable(Object? value) => (value?.toString() ?? 'Unknown')
    .split('_')
    .map(
      (word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
    )
    .join(' ');
