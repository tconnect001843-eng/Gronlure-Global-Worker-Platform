import 'package:flutter/material.dart';

import 'api_client.dart';

extension _PlatformColors on BuildContext {
  Color get appBrand => Theme.of(this).colorScheme.primary;
  Color get appInk => Theme.of(this).colorScheme.onSurface;
  Color get appMuted => Theme.of(this).colorScheme.onSurfaceVariant;
  Color get appSoft => Theme.of(this).colorScheme.surfaceContainerHigh;
  Color get appBorder => Theme.of(this).colorScheme.outlineVariant;
}

class PlatformShell extends StatefulWidget {
  const PlatformShell({
    required this.api,
    required this.isDark,
    required this.onToggleTheme,
    super.key,
  });

  final PlatformApi api;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  State<PlatformShell> createState() => _PlatformShellState();
}

class _PlatformShellState extends State<PlatformShell> {
  bool _signedIn = false;
  bool _registering = false;
  int _section = 0;
  int _jobsRevision = 0;
  Map<String, dynamic> _profile = {
    'full_name': 'Alex Nambasa',
    'phone': '+256 700 123 456',
    'location': 'Kampala, Uganda',
    'headline': 'Reliable electrician · 6 years experience',
    'skills': 'Electrical wiring, Solar installation, Maintenance',
  };

