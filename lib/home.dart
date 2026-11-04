import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  String _role = 'Landlord';
  bool _roleLoaded = false;

  bool get _isLandlord => _role == 'Landlord';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_roleLoaded) {
      _role = ModalRoute.of(context)?.settings.arguments as String? ?? 'Landlord';
      _roleLoaded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final titles = _isLandlord
        ? const ['Overview', 'Properties', 'Leases', 'Account']
        : const ['Overview', 'My rent', 'Leases', 'Account'];
    final pages = _isLandlord
        ? [_landlordOverview(), _properties(), _leases(), _account()]
        : [_tenantOverview(), _rent(), _leases(), _account()];

    return Scaffold(
      appBar: AppBar(
        title: const Text('tante',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: .5)),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () => _openWorkflow(
              'Notifications',
              ['Lease updates', 'Rent reminders', 'New messages from your property manager'],
              'Mark all as read',
            ),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.grid_view_rounded), label: 'Overview'),
          NavigationDestination(
              icon: Icon(_isLandlord ? Icons.apartment_rounded : Icons.payments_outlined),
              label: _isLandlord ? 'Properties' : 'My rent'),
          const NavigationDestination(
              icon: Icon(Icons.description_outlined), label: 'Leases'),
          const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded), label: 'Account'),
        ],
      ),
    );
  }

  Widget _landlordOverview() => _page(
        greeting: 'Good morning, Alex',
        subtitle: 'Here is what is happening with your rentals.',
        children: [
          _summaryGrid([
            _SummaryData('Properties', '4', Icons.apartment_rounded, const Color(0xFFCCFBF1)),
            _SummaryData('Active leases', '8', Icons.description_outlined, const Color(0xFFDBEAFE)),
            _SummaryData('Rent this month', '\$8,450', Icons.payments_outlined, const Color(0xFFFEF3C7)),
            _SummaryData('Invitations', '2', Icons.mark_email_unread_outlined, const Color(0xFFEDE9FE)),
          ]),
          _sectionHeading('Quick actions'),
          _actionTile(Icons.add_home_work_outlined, 'Add a property', 'Create a property profile',
              () => _openForm('Add property', ['Property name', 'Address', 'Number of units'])),
          _actionTile(Icons.note_add_outlined, 'Create a lease', 'Set up a rental agreement',
              () => _openForm('Create lease', ['Property and unit', 'Tenant email', 'Monthly rent', 'Lease start date', 'Lease end date'])),
          _actionTile(Icons.person_add_alt_1_rounded, 'Invite a tenant', 'Send an invitation to join',
              () => _openWorkflow('Invite a tenant', ['Enter the tenant’s email address', 'Choose the property and unit', 'Review and send the invitation'], 'Send invitation')),
          _sectionHeading('Needs your attention'),
          _noticeCard(Icons.schedule_rounded, '2 leases need attention', 'Review upcoming renewals and pending signatures.',
              () => _openWorkflow('Lease reminders', ['Oak Street · renewal in 14 days', 'Parkview · awaiting tenant signature'], 'Review leases')),
          _sectionHeading('Recent activity'),
          _activity('Rent payment received', 'Unit 3B · 12 May', Icons.check_circle_outline_rounded),
          _activity('Tenant invitation sent', 'Jordan Lee · 10 May', Icons.mail_outline_rounded),
        ],
      );

  Widget _tenantOverview() => _page(
        greeting: 'Welcome home, Jordan',
        subtitle: 'Your rental information, all together.',
        children: [
          _rentHighlight(),
          _sectionHeading('Your home'),
          _propertyCard('Oak Street Apartments', 'Unit 3B · 24 Oak Street', 'Active lease'),
          _sectionHeading('Quick actions'),
          _actionTile(Icons.receipt_long_outlined, 'View rent statement', 'See your balance and payment history',
              () => setState(() => _selectedIndex = 1)),
          _actionTile(Icons.description_outlined, 'View lease', 'Check dates and agreement details',
              () => _openWorkflow('Lease details', ['Oak Street Apartments · Unit 3B', 'Lease term: 1 Jan – 31 Dec 2026', 'Monthly rent: \$1,450', 'Status: Active'], 'Contact landlord')),
          _actionTile(Icons.build_outlined, 'Request maintenance', 'Tell your property manager about an issue',
              () => _openForm('Maintenance request', ['Issue title', 'Describe the issue', 'Preferred access time'])),
          _sectionHeading('Updates'),
          _noticeCard(Icons.info_outline_rounded, 'Inspection scheduled', 'Your next property inspection is on 18 June.',
              () => _openWorkflow('Inspection details', ['18 June · 10:00 AM', 'Your property manager will confirm the time.'], 'Got it')),
        ],
      );

  Widget _properties() => _page(
        greeting: 'Your properties',
        subtitle: 'Manage buildings, units, and property details.',
        children: [
          FilledButton.icon(
            onPressed: () => _openForm('Add property', ['Property name', 'Address', 'Number of units']),
            icon: const Icon(Icons.add),
            label: const Text('Add property'),
          ),
          const SizedBox(height: 18),
          _propertyCard('Oak Street Apartments', '24 Oak Street · 4 units', '3 occupied'),
          _propertyCard('Parkview House', '18 Park Avenue · 2 units', '2 occupied'),
          _propertyCard('Lakeside Villas', '7 Lake Road · 6 units', '5 occupied'),
          _propertyCard('Maple Court', '102 Maple Lane · 3 units', '2 occupied'),
        ],
      );

  Widget _leases() => _page(
        greeting: 'Leases',
        subtitle: _isLandlord ? 'Review agreements and manage tenants.' : 'Your rental agreements and key dates.',
        children: [
          if (_isLandlord) ...[
            FilledButton.icon(
              onPressed: () => _openForm('Create lease', ['Property and unit', 'Tenant email', 'Monthly rent', 'Lease start date', 'Lease end date']),
              icon: const Icon(Icons.add),
              label: const Text('Create lease'),
            ),
            const SizedBox(height: 18),
          ],
          _leaseCard('Oak Street Apartments · Unit 3B', _isLandlord ? 'Jordan Lee' : '1 Jan – 31 Dec 2026', 'Active',
              () => _openWorkflow('Lease details', ['Oak Street Apartments · Unit 3B', 'Tenant: Jordan Lee', 'Monthly rent: \$1,450', 'Term: 1 Jan – 31 Dec 2026', 'Status: Active'], 'View rent summary')),
          _leaseCard('Parkview House · Unit 1', _isLandlord ? 'Morgan Chen' : '1 Mar 2026 – 28 Feb 2027', 'Active',
              () => _openWorkflow('Lease details', ['Parkview House · Unit 1', 'Monthly rent: \$1,800', 'Status: Active'], 'View details')),
          _leaseCard('Maple Court · Unit 2', _isLandlord ? 'Pending invitation' : 'Invitation pending', 'Pending',
              () => _openWorkflow('Invitation details', ['Maple Court · Unit 2', 'Review the lease invitation and sign to continue.'], 'Review invitation')),
        ],
      );

  Widget _rent() => _page(
        greeting: 'Rent and payments',
        subtitle: 'Track your balance, upcoming payments, and receipts.',
        children: [
          _rentHighlight(),
          _sectionHeading('Payment history'),
          _paymentRow('May 2026 rent', '\$1,450', 'Paid · 1 May'),
          _paymentRow('April 2026 rent', '\$1,450', 'Paid · 1 Apr'),
          _paymentRow('March 2026 rent', '\$1,450', 'Paid · 1 Mar'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openWorkflow('Rent statement', ['Oak Street Apartments · Unit 3B', 'Monthly rent: \$1,450', 'Next payment due: 1 June 2026', 'No outstanding balance'], 'Download statement'),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('View full rent statement'),
          ),
        ],
      );

  Widget _account() => _page(
        greeting: 'Account',
        subtitle: 'Manage your profile and preferences.',
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFCCFBF1),
                child: Text(_isLandlord ? 'A' : 'J', style: const TextStyle(color: Color(0xFF0F766E), fontWeight: FontWeight.bold)),
              ),
              title: Text(_isLandlord ? 'Alex Morgan' : 'Jordan Lee'),
              subtitle: Text('$_role account · alex@example.com'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openWorkflow('Profile', ['Name', 'Email address', 'Contact number', 'Account type: $_role'], 'Edit profile'),
            ),
          ),
          _actionTile(Icons.notifications_outlined, 'Notifications', 'Choose which updates you receive',
              () => _openWorkflow('Notification preferences', ['Rent reminders', 'Lease updates', 'Property messages'], 'Save preferences')),
          _actionTile(Icons.help_outline_rounded, 'Help and support', 'Get help with your Tante account',
              () => _openWorkflow('Help and support', ['Frequently asked questions', 'Contact support: support@tante.example'], 'Contact support')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Log out'),
          ),
        ],
      );

  Widget _page({required String greeting, required String subtitle, required List<Widget> children}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(greeting,
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Color(0xFF0F172A))),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), height: 1.4)),
        const SizedBox(height: 22),
        ...children,
      ],
    );
  }

  Widget _summaryGrid(List<_SummaryData> items) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.45,
        children: items.map((item) => Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              CircleAvatar(radius: 17, backgroundColor: item.tint, child: Icon(item.icon, size: 18, color: const Color(0xFF0F766E))),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                Text(item.label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              ]),
            ]),
          ),
        )).toList(),
      );

  Widget _sectionHeading(String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 10),
        child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w750, color: Color(0xFF0F172A))),
      );

  Widget _actionTile(IconData icon, String title, String subtitle, VoidCallback onTap) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          leading: CircleAvatar(backgroundColor: const Color(0xFFF1F5F9), child: Icon(icon, color: const Color(0xFF0F766E))),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w650)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );

  Widget _propertyCard(String name, String address, String status) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openWorkflow(name, [address, status, 'View units, leases, and property activity.'], 'Manage property'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(width: 54, height: 54, decoration: BoxDecoration(color: const Color(0xFFCCFBF1), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.apartment_rounded, color: Color(0xFF0F766E))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: const TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 4), Text(address, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))), const SizedBox(height: 7), Text(status, style: const TextStyle(fontSize: 12, color: Color(0xFF0F766E), fontWeight: FontWeight.w600))])),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
            ]),
          ),
        ),
      );

  Widget _leaseCard(String name, String detail, String status, VoidCallback onTap) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.all(14),
          leading: const CircleAvatar(backgroundColor: Color(0xFFDBEAFE), child: Icon(Icons.description_outlined, color: Color(0xFF1D4ED8))),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text('$detail\n$status')),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );

  Widget _noticeCard(IconData icon, String title, String message, VoidCallback onTap) => Card(
        color: const Color(0xFFFFFBEB),
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFFB45309)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(message),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      );

  Widget _activity(String title, String subtitle, IconData icon) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(backgroundColor: const Color(0xFFF1F5F9), child: Icon(icon, color: const Color(0xFF0F766E), size: 20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
      );

  Widget _rentHighlight() => Card(
        color: const Color(0xFF0F766E),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Next rent payment', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            const Text('\$1,450', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Due 1 June · Oak Street, Unit 3B', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 18),
            FilledButton.tonalIcon(
              onPressed: () => _openWorkflow('Make a payment', ['Amount due: \$1,450', 'Payment method: Add or select a payment method', 'Confirm your payment to receive a receipt.'], 'Continue to payment'),
              icon: const Icon(Icons.lock_outline_rounded),
              label: const Text('Pay rent securely'),
            ),
          ]),
        ),
      );

  Widget _paymentRow(String title, String amount, String status) => Card(
        margin: const EdgeInsets.only(bottom: 9),
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: Color(0xFFDCFCE7), child: Icon(Icons.check_rounded, color: Color(0xFF15803D))),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w650)),
          subtitle: Text(status),
          trailing: Text(amount, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      );

  void _openWorkflow(String title, List<String> steps, String actionLabel) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (context) => _WorkflowPage(title: title, steps: steps, actionLabel: actionLabel),
    ));
  }

  void _openForm(String title, List<String> fields) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (context) => _EntryFormPage(title: title, fields: fields),
    ));
  }
}

