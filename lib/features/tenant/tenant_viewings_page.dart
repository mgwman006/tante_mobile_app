import 'package:flutter/material.dart';

class TenantViewingsPage extends StatelessWidget {
  const TenantViewingsPage({
    super.key,
    required this.bookings,
    required this.error,
    required this.onRetry,
  });

  final List<Map<String, dynamic>> bookings;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return _page(
        context,
        children: [
          Text(error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      );
    }
    if (bookings.isEmpty) {
      return _page(
        context,
        children: const [
          Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text("You haven't requested a viewing yet."),
            ),
          ),
        ],
      );
    }

    return _page(
      context,
      children: bookings.map((booking) {
        final status = booking['status']?.toString() ?? 'UNKNOWN';
        final paymentStatus = booking['paymentStatus']?.toString() ?? 'UNKNOWN';
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
                    const Icon(Icons.event_outlined),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Viewing booking',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _statusChip(status),
                  ],
                ),
                const SizedBox(height: 14),
                _detail('Reference', booking['reference']),
                _detail('Requested time', _dateTime(booking['startTime'])),
                _detail('Until', _dateTime(booking['endTime'])),
                if (paymentStatus != 'NOT_REQUIRED') ...[
                  _detail('Viewing fee', _money(booking['serviceFee'], 'TZS')),
                  Row(
                    children: [
                      const SizedBox(
                        width: 125,
                        child: Text(
                          'Payment',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                      _statusChip(paymentStatus),
                    ],
                  ),
                ],
                if (outcome != null)
                  _detail(
                    _readable(outcome['type']),
                    outcome['notes']?.toString(),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _page(BuildContext context, {required List<Widget> children}) =>
      ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          Text(
            'Viewing bookings',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF102F4C),
            ),
          ),
          const SizedBox(height: 6),
          const Text('Review the viewings you have requested.'),
          const SizedBox(height: 20),
          ...children,
        ],
      );

  Widget _detail(String label, Object? value) {
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = switch (status.toUpperCase()) {
      'PENDING' => Colors.orange,
      'CONFIRMED' => Colors.blue,
      'CLOSED' => Colors.green,
      'PAID' => Colors.green,
      'AWAITING_PAYMENT' => Colors.orange,
      'REFUNDED' => Colors.deepPurple,
      'REJECTED' || 'FAILED' => Colors.red,
      _ => Colors.blueGrey,
    };
    return Chip(
      label: Text(_readable(status)),
      visualDensity: VisualDensity.compact,
      backgroundColor: color.withValues(alpha: .12),
      labelStyle: TextStyle(color: color.shade800),
    );
  }

  String _dateTime(Object? value) {
    final text = value?.toString() ?? '';
    final date = DateTime.tryParse(text);
    if (date == null) return text.isEmpty ? 'Not provided' : text;
    final local = date.toLocal();
    final dateText =
        '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
    final timeText = '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
    return '$dateText, $timeText';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _money(Object? value, String currency) {
    final amount = num.tryParse(value?.toString() ?? '');
    return amount == null ? 'Not provided' : '$currency ${_number(amount)}';
  }

  String _number(num value) => value.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => ',',
  );

  String _readable(Object? value) => (value?.toString() ?? 'Unknown')
      .split('_')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}