  void _authenticated(Map<String, dynamic> data) {
    final profile = data['profile'];
    setState(() {
      _signedIn = true;
      if (profile is Map<String, dynamic>) {
        _profile = {..._profile, ...profile};
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_signedIn) {
      return AuthScreen(
        api: widget.api,
        isDark: widget.isDark,
        onToggleTheme: widget.onToggleTheme,
        registering: _registering,
        onAuthenticated: _authenticated,
        onToggle: () => setState(() => _registering = !_registering),
      );
    }
    return DashboardShell(
      api: widget.api,
      selectedIndex: _section,
      jobsRevision: _jobsRevision,
      onJobCreated: () => setState(() => _jobsRevision++),
      isDark: widget.isDark,
      onToggleTheme: widget.onToggleTheme,
      profile: _profile,
      onNavigate: (index) => setState(() => _section = index),
      onProfileChanged: (profile) => setState(() => _profile = profile),
      onLogout: () => setState(() {
        _signedIn = false;
        _section = 0;
      }),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    required this.api,
    required this.isDark,
    required this.onToggleTheme,
    required this.registering,
    required this.onAuthenticated,
    required this.onToggle,
    super.key,
  });

  final PlatformApi api;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final bool registering;
  final ValueChanged<Map<String, dynamic>> onAuthenticated;
  final VoidCallback onToggle;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _terms = false;
  bool _loading = false;
  bool _passwordVisible = false;
  bool _confirmVisible = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.registering && !_terms) {
      setState(
        () => _error = 'Please accept the Terms of Service to continue.',
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = widget.registering
          ? await widget.api.register(
              fullName: _name.text.trim(),
              phone: _phone.text.trim(),
              password: _password.text,
            )
          : await widget.api.login(
              phone: _phone.text.trim(),
              password: _password.text,
            );
      if (mounted) widget.onAuthenticated(data);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final register = widget.registering;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1060),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Brand(),
                      const SizedBox(width: 12),
                      _ThemeToggle(
                        isDark: widget.isDark,
                        onToggle: widget.onToggleTheme,
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final split = constraints.maxWidth > 720;
                      final form = _authForm(register);
                      if (!split) return form;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _welcomePanel()),
                          const SizedBox(width: 18),
                          Expanded(child: form),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 22,
                    children: [
                      _footerLink(
                        context,
                        'Privacy Policy',
                        () => _info(context, 'Privacy Policy'),
                      ),
                      _footerLink(
                        context,
                        'Terms of Service',
                        () => _info(context, 'Terms of Service'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _welcomePanel() => Container(
    padding: const EdgeInsets.all(34),
    decoration: BoxDecoration(
      color: const Color(0xFF155C45),
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFF155C45), Color(0xFF23795A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.public, color: Colors.white, size: 30),
        SizedBox(height: 36),
        Text(
          'Good work deserves to be seen.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 14),
        Text(
          'Build your reputation, find trusted people, and grow opportunities — all in one place.',
          style: TextStyle(color: Color(0xFFD8EEE2), height: 1.6, fontSize: 15),
        ),
        SizedBox(height: 28),
        Row(
          children: [
            Icon(Icons.verified, color: Color(0xFFC8E97C)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Verified profiles. Real experience.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _authForm(bool register) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              register ? 'Create your account' : 'Welcome back',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: context.appInk,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              register
                  ? 'One profile. Many opportunities.'
                  : 'Sign in to continue to Gronlure.',
            ),
            const SizedBox(height: 24),
            if (register) ...[
              _field('Full name', _name, icon: Icons.person_outline),
              const SizedBox(height: 14),
            ],
            _field(
              'Phone number',
              _phone,
              icon: Icons.phone_outlined,
              hint: '+256 7XX XXX XXX',
            ),
            const SizedBox(height: 14),
            _field(
              'Password',
              _password,
              icon: Icons.lock_outline,
              password: true,
              visible: _passwordVisible,
              onToggleVisibility: () =>
                  setState(() => _passwordVisible = !_passwordVisible),
            ),
            if (register) ...[
              const SizedBox(height: 14),
              _field(
                'Confirm password',
                _confirm,
                icon: Icons.lock_outline,
                password: true,
                visible: _confirmVisible,
                onToggleVisibility: () =>
                    setState(() => _confirmVisible = !_confirmVisible),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _terms,
                onChanged: (value) => setState(() => _terms = value ?? false),
                title: const Text(
                  'I agree to the Terms of Service and Privacy Policy',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      )
                    : Text(register ? 'Create account' : 'Login'),
              ),
            ),
            if (!register)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _info(context, 'Password reset'),
                  child: const Text('Forgot password?'),
                ),
              ),
            const Divider(height: 24),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    register ? 'Already have an account?' : 'New to Gronlure?',
                  ),
                  TextButton(
                    onPressed: widget.onToggle,
                    child: Text(register ? 'Login' : 'Create account'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _field(
    String label,
    TextEditingController controller, {
    required IconData icon,
    String? hint,
    bool password = false,
    bool visible = false,
    VoidCallback? onToggleVisibility,
  }) => TextFormField(
    controller: controller,
    obscureText: password && !visible,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: password
          ? IconButton(
              tooltip: visible ? 'Hide password' : 'Show password',
              onPressed: onToggleVisibility,
              icon: Icon(
                visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            )
          : null,
    ),
    validator: (value) {
      if (value == null || value.trim().isEmpty) return '$label is required.';
      if (password && value.length < 8) return 'Use at least 8 characters.';
      if (label == 'Confirm password' && value != _password.text) {
        return 'Passwords do not match.';
      }
      return null;
    },
  );

  Widget _footerLink(BuildContext context, String text, VoidCallback onTap) =>
      TextButton(
        onPressed: onTap,
        child: Text(text, style: TextStyle(color: context.appMuted)),
      );
}

class DashboardShell extends StatelessWidget {
  const DashboardShell({
    required this.api,
    required this.selectedIndex,
    required this.jobsRevision,
    required this.onJobCreated,
    required this.isDark,
    required this.onToggleTheme,
    required this.profile,
    required this.onNavigate,
    required this.onProfileChanged,
    required this.onLogout,
    super.key,
  });

  final PlatformApi api;
  final int selectedIndex;
  final int jobsRevision;
  final VoidCallback onJobCreated;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final Map<String, dynamic> profile;
  final ValueChanged<int> onNavigate;
  final ValueChanged<Map<String, dynamic>> onProfileChanged;
  final VoidCallback onLogout;

  static const _labels = [
    'Overview',
    'Find Work',
    'My Jobs',
    'Payments',
    'Admin',
  ];
  static const _icons = [
    Icons.grid_view_rounded,
    Icons.search_rounded,
    Icons.work_outline_rounded,
    Icons.account_balance_wallet_outlined,
    Icons.admin_panel_settings_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final page = _page(context);
        return Scaffold(
          appBar: AppBar(
            title: wide ? null : const Brand(compact: true),
            actions: [
              _ThemeToggle(isDark: isDark, onToggle: onToggleTheme),
              IconButton(
                tooltip: 'Notifications',
                onPressed: () => _snack(context, 'You are all caught up.'),
                icon: const Icon(Icons.notifications_none),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: CircleAvatar(
                  backgroundColor: context.appSoft,
                  child: Text(
                    _initials(_name),
                    style: TextStyle(color: context.appBrand),
                  ),
                ),
              ),
            ],
          ),
          body: Row(
            children: [
              if (wide) _sideBar(context),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1320),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 34 : 18,
                        22,
                        wide ? 34 : 18,
                        36,
                      ),
                      child: page,
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onNavigate,
                  destinations: List.generate(
                    _isAdmin ? 5 : 4,
                    (index) => NavigationDestination(
                      icon: Icon(_icons[index]),
                      label: _labels[index],
                    ),
                  ),
                ),
        );
      },
    );
  }

  String get _name => (profile['full_name'] as String?) ?? 'Worker';
  bool get _isAdmin => profile['role'] == 'admin';

  Widget _sideBar(BuildContext context) => Container(
    width: 250,
    padding: const EdgeInsets.fromLTRB(20, 22, 14, 16),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(right: BorderSide(color: context.appBorder)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Brand(),
        const SizedBox(height: 35),
        Text(
          'WORKSPACE',
          style: TextStyle(
            color: context.appMuted,
            fontSize: 11,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        ..._labels
            .asMap()
            .entries
            .where((entry) => entry.key != 4 || _isAdmin)
            .map((entry) {
              final index = entry.key;
              final selected = index == selectedIndex;
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: ListTile(
                  dense: true,
                  selected: selected,
                  selectedTileColor: context.appSoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: Icon(
                    _icons[index],
                    color: selected ? context.appBrand : context.appMuted,
                    size: 21,
                  ),
                  title: Text(
                    _labels[index],
                    style: TextStyle(
                      color: selected ? context.appBrand : context.appInk,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                  onTap: () => onNavigate(index),
                ),
              );
            }),
        const Spacer(),
        const Divider(),
        ListTile(
          dense: true,
          leading: Icon(Icons.logout, color: context.appMuted),
          title: const Text('Log out'),
          onTap: () => _logout(context),
        ),
      ],
    ),
  );

  Future<void> _postJob(BuildContext context) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _PostJobDialog(api: api),
    );
    if (created != true || !context.mounted) return;
    onJobCreated();
    onNavigate(2);
    _snack(context, 'Your job has been posted and is now visible to everyone.');
  }

  Widget _page(BuildContext context) {
    switch (selectedIndex) {
      case 1:
        return _browsePage(context);
      case 2:
        return _jobsPage(context);
      case 3:
        return _paymentsPage(context);
      case 4:
        return _isAdmin ? _adminPage(context) : _overviewPage(context);
      default:
        return _overviewPage(context);
    }
  }

  Widget _overviewPage(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _pageHeading(
        context,
        'Good morning, ${_name.split(' ').first}',
        'Your work and opportunities, all in one place.',
      ),
      const SizedBox(height: 22),
      _profileCard(context),
      const SizedBox(height: 18),
      _statsRow(context),
      const SizedBox(height: 20),
      LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 760) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _quickActions(context)),
                const SizedBox(width: 18),
                Expanded(flex: 2, child: _feedbackCard(context)),
              ],
            );
          }
          return Column(
            children: [
              _quickActions(context),
              const SizedBox(height: 16),
              _feedbackCard(context),
            ],
          );
        },
      ),
      const SizedBox(height: 18),
      _subscriptionCard(context),
      const SizedBox(height: 28),
      Align(
        alignment: Alignment.center,
        child: OutlinedButton.icon(
          onPressed: () => _editProfile(context),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Edit profile'),
        ),
      ),
    ],
  );

  Widget _profileCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: context.appSoft,
            child: Text(
              _initials(_name),
              style: TextStyle(
                fontSize: 20,
                color: context.appBrand,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      _name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.appInk,
                      ),
                    ),
                    if (profile['verification_status'] == 'approved')
                      Icon(
                        Icons.verified,
                        size: 18,
                        color: Theme.of(context).colorScheme.secondary,
                      )
                    else
                      _tag(context, 'Verification pending'),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${profile['headline'] ?? 'Add your skills and experience'}',
                  style: TextStyle(color: context.appMuted),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: context.appMuted,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${profile['location'] ?? 'Add location'}',
                      style: TextStyle(color: context.appMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _skills
                      .map((skill) => _tag(context, skill))
                      .toList(),
                ),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width > 600)
            IconButton(
              onPressed: () => _editProfile(context),
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit profile',
            ),
        ],
      ),
    ),
  );

  List<String> get _skills => ((profile['skills'] as String?) ?? '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Widget _statsRow(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = constraints.maxWidth > 900 ? 4 : 2;
      return GridView.count(
        crossAxisCount: count,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: constraints.maxWidth > 900 ? 1.8 : 1.55,
        children: [
          _StatCard(
            icon: Icons.task_alt,
            value: '${profile['completed_jobs'] ?? 0}',
            label: 'Jobs completed',
          ),
          _StatCard(
            icon: Icons.star_rounded,
            value: '—',
            label: 'Average rating',
          ),
          _StatCard(
            icon: Icons.thumb_up_alt_outlined,
            value: '0',
            label: 'Positive reviews',
          ),
          _StatCard(
            icon: Icons.workspace_premium_outlined,
            value: '${profile['completed_jobs'] ?? 0}',
            label: 'Experience marks',
          ),
        ],
      );
    },
  );

  Widget _quickActions(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your workspace',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.appInk,
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _actionButton(
                context,
                'View offers',
                Icons.mark_email_unread_outlined,
                () => onNavigate(2),
              ),
              _actionButton(
                context,
                'Find work',
                Icons.search,
                () => onNavigate(1),
              ),
              _actionButton(
                context,
                'Post a job',
                Icons.add_business_outlined,
                () => _postJob(context),
              ),
              _actionButton(
                context,
                'My hires',
                Icons.groups_outlined,
                () => onNavigate(2),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _feedbackCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Feedback',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.appInk,
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(
                child: _RatingColumn(
                  title: 'Received',
                  rating: '—',
                  count: '0 reviews',
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _RatingColumn(
                  title: 'Given',
                  rating: '—',
                  count: '0 reviews',
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Text(
            'Feedback from completed jobs will appear here.',
            style: TextStyle(
              color: context.appMuted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _subscriptionCard(BuildContext context) => Card(
    color: context.appSoft,
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 14,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grow your reach',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: context.appInk,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'Monthly subscription · UGX 4,000 / month',
                style: TextStyle(color: context.appMuted),
              ),
              SizedBox(height: 8),
              Text(
                '✓ Browse verified workers    ✓ Unlock contacts    ✓ Post opportunities',
                style: TextStyle(color: context.appBrand, fontSize: 12),
              ),
            ],
          ),
          FilledButton(
            onPressed: () => _pay(context, purpose: 'subscription'),
            child: const Text('Subscribe now'),
          ),
        ],
      ),
    ),
  );

  Widget _browsePage(BuildContext context) => _WorkerDirectory(
    api: api,
    onUnlock: (id, name) => _unlock(context, id, name),
  );

  Widget _jobsPage(BuildContext context) => _JobWorkspace(
    key: ValueKey(jobsRevision),
    api: api,
    onPostJob: () => _postJob(context),
  );

  Widget _paymentsPage(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _pageHeading(
        context,
        'Payments & access',
        'Manage your subscription and contact unlocks.',
      ),
      const SizedBox(height: 22),
      _subscriptionCard(context),
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Unlock a worker contact',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter a worker ID to request their contact details. UGX 500 per contact.',
                style: TextStyle(color: context.appMuted),
              ),
              const SizedBox(height: 14),
              _UnlockForm(
                onSubmit: (id) =>
                    _pay(context, purpose: 'contact_unlock', workerId: id),
              ),
              const SizedBox(height: 20),
              const Text(
                'Available payment methods',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              const Wrap(
                spacing: 9,
                children: [
                  _PaymentMethod(icon: Icons.phone_android, label: 'MTN MoMo'),
                  _PaymentMethod(
                    icon: Icons.phone_iphone,
                    label: 'Airtel Money',
                  ),
                  _PaymentMethod(
                    icon: Icons.credit_card,
                    label: 'Visa / Mastercard',
                  ),
                  _PaymentMethod(icon: Icons.paypal, label: 'PayPal'),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      Card(
        child: ListTile(
          leading: Icon(Icons.receipt_long_outlined, color: context.appBrand),
          title: const Text('Payment history'),
          subtitle: const Text(
            'Your transactions will appear here after API activation.',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _snack(context, 'No completed payments yet.'),
        ),
      ),
    ],
  );

  Widget _adminPage(BuildContext context) => _AdminDashboard(api: api);

  Widget _pageHeading(BuildContext context, String title, String subtitle) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              color: context.appInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(subtitle, style: TextStyle(color: context.appMuted)),
        ],
      );

  Widget _actionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 18),
    label: Text(label),
  );

  Widget _tag(BuildContext context, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: context.appSoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(text, style: TextStyle(color: context.appBrand, fontSize: 11)),
  );

  Future<void> _editProfile(BuildContext context) async {
    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ProfileDialog(profile: profile),
    );
    if (updated == null) return;
    try {
      final result = await api.updateProfile(updated);
      final saved = result['profile'];
      if (saved is Map<String, dynamic>) {
        onProfileChanged({...profile, ...saved});
      }
      if (context.mounted) _snack(context, 'Profile updated.');
    } on ApiException catch (error) {
      if (context.mounted) _snack(context, error.message);
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await api.logout();
      onLogout();
    } on ApiException catch (error) {
      onLogout();
      if (context.mounted) {
        _snack(
          context,
          'Signed out here, but could not revoke the server session: ${error.message}',
        );
      }
    }
  }

  Future<void> _unlock(
    BuildContext context,
    String workerId,
    String name,
  ) async {
    final phone = await _phoneDialog(context);
    if (phone == null || !context.mounted) return;
    await _pay(
      context,
      purpose: 'contact_unlock',
      workerId: workerId,
      phone: phone,
    );
  }

  Future<void> _pay(
    BuildContext context, {
    required String purpose,
    String? workerId,
    String? phone,
  }) async {
    final targetPhone = phone ?? await _phoneDialog(context);
    if (targetPhone == null) return;
    try {
      final response = await api.startPayment(
        purpose: purpose,
        phone: targetPhone,
        workerId: workerId,
      );
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => _PaymentStatusDialog(
            api: api,
            reference: response['reference'] as String? ?? '',
            message: response['message'] as String? ?? 'Payment request sent.',
          ),
        );
      }
    } on ApiException catch (error) {
      if (context.mounted) _snack(context, error.message);
    }
  }
}

