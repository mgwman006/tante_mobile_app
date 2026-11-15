int? rentalProfileIdFrom(Object? value) {
  return value is num ? value.toInt() : int.tryParse(value?.toString() ?? '');
}

String rentalProfileTypeLabel(Object? value) {
  final type = value?.toString().toUpperCase() ?? '';
  return switch (type) {
    'INDIVIDUAL' => 'Individual',
    'BUSINESS' => 'Business',
    'ENTERPRISE' => 'Enterprise',
    _ => type.isEmpty ? 'Rental' : type,
  };
}