class _SummaryData {
  const _SummaryData(this.label, this.value, this.icon, this.tint);
  final String label;
  final String value;
  final IconData icon;
  final Color tint;
}

class _WorkflowPage extends StatelessWidget {
  const _WorkflowPage({required this.title, required this.steps, required this.actionLabel});
  final String title;
  final List<String> steps;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Review the information and continue when you are ready.', style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 20),
            ...steps.map((step) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(padding: const EdgeInsets.all(16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF0F766E)),
                const SizedBox(width: 12),
                Expanded(child: Text(step, style: const TextStyle(height: 1.4))),
              ])),
            )),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$actionLabel selected')));
                Navigator.pop(context);
              },
              child: Text(actionLabel),
            ),
          ],
        ),
      );
}

class _EntryFormPage extends StatefulWidget {
  const _EntryFormPage({required this.title, required this.fields});
  final String title;
  final List<String> fields;

  @override
  State<_EntryFormPage> createState() => _EntryFormPageState();
}

class _EntryFormPageState extends State<_EntryFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.fields.length, (_) => TextEditingController());
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(widget.title, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('Add the details below to continue.', style: TextStyle(color: Color(0xFF64748B))),
              const SizedBox(height: 22),
              ...List.generate(widget.fields.length, (index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextFormField(
                  controller: _controllers[index],
                  maxLines: widget.fields[index].toLowerCase().contains('describe') ? 4 : 1,
                  decoration: InputDecoration(labelText: widget.fields[index]),
                  validator: (value) => value == null || value.trim().isEmpty ? 'This field is required' : null,
                ),
              )),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Details saved')));
                  Navigator.pop(context);
                },
                child: const Text('Save and continue'),
              ),
            ],
          ),
        ),
      );
}