class _PaymentStatusDialog extends StatefulWidget {
  const _PaymentStatusDialog({
    required this.api,
    required this.reference,
    required this.message,
  });

  final PlatformApi api;
  final String reference;
  final String message;

  @override
  State<_PaymentStatusDialog> createState() => _PaymentStatusDialogState();
}

class _PaymentStatusDialogState extends State<_PaymentStatusDialog> {
  bool _checking = false;
  String? _status;
  String? _contact;
  String? _error;

  Future<void> _checkStatus() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final result = await widget.api.paymentStatus(widget.reference);
      if (!mounted) return;
      setState(() {
        _status = result['status'] as String?;
        _contact = result['contact'] as String?;
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Confirm your payment'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.message),
        const SizedBox(height: 12),
        Text(
          'Reference: ${widget.reference}',
          style: TextStyle(fontSize: 12, color: context.appMuted),
        ),
        if (_status != null) ...[
          const SizedBox(height: 12),
          Text(
            'Payment status: ${_status!.toUpperCase()}',
            style: TextStyle(
              color: _status == 'successful'
                  ? context.appBrand
                  : context.appMuted,
            ),
          ),
        ],
        if (_contact != null) ...[
          const SizedBox(height: 8),
          Text(
            'Worker contact: $_contact',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton(
        onPressed: _checking ? null : _checkStatus,
        child: _checking
            ? SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              )
            : const Text('Check payment status'),
      ),
    ],
  );
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.profile});
  final Map<String, dynamic> profile;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late final _name = TextEditingController(
    text: widget.profile['full_name'] as String?,
  );
  late final _location = TextEditingController(
    text: widget.profile['location'] as String?,
  );
  late final _headline = TextEditingController(
    text: widget.profile['headline'] as String?,
  );
  late final _skills = TextEditingController(
    text: widget.profile['skills'] as String?,
  );

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _headline.dispose();
    _skills.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit your profile'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _headline,
              decoration: const InputDecoration(
                labelText: 'Headline / experience',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _skills,
              decoration: const InputDecoration(
                labelText: 'Skills (comma separated)',
              ),
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
        onPressed: () => Navigator.pop(context, {
          'full_name': _name.text.trim(),
          'location': _location.text.trim(),
          'headline': _headline.text.trim(),
          'skills': _skills.text.trim(),
        }),
        child: const Text('Save changes'),
      ),
    ],
  );
}

