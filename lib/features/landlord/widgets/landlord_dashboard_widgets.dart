import 'package:flutter/material.dart';

class LandlordPageLayout extends StatelessWidget {
  const LandlordPageLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: Color(0xFF102F4C),
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: Color(0xFF3E5674))),
        const SizedBox(height: 22),
        ...children,
      ],
    );
  }
}

class LandlordSectionHeading extends StatelessWidget {
  const LandlordSectionHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: Color(0xFF102F4C),
        ),
      ),
    );
  }
}

class LandlordMetricCard extends StatelessWidget {
  const LandlordMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE7F8E7),
          child: Icon(icon, color: const Color(0xFF19A75C)),
        ),
        title: Text(
          value,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(label),
      ),
    );
  }
}

class PropertyDataCard extends StatelessWidget {
  const PropertyDataCard({
    super.key,
    required this.icon,
    required this.title,
    required this.type,
    required this.address,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String type;
  final String address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE7F8E7),
          child: Icon(icon, color: const Color(0xFF19A75C)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(type, style: const TextStyle(fontWeight: FontWeight.w600)),
            if (address.isNotEmpty) Text(address),
          ],
        ),
        isThreeLine: true,
        onTap: onTap,
      ),
    );
  }
}

class LeaseDataCard extends StatelessWidget {
  const LeaseDataCard({
    super.key,
    required this.title,
    required this.status,
    required this.statusColor,
    required this.detail,
    this.onTap,
  });

  final String title;
  final String status;
  final Color statusColor;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE7F8E7),
          child: Icon(Icons.description_outlined, color: Color(0xFF19A75C)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text(status),
                visualDensity: VisualDensity.compact,
                backgroundColor: statusColor.withValues(alpha: .12),
                side: BorderSide(color: statusColor.withValues(alpha: .35)),
                labelStyle: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (detail.isNotEmpty) Text(detail),
          ],
        ),
        isThreeLine: true,
        onTap: onTap,
      ),
    );
  }
}

class LandlordInfoCard extends StatelessWidget {
  const LandlordInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return _SummaryDataCard(icon: icon, title: title, detail: detail);
  }
}

class _SummaryDataCard extends StatelessWidget {
  const _SummaryDataCard({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE7F8E7),
          child: Icon(icon, color: const Color(0xFF19A75C)),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(detail),
      ),
    );
  }
}

class LandlordActionCard extends StatelessWidget {
  const LandlordActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF19A75C)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class LandlordEmptyState extends StatelessWidget {
  const LandlordEmptyState(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(message, textAlign: TextAlign.center)),
    );
  }
}
