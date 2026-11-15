import 'package:flutter/material.dart';
import 'package:tante/services/tante_api.dart';

const _bookingStatuses = [
  'PENDING',
  'CONFIRMED',
  'REJECTED',
  'CANCELLED',
  'CLOSED',
  'EXPIRED',
  'RESCHEDULED',
  'DRAFT',
];

const _viewingOutcomes = [
  'COMPLETED',
  'AGENT_ABSENT',
  'TENANT_ABSENT',
  'UNIT_NOT_AVAILABLE',
  'RESCHEDULED',
];

class LandlordViewingsPage extends StatefulWidget {
  const LandlordViewingsPage({
    super.key,
    required this.api,
    required this.rentalProfileId,
    required this.rentalProfileName,
    required this.token,
    this.onBookingsLoaded,
  });

  final TanteApi api;
  final int rentalProfileId;
  final String rentalProfileName;
  final String token;
  final ValueChanged<int>? onBookingsLoaded;

  @override
  State<LandlordViewingsPage> createState() => _LandlordViewingsPageState();
}

class _LandlordViewingsPageState extends State<LandlordViewingsPage> {
  List<Map<String, dynamic>> _bookings = const [];
  final Set<int> _updatingBookingIds = {};
  String _statusFilter = 'ALL';
  String? _error;
  bool _loading = true;
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  @override
  void didUpdateWidget(covariant LandlordViewingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rentalProfileId != widget.rentalProfileId ||
        oldWidget.token != widget.token) {
      _loadBookings();
    }
  }

  Future<void> _loadBookings() async {
    final requestId = ++_loadRequestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bookings = await widget.api.getViewingBookings(
        widget.rentalProfileId,
        widget.token,
      );
      if (!mounted || requestId != _loadRequestId) return;
      setState(() => _bookings = bookings);
      widget.onBookingsLoaded?.call(bookings.length);
    } on TanteApiException catch (error) {
      if (mounted && requestId == _loadRequestId) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && requestId == _loadRequestId) {
        setState(() => _loading = false);
      }
    }
  }

  List<Map<String, dynamic>> get _filteredBookings {
    if (_statusFilter == 'ALL') return _bookings;
    return _bookings
        .where((booking) => booking['status'] == _statusFilter)
        .toList();
  }

  Future<void> _confirmBookingAction(
    Map<String, dynamic> booking,
    String action,
  ) async {
    final bookingId = _intValue(booking['id']);
    if (bookingId == null || _updatingBookingIds.contains(bookingId)) return;
    final actionLabel = action == 'approve'
        ? 'Approve'
        : action == 'reject'
        ? 'Reject'
        : 'Cancel';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$actionLabel viewing?'),
        content: Text('Do you want to $actionLabel this viewing booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep booking'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _updatingBookingIds.add(bookingId));
    try {
      final updated = switch (action) {
        'approve' => await widget.api.approveViewingBooking(
          bookingId: bookingId,
          token: widget.token,
        ),
        'reject' => await widget.api.rejectViewingBooking(
          bookingId: bookingId,
          token: widget.token,
        ),
        _ => await widget.api.cancelViewingBooking(
          bookingId: bookingId,
          token: widget.token,
        ),
      };
      _replaceBooking(updated);
      if (mounted) {
        final resultLabel = switch (action) {
          'approve' => 'approved',
          'reject' => 'rejected',
          _ => 'cancelled',
        };
        _showMessage('Viewing booking $resultLabel.');
      }
    } on TanteApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _updatingBookingIds.remove(bookingId));
      }
    }
  }

  Future<void> _recordOutcome(Map<String, dynamic> booking) async {
    final bookingId = _intValue(booking['id']);
    if (bookingId == null || _updatingBookingIds.contains(bookingId)) return;
    final result = await _showOutcomeDialog();
    if (result == null || !mounted) return;
    setState(() => _updatingBookingIds.add(bookingId));
    try {
      final updated = await widget.api.recordViewingOutcome(
        bookingId: bookingId,
        outcome: result['outcome']!,
        notes: result['notes'],
        token: widget.token,
      );
      _replaceBooking(updated);
      if (mounted) _showMessage('Viewing outcome recorded.');
    } on TanteApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _updatingBookingIds.remove(bookingId));
      }
    }
  }

  Future<Map<String, String>?> _showOutcomeDialog() async {
    final formKey = GlobalKey<FormState>();
    String? outcome;
    String notes = '';
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record viewing outcome'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: outcome,
                  decoration: const InputDecoration(labelText: 'Outcome'),
                  items: _viewingOutcomes
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(_formatEnum(value)),
                        ),
                      )
                      .toList(),
                  validator: (value) =>
                      value == null ? 'Select the viewing outcome.' : null,
                  onChanged: (value) => setDialogState(() => outcome = value),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    alignLabelWithHint: true,
                  ),
                  onChanged: (value) => notes = value,
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
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, {
                    'outcome': outcome!,
                    'notes': notes.trim(),
                  });
                }
              },
              child: const Text('Save outcome'),
            ),
          ],
        ),
      ),
    );
  }

  void _replaceBooking(Map<String, dynamic> updated) {
    final updatedId = _intValue(updated['id']);
    if (!mounted || updatedId == null) return;
    setState(() {
      _bookings = _bookings
          .map(
            (booking) =>
                _intValue(booking['id']) == updatedId ? updated : booking,
          )
          .toList();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Viewing bookings',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: const Color(0xFF102F4C),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(widget.rentalProfileName),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh bookings',
              onPressed: _loading ? null : _loadBookings,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _statusFilter,
          decoration: const InputDecoration(
            labelText: 'Filter by status',
            border: OutlineInputBorder(),
          ),
          items: [
            const DropdownMenuItem(value: 'ALL', child: Text('All statuses')),
            ..._bookingStatuses.map(
              (status) => DropdownMenuItem(
                value: status,
                child: Text(_formatEnum(status)),
              ),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _statusFilter = value);
          },
        ),
        const SizedBox(height: 12),
        if (_loading && _bookings.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null && _bookings.isEmpty)
          _ErrorCard(message: _error!, onRetry: _loadBookings)
        else if (_filteredBookings.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _bookings.isEmpty
                    ? 'No viewing bookings found.'
                    : 'No bookings match this status.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else ...[
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Text('${_filteredBookings.length} bookings'),
          const SizedBox(height: 8),
          ..._filteredBookings.map(
            (booking) => _BookingCard(
              booking: booking,
              loading: _updatingBookingIds.contains(_intValue(booking['id'])),
              onApprove: () => _confirmBookingAction(booking, 'approve'),
              onReject: () => _confirmBookingAction(booking, 'reject'),
              onCancel: () => _confirmBookingAction(booking, 'cancel'),
              onRecordOutcome: () => _recordOutcome(booking),
              dateTimeLabel: (value) => _formatDateTime(value, localizations),
            ),
          ),
        ],
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.loading,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
    required this.onRecordOutcome,
    required this.dateTimeLabel,
  });

  final Map<String, dynamic> booking;
  final bool loading;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancel;
  final VoidCallback onRecordOutcome;
  final String Function(Object?) dateTimeLabel;

  @override
  Widget build(BuildContext context) {
    final status = booking['status']?.toString() ?? 'UNKNOWN';
    final paymentStatus = booking['paymentStatus']?.toString() ?? 'UNKNOWN';
    final serviceFee = _doubleValue(booking['serviceFee']) ?? 0;
    final canApprove = serviceFee <= 0 || paymentStatus == 'PAID';
    final outcome = booking['outcome'] is Map
        ? Map<String, dynamic>.from(booking['outcome'] as Map)
        : null;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    dateTimeLabel(booking['startTime']),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusChip(value: status),
              ],
            ),
            const SizedBox(height: 12),
            if (booking['reference']?.toString().isNotEmpty ?? false)
              _BookingDetail(
                label: 'Reference',
                value: booking['reference'].toString(),
              ),
            _BookingDetail(
              label: 'Ends',
              value: dateTimeLabel(booking['endTime']),
            ),
            _BookingDetail(
              label: 'Unit',
              value: 'Unit #${booking['unitId'] ?? '—'}',
            ),
            _BookingDetail(
              label: 'Requester',
              value: 'User #${booking['requesterUserId'] ?? '—'}',
            ),
            _BookingDetail(
              label: 'Service fee',
              value: 'TSh ${_formatAmount(serviceFee)}',
            ),
            _BookingDetail(label: 'Payment', value: _formatEnum(paymentStatus)),
            if (booking['paymentUpdatedAt'] != null)
              _BookingDetail(
                label: 'Payment updated',
                value: dateTimeLabel(booking['paymentUpdatedAt']),
              ),
            if (booking['holdExpiresAt'] != null)
              _BookingDetail(
                label: 'Hold expires',
                value: dateTimeLabel(booking['holdExpiresAt']),
              ),
            if ((booking['notes']?.toString().trim().isNotEmpty ?? false))
              _BookingDetail(
                label: 'Notes',
                value: booking['notes'].toString(),
              ),
            if (outcome != null)
              _BookingDetail(
                label: 'Outcome',
                value: [
                  _formatEnum(outcome['type']?.toString() ?? 'UNKNOWN'),
                  if (outcome['notes']?.toString().trim().isNotEmpty ?? false)
                    outcome['notes'].toString(),
                ].join(' — '),
              ),
            const SizedBox(height: 12),
            if (status == 'PENDING')
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: loading || !canApprove ? null : onApprove,
                    child: loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Approve'),
                  ),
                  OutlinedButton(
                    onPressed: loading ? null : onReject,
                    child: const Text('Reject'),
                  ),
                  if (!canApprove)
                    const Text(
                      'Payment must be completed before approval.',
                      style: TextStyle(fontSize: 12),
                    ),
                ],
              )
            else if (status == 'CONFIRMED')
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: loading ? null : onRecordOutcome,
                    child: const Text('Record outcome'),
                  ),
                  TextButton(
                    onPressed: loading ? null : onCancel,
                    child: const Text('Cancel viewing'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _BookingDetail extends StatelessWidget {
  const _BookingDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final color = switch (value) {
      'PENDING' => Colors.orange,
      'CONFIRMED' => Colors.blue,
      'REJECTED' => Colors.red,
      'CLOSED' => Colors.green,
      'RESCHEDULED' => Colors.purple,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(_formatEnum(value)),
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: color.shade700),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(Object? value, MaterialLocalizations localizations) {
  final date = DateTime.tryParse(value?.toString() ?? '');
  if (date == null) return value?.toString() ?? '—';
  final localDate = date.toLocal();
  return '${localizations.formatMediumDate(localDate)} '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(localDate))}';
}

String _formatEnum(String value) => value
    .split('_')
    .where((word) => word.isNotEmpty)
    .map((word) => '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
    .join(' ');

String _formatAmount(double value) => value
    .toStringAsFixed(0)
    .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => ',');

int? _intValue(Object? value) =>
    value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');

double? _doubleValue(Object? value) =>
    value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