class _PostJobDialog extends StatefulWidget {
  const _PostJobDialog({required this.api});

  final PlatformApi api;

  @override
  State<_PostJobDialog> createState() => _PostJobDialogState();
}

class _PostJobDialogState extends State<_PostJobDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _skill = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  final _budget = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _skill.dispose();
    _location.dispose();
    _description.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final budgetText = _budget.text.trim();
    final budget = budgetText.isEmpty ? null : int.tryParse(budgetText);
    if (budgetText.isNotEmpty && budget == null) {
      setState(() => _error = 'Enter the budget as a whole number of UGX.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.createJob(
        title: _title.text.trim(),
        skill: _skill.text.trim(),
        location: _location.text.trim(),
        description: _description.text.trim(),
        budgetUgx: budget,
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value, String label, int maxLength) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label is required.';
    if (text.length > maxLength) {
      return '$label must be $maxLength characters or fewer.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Post a job'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                key: const ValueKey('job-title'),
                controller: _title,
                maxLength: 180,
                decoration: const InputDecoration(
                  labelText: 'Job title',
                  hintText: 'e.g. Install solar panels at my home',
                  counterText: '',
                ),
                validator: (value) => _required(value, 'Job title', 180),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('job-skill'),
                controller: _skill,
                maxLength: 120,
                decoration: const InputDecoration(
                  labelText: 'Skill needed',
                  hintText: 'e.g. Solar installation',
                  counterText: '',
                ),
                validator: (value) => _required(value, 'Skill needed', 120),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('job-location'),
                controller: _location,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Location',
                  hintText: 'Town, district, or region',
                  counterText: '',
                ),
                validator: (value) => _required(value, 'Location', 160),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('job-description'),
                controller: _description,
                maxLength: 5000,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Describe the work',
                  hintText:
                      'Explain what needs to be done and any useful details.',
                  alignLabelWithHint: true,
                  counterText: '',
                ),
                validator: (value) => _required(value, 'Job description', 5000),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('job-budget'),
                controller: _budget,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Budget in UGX (optional)',
                  hintText: 'e.g. 150000',
                  prefixText: 'UGX ',
                ),
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final amount = int.tryParse(text);
                  if (amount == null || amount < 1 || amount > 2000000000) {
                    return 'Enter a whole UGX amount up to 2,000,000,000.';
                  }
                  return null;
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _submit,
        child: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Publish job'),
      ),
    ],
  );
}

