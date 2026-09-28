import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import '../state/convoy_state.dart';
import '../theme/theme.dart';
import '../widgets/loading_overlay.dart';
import 'host_setup_screen.dart';
import 'join_screen.dart';
import 'settings_screen.dart';
import 'expenses_screen.dart';
import 'expense_history_screen.dart';
import 'map_screen.dart';
import '../widgets/add_expense_dialog.dart';
import '../widgets/add_person_dialog.dart';
import '../widgets/complete_expense_dialog.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});
  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<ConvoyState>().token != null) {
        context.read<ConvoyState>().fetchExpenses();
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submitAuth() async {
    final action = _registering ? 'create an account' : 'sign in';
    if (!await ConnectivityService.instance.ensureConnected(context: context, action: action)) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final state = context.read<ConvoyState>();
    try {
      if (_registering) {
        await state.register(_name.text.trim(), _email.text.trim(), _password.text);
      } else {
        await state.login(_email.text.trim(), _password.text);
      }
      state.fetchExpenses();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (!await ConnectivityService.instance.ensureConnected(context: context, action: 'sign in with Google')) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<ConvoyState>().loginWithGoogle();
      if (mounted) {
        context.read<ConvoyState>().fetchExpenses();
      }
    } catch (e) {
      setState(() => _error = 'Google Sign-In: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (!await ConnectivityService.instance.ensureConnected(context: context, action: 'sign in with Apple')) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<ConvoyState>().loginWithApple();
      if (mounted) {
        context.read<ConvoyState>().fetchExpenses();
      }
    } catch (e) {
      setState(() => _error = 'Apple Sign-In: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ConvoyState>();
    final signedIn = state.token != null;

    return Scaffold(
      backgroundColor: ConvoyColors.road,
      body: LoadingOverlay(
        isLoading: _busy,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: signedIn ? _buildDashboard(context, state) : _buildAuth(context),
          ),
        ),
      ),
    );
  }

  /// Minimalistic Authenticated Dashboard
  Widget _buildDashboard(BuildContext context, ConvoyState state) {
    final name = state.userName ?? 'Driver';
    final firstName = name.split(' ').first;
    final initial = firstName.isNotEmpty ? firstName[0].toUpperCase() : 'C';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Sleek Top Navigation Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: ConvoyColors.amber.withAlpha(40),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'CONVOY',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: ConvoyColors.paint,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: ConvoyColors.panel,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ConvoyColors.stroke),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: ConvoyColors.amber.withAlpha(40),
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: ConvoyColors.amber,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        firstName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ConvoyColors.paint,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, size: 20, color: ConvoyColors.muted),
                  tooltip: 'Settings',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // 2. Greeting Header
        Text(
          'Hello, $firstName',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: ConvoyColors.paint,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'One route, every vehicle in sync.',
          style: TextStyle(
            fontSize: 13.5,
            color: ConvoyColors.muted,
          ),
        ),
        const SizedBox(height: 20),

        // 3. Active Convoy Banner (if user has an ongoing session)
        if (state.convoy != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: ConvoyColors.panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ConvoyColors.signal.withAlpha(100)),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: ConvoyColors.signal,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.convoy!.name.isNotEmpty ? state.convoy!.name : 'Active Convoy',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Code: ${state.convoy!.code} • ${state.convoy!.members.length} vehicles',
                        style: const TextStyle(color: ConvoyColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: ConvoyColors.signal,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MapScreen()),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Resume', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],

        // 4. Primary Trip Actions (Host & Join minimal dual cards)
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                context,
                title: 'Host Convoy',
                caption: 'Create route & code',
                icon: Icons.navigation_rounded,
                accentColor: ConvoyColors.amber,
                onTap: () async {
                  if (!await ConnectivityService.instance.ensureConnected(context: context, action: 'host a convoy')) return;
                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HostSetupScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                context,
                title: 'Join Convoy',
                caption: 'Enter trip code',
                icon: Icons.qr_code_scanner_rounded,
                accentColor: const Color(0xFF64B5F6),
                onTap: () async {
                  if (!await ConnectivityService.instance.ensureConnected(context: context, action: 'join a convoy')) return;
                  if (!context.mounted) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const JoinScreen()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // 5. Minimalist Trip Expenses Card
        _buildExpenseSection(context, state),
      ],
    );
  }

  /// Minimalist Action Tile for Host/Join
  Widget _buildActionTile(
    BuildContext context, {
    required String title,
    required String caption,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: ConvoyColors.panel,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ConvoyColors.stroke),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ConvoyColors.paint,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                caption,
                style: const TextStyle(
                  fontSize: 12,
                  color: ConvoyColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Sleek Minimalist Expense Card
  Widget _buildExpenseSection(BuildContext context, ConvoyState state) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ConvoyColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ConvoyColors.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, color: ConvoyColors.amber, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Trip Expenses',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15.5,
                      color: ConvoyColors.paint,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.history_rounded, size: 20, color: ConvoyColors.muted),
                    tooltip: 'History',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ExpenseHistoryScreen()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ExpensesScreen()),
                    ),
                    borderRadius: BorderRadius.circular(4),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Details', style: TextStyle(fontSize: 12.5, color: ConvoyColors.amber, fontWeight: FontWeight.w600)),
                          SizedBox(width: 2),
                          Icon(Icons.chevron_right_rounded, size: 16, color: ConvoyColors.amber),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Numbers Summary
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: ConvoyColors.panel2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ConvoyColors.stroke.withAlpha(25)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL SPENT',
                        style: TextStyle(
                          color: ConvoyColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${state.totalExpenses.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ConvoyColors.paint,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${state.expenses.length} item${state.expenses.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: ConvoyColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 38,
                  color: ConvoyColors.stroke,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SPLIT / PERSON',
                        style: TextStyle(
                          color: ConvoyColors.amber,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${state.splitPerPerson.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: ConvoyColors.amber,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${state.peopleCount} ${state.peopleCount == 1 ? 'person' : 'people'}',
                        style: const TextStyle(color: ConvoyColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action buttons: + Expense & + Person
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => AddExpenseDialog.show(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Expense', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => AddPersonDialog.show(context),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                label: const Text('Add Person', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),

          // Archive / Complete Trip Button (clean subtle outline)
          if (state.expenses.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: ConvoyColors.signal,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: ConvoyColors.signal.withAlpha(50)),
                  ),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 15, color: ConvoyColors.signal),
                label: const Text(
                  'Complete & Archive Trip',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                onPressed: () async {
                  final session = await CompleteExpenseDialog.show(context);
                  if (session != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Archived "${session.name}" to history!'),
                        action: SnackBarAction(
                          label: 'View',
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ExpenseHistoryScreen()),
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Minimalist Clean Auth View
  Widget _buildAuth(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: ConvoyColors.amber.withAlpha(50),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'CONVOY',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: ConvoyColors.paint,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'One route, every car.',
                style: TextStyle(color: ConvoyColors.amber, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        Text(
          _registering ? 'Create your account' : 'Welcome back',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: ConvoyColors.paint),
        ),
        const SizedBox(height: 6),
        Text(
          _registering
              ? 'Join convoys and track roadtrip expenses.'
              : 'Sign in to access your routes and active trips.',
          style: const TextStyle(fontSize: 13, color: ConvoyColors.muted),
        ),
        const SizedBox(height: 20),

        // Social Sign-In Options
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _handleGoogleSignIn,
            icon: const Icon(Icons.g_mobiledata_rounded, size: 28, color: ConvoyColors.paint),
            label: const Text('Continue with Google', style: TextStyle(fontSize: 14)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _handleAppleSignIn,
            icon: const Icon(Icons.apple, size: 20, color: ConvoyColors.paint),
            label: const Text('Continue with Apple', style: TextStyle(fontSize: 14)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
        const SizedBox(height: 18),

        const Row(
          children: [
            Expanded(child: Divider(color: ConvoyColors.stroke)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'OR',
                style: TextStyle(
                  color: ConvoyColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Expanded(child: Divider(color: ConvoyColors.stroke)),
          ],
        ),
        const SizedBox(height: 18),

        if (_registering)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TextField(
              controller: _name,
              decoration: const InputDecoration(
                hintText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded, size: 20, color: ConvoyColors.muted),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'Email address',
              prefixIcon: Icon(Icons.mail_outline_rounded, size: 20, color: ConvoyColors.muted),
            ),
          ),
        ),
        TextField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'Password',
            prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: ConvoyColors.muted),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: ConvoyColors.alert, fontSize: 13)),
        ],
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : _submitAuth,
            child: Text(
              _busy ? 'Please wait…' : (_registering ? 'Create Account' : 'Sign In'),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _registering = !_registering),
            child: Text(
              _registering ? 'Already have an account? Sign In' : 'New to Convoy? Create an account',
              style: const TextStyle(color: ConvoyColors.muted, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