class _JobWorkspace extends StatefulWidget {
  const _JobWorkspace({required this.api, required this.onPostJob, super.key});

  final PlatformApi api;
  final VoidCallback onPostJob;

  @override
  State<_JobWorkspace> createState() => _JobWorkspaceState();
}

class _JobWorkspaceState extends State<_JobWorkspace> {
  bool _showMine = true;
  late Future<Map<String, dynamic>> _jobs;

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  void _loadJobs() {
    _jobs = widget.api.jobs(mine: _showMine);
  }

  void _selectTab(bool showMine) {
    if (_showMine == showMine) return;
    setState(() {
      _showMine = showMine;
      _loadJobs();
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jobs & hires',
                  style: TextStyle(
                    fontSize: 26,
                    color: context.appInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Post opportunities or browse jobs shared by the community.',
                  style: TextStyle(color: context.appMuted),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: widget.onPostJob,
            icon: const Icon(Icons.add),
            label: const Text('Post a job'),
          ),
        ],
      ),
      const SizedBox(height: 20),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('My posts')),
          ButtonSegment(value: false, label: Text('Open jobs')),
        ],
        selected: {_showMine},
        onSelectionChanged: (selection) => _selectTab(selection.first),
      ),
      const SizedBox(height: 16),
      FutureBuilder<Map<String, dynamic>>(
        future: _jobs,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasError) {
            return _messageCard(
              context,
              'Could not load jobs',
              snapshot.error.toString(),
            );
          }
          final jobs = snapshot.data?['jobs'] as List<dynamic>? ?? [];
          if (jobs.isEmpty) {
            return _messageCard(
              context,
              _showMine ? 'You have not posted a job yet' : 'No open jobs yet',
              _showMine
                  ? 'Share an opportunity with the community. Anyone with an account can post a job.'
                  : 'Open jobs posted by the community will appear here.',
            );
          }
          return Column(
            children: jobs.map((item) {
              final job = item as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _JobCard(job: job, mine: _showMine),
              );
            }).toList(),
          );
        },
      ),
      const SizedBox(height: 16),
      Text(
        'Experience marks',
        style: TextStyle(
          color: context.appInk,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
      const Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Badge(icon: Icons.electric_bolt, label: 'Skilled craft'),
          _Badge(icon: Icons.handshake_outlined, label: 'Trusted worker'),
          _Badge(icon: Icons.star, label: 'Top rated'),
        ],
      ),
    ],
  );
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job, required this.mine});

  final Map<String, dynamic> job;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final budget = job['budget_ugx'];
    final details = <String>[
      '${job['skill']}',
      '${job['location']}',
      if (budget != null) 'UGX $budget',
      if (mine) '${job['application_count'] ?? 0} applications',
      if (!mine && job['employer_name'] != null)
        'Posted by ${job['employer_name']}',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${job['title']}',
                    style: TextStyle(
                      color: context.appInk,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: context.appSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${job['status']}',
                    style: TextStyle(
                      color: context.appBrand,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              details.join(' · '),
              style: TextStyle(color: context.appMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Text(
              '${job['description']}',
              style: TextStyle(color: context.appInk, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkerDirectory extends StatefulWidget {
  const _WorkerDirectory({required this.api, required this.onUnlock});

  final PlatformApi api;
  final Future<void> Function(String workerId, String name) onUnlock;

  @override
  State<_WorkerDirectory> createState() => _WorkerDirectoryState();
}

class _WorkerDirectoryState extends State<_WorkerDirectory> {
  final _search = TextEditingController();
  late Future<Map<String, dynamic>> _workers;

  @override
  void initState() {
    super.initState();
    _workers = widget.api.workers();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _runSearch() {
    setState(() => _workers = widget.api.workers(query: _search.text.trim()));
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Find trusted people',
        style: TextStyle(
          fontSize: 26,
          color: context.appInk,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        'Explore verified profiles by skill, name, or location.',
        style: TextStyle(color: context.appMuted),
      ),
      const SizedBox(height: 22),
      TextField(
        controller: _search,
        onSubmitted: (_) => _runSearch(),
        decoration: InputDecoration(
          hintText: 'Try “electrician” or “Kampala”',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: IconButton(
            onPressed: _runSearch,
            icon: const Icon(Icons.arrow_forward),
          ),
        ),
      ),
      const SizedBox(height: 18),
      FutureBuilder<Map<String, dynamic>>(
        future: _workers,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasError) {
            return _messageCard(
              context,
              'Could not load profiles',
              snapshot.error.toString(),
            );
          }
          final profiles = (snapshot.data?['workers'] as List<dynamic>?) ?? [];
          if (profiles.isEmpty) {
            return _messageCard(
              context,
              'No verified profiles found',
              'Try another search, or check back when more workers are verified.',
            );
          }
          return Column(
            children: profiles.map((item) {
              final worker = item as Map<String, dynamic>;
              final name = worker['full_name'] as String? ?? 'Worker';
              final workerId = worker['public_id'] as String? ?? '';
              final rating = double.tryParse('${worker['rating']}') ?? 0;
              final reviewCount = worker['review_count']?.toString() ?? '0';
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: context.appSoft,
                          child: Text(
                            _initials(name),
                            style: TextStyle(color: context.appBrand),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Icon(
                                    Icons.verified,
                                    size: 17,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.secondary,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${worker['headline'] ?? ''} · ${worker['location'] ?? ''}\n${worker['skills'] ?? ''}\n${rating == 0 ? 'No reviews yet' : '★ ${rating.toStringAsFixed(1)} · $reviewCount reviews'} · ${worker['completed_jobs'] ?? 0} jobs',
                                style: TextStyle(
                                  color: context.appMuted,
                                  height: 1.5,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Worker ID: $workerId',
                                style: TextStyle(
                                  color: context.appMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () => widget.onUnlock(workerId, name),
                          child: const Text('Unlock · 500'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    ],
  );
}

class _AdminDashboard extends StatefulWidget {
  const _AdminDashboard({required this.api});
  final PlatformApi api;

  @override
  State<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<_AdminDashboard> {
  late Future<Map<String, dynamic>> _summary;
  late Future<Map<String, dynamic>> _verifications;
  late Future<Map<String, dynamic>> _disputes;
  late Future<Map<String, dynamic>> _payments;
  final _paymentsKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _summary = widget.api.adminSummary();
    _verifications = widget.api.pendingVerifications();
    _disputes = widget.api.adminDisputes();
    _payments = widget.api.adminPayments();
  }

  Future<void> _review(String workerId, String decision) async {
    try {
      await widget.api.reviewVerification(workerId, decision);
      if (!mounted) return;
      setState(_reload);
      _snack(context, 'Worker profile $decision.');
    } on ApiException catch (error) {
      if (mounted) _snack(context, error.message);
    }
  }

  Future<void> _resolve(Map<String, dynamic> dispute) async {
    final controller = TextEditingController();
    final decision = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Resolve dispute #${dispute['id']}'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Resolution details'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'dismissed'),
            child: const Text('Dismiss'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'resolved'),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
    final resolution = controller.text.trim();
    controller.dispose();
    if (decision == null || resolution.isEmpty) return;
    try {
      await widget.api.resolveDispute('${dispute['id']}', decision, resolution);
      if (!mounted) return;
      setState(_reload);
      _snack(context, 'Dispute $decision.');
    } on ApiException catch (error) {
      if (mounted) _snack(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Admin overview',
        style: TextStyle(
          fontSize: 26,
          color: context.appInk,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 5),
      Text(
        'Verification, disputes, and live platform health.',
        style: TextStyle(color: context.appMuted),
      ),
      const SizedBox(height: 22),
      FutureBuilder<Map<String, dynamic>>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _messageCard(
              context,
              'Admin summary unavailable',
              snapshot.error.toString(),
            );
          }
          final summary =
              snapshot.data?['summary'] as Map<String, dynamic>? ?? {};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _AdminMetric(
                    title: 'Active users',
                    value: '${summary['active_users'] ?? 0}',
                    icon: Icons.people_alt_outlined,
                  ),
                  _AdminMetric(
                    title: 'Verified profiles',
                    value: '${summary['verified_profiles'] ?? 0}',
                    icon: Icons.verified_user_outlined,
                  ),
                  _AdminMetric(
                    title: 'Active subscriptions',
                    value: '${summary['active_subscriptions'] ?? 0}',
                    icon: Icons.autorenew,
                  ),
                  _AdminMetric(
                    title: 'Payments processed',
                    value: 'UGX ${summary['payments_total_ugx'] ?? 0}',
                    icon: Icons.payments_outlined,
                  ),
                  _AdminMetric(
                    title: 'Transactions',
                    value: '${summary['payments_processed'] ?? 0}',
                    icon: Icons.receipt_long_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'System health',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const _HealthRow(label: 'Database connection', ok: true),
                      _HealthRow(
                        label: 'MTN Mobile Money',
                        ok: summary['mtn_configured'] == true,
                      ),
                      _HealthRow(
                        label: 'Pending verifications',
                        ok:
                            summary['pending_verifications'] == 0 ||
                            summary['pending_verifications'] == '0',
                        detail:
                            '${summary['pending_verifications'] ?? 0} awaiting review',
                      ),
                      _HealthRow(
                        label: 'Open disputes',
                        ok:
                            summary['open_disputes'] == 0 ||
                            summary['open_disputes'] == '0',
                        detail: '${summary['open_disputes'] ?? 0} active',
                      ),
                      const Divider(height: 24),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              final target = _paymentsKey.currentContext;
                              if (target != null) {
                                Scrollable.ensureVisible(
                                  target,
                                  duration: const Duration(milliseconds: 250),
                                );
                              }
                            },
                            child: const Text('Manage payments'),
                          ),
                          OutlinedButton(
                            onPressed: () => _info(
                              context,
                              'Active users: ${summary['active_users'] ?? 0}\nVerified profiles: ${summary['verified_profiles'] ?? 0}\nActive subscriptions: ${summary['active_subscriptions'] ?? 0}\nSuccessful transactions: ${summary['payments_processed'] ?? 0}\nTotal processed: UGX ${summary['payments_total_ugx'] ?? 0}',
                            ),
                            child: const Text('View report'),
                          ),
                          OutlinedButton(
                            onPressed: () => _info(
                              context,
                              'For security, create an account first and promote it to administrator directly in MySQL. See the Admin setup section in README.md.',
                            ),
                            child: const Text('Add admin'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 18),
      _verificationCard(),
      const SizedBox(height: 18),
      _disputeCard(),
      const SizedBox(height: 18),
      _paymentCard(),
      const SizedBox(height: 18),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'System summary',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
              SizedBox(height: 8),
              Text(
                'Monthly analytics charts are not available yet.',
                style: TextStyle(color: context.appMuted),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _verificationCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verification queue',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 10),
          FutureBuilder<Map<String, dynamic>>(
            future: _verifications,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.red),
                );
              }
              final items =
                  snapshot.data?['verifications'] as List<dynamic>? ?? [];
              if (items.isEmpty) {
                return Text(
                  'No profiles are waiting for verification.',
                  style: TextStyle(color: context.appMuted),
                );
              }
              return Column(
                children: items.map((item) {
                  final profile = item as Map<String, dynamic>;
                  final workerId = profile['public_id'] as String? ?? '';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${profile['full_name']} · $workerId'),
                    subtitle: Text(
                      '${profile['phone']} · ${profile['location'] ?? ''}\n${profile['skills'] ?? profile['headline'] ?? ''}',
                    ),
                    isThreeLine: true,
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          tooltip: 'Approve',
                          onPressed: () => _review(workerId, 'approved'),
                          icon: Icon(
                            Icons.check_circle_outline,
                            color: context.appBrand,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Reject',
                          onPressed: () => _review(workerId, 'rejected'),
                          icon: const Icon(
                            Icons.cancel_outlined,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _disputeCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dispute management',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 10),
          FutureBuilder<Map<String, dynamic>>(
            future: _disputes,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.red),
                );
              }
              final items = snapshot.data?['disputes'] as List<dynamic>? ?? [];
              if (items.isEmpty) {
                return Text(
                  'No dispute cases have been reported.',
                  style: TextStyle(color: context.appMuted),
                );
              }
              return Column(
                children: items.map((item) {
                  final dispute = item as Map<String, dynamic>;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      '${dispute['job_title']} · ${dispute['status']}',
                    ),
                    subtitle: Text(
                      '${dispute['opened_by']} vs ${dispute['against_user']}',
                    ),
                    trailing: TextButton(
                      onPressed: () => _resolve(dispute),
                      child: const Text('View / resolve'),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    ),
  );

  Widget _paymentCard() => Card(
    key: _paymentsKey,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent payments',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 10),
          FutureBuilder<Map<String, dynamic>>(
            future: _payments,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: Colors.red),
                );
              }
              final items = snapshot.data?['payments'] as List<dynamic>? ?? [];
              if (items.isEmpty) {
                return Text(
                  'No payments have been recorded.',
                  style: TextStyle(color: context.appMuted),
                );
              }
              return Column(
                children: items.map((item) {
                  final payment = item as Map<String, dynamic>;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.receipt_long_outlined,
                      color: context.appBrand,
                    ),
                    title: Text(
                      '${payment['customer_name']} · UGX ${payment['amount_ugx']}',
                    ),
                    subtitle: Text(
                      '${payment['purpose']} · ${payment['provider']} · ${payment['provider_reference']}',
                    ),
                    trailing: Text('${payment['status']}'),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    ),
  );
}

Widget _messageCard(BuildContext context, String title, String message) => Card(
  child: Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(message, style: TextStyle(color: context.appMuted)),
      ],
    ),
  ),
);

class _UnlockForm extends StatefulWidget {
  const _UnlockForm({required this.onSubmit});
  final ValueChanged<String> onSubmit;

  @override
  State<_UnlockForm> createState() => _UnlockFormState();
}

class _UnlockFormState extends State<_UnlockForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Worker ID',
            hintText: 'e.g. 1042',
          ),
        ),
      ),
      const SizedBox(width: 10),
      FilledButton(
        onPressed: () {
          if (_controller.text.trim().isEmpty) {
            _snack(context, 'Enter a worker ID first.');
          } else {
            widget.onSubmit(_controller.text.trim());
          }
        },
        child: const Text('Unlock · UGX 500'),
      ),
    ],
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: context.appBrand),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: context.appInk,
            ),
          ),
          Text(label, style: TextStyle(color: context.appMuted, fontSize: 11)),
        ],
      ),
    ),
  );
}

class _RatingColumn extends StatelessWidget {
  const _RatingColumn({
    required this.title,
    required this.rating,
    required this.count,
  });
  final String title;
  final String rating;
  final String count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.appSoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: context.appMuted, fontSize: 12)),
        const SizedBox(height: 5),
        Text(
          '★ $rating',
          style: TextStyle(
            color: context.appBrand,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        Text(count, style: TextStyle(color: context.appMuted, fontSize: 10)),
      ],
    ),
  );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 16, color: context.appBrand),
    label: Text(label),
    backgroundColor: Theme.of(context).colorScheme.surface,
    side: BorderSide(color: context.appBorder),
  );
}

class _AdminMetric extends StatelessWidget {
  const _AdminMetric({
    required this.title,
    required this.value,
    required this.icon,
  });
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 235,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: context.appBrand),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
            ),
            Text(
              title,
              style: TextStyle(color: context.appMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({required this.label, required this.ok, this.detail});
  final String label;
  final bool ok;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.error_outline,
          size: 18,
          color: ok ? context.appBrand : _warning(context),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        if (detail != null)
          Text(
            detail!,
            style: TextStyle(color: context.appMuted, fontSize: 12),
          ),
        Text(
          ok ? 'Connected' : 'Needs setup',
          style: TextStyle(
            color: ok ? context.appBrand : _warning(context),
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class _PaymentMethod extends StatelessWidget {
  const _PaymentMethod({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 16, color: context.appBrand),
    label: Text(label, style: const TextStyle(fontSize: 11)),
    backgroundColor: context.appSoft,
    side: BorderSide.none,
  );
}

class Brand extends StatelessWidget {
  const Brand({this.compact = false, super.key});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: compact ? 30 : 38,
        height: compact ? 30 : 38,
        decoration: BoxDecoration(
          color: const Color(0xFF155C45),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(Icons.public, color: Colors.white, size: compact ? 18 : 23),
      ),
      const SizedBox(width: 10),
      Text(
        'Gronlure',
        style: TextStyle(
          color: context.appBrand,
          fontWeight: FontWeight.w800,
          fontSize: 21,
          letterSpacing: -0.5,
        ),
      ),
    ],
  );
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.isDark, required this.onToggle});

  final bool isDark;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
    onPressed: onToggle,
    icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
  );
}

Color _warning(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? const Color(0xFFFFD180)
    : const Color(0xFF8A5700);

String _initials(String name) => name
    .trim()
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0].toUpperCase())
    .join();

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void _info(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<String?> _phoneDialog(BuildContext context) async {
  final controller = TextEditingController();
  final phone = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('MTN Mobile Money'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(
          labelText: 'Payment phone number',
          hintText: '+256 7XX XXX XXX',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  controller.dispose();
  if (phone == null || phone.isEmpty) return null;
  return phone;
}
