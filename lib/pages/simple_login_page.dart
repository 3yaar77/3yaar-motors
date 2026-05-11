import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:autoreel/nav.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/providers/auth_provider.dart';

class SimpleLoginPage extends StatefulWidget {
  const SimpleLoginPage({super.key});

  @override
  State<SimpleLoginPage> createState() => _SimpleLoginPageState();
}

class _SimpleLoginPageState extends State<SimpleLoginPage> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String? _city;
  bool _isSaving = false;
  int _tabIndex = 0; // 0 = Phone, 1 = Guest (visual only)

  final List<String> _cities = const [
    'Dubai',
    'Abu Dhabi',
    'Sharjah',
    'Ajman',
    'Fujairah',
    'Ras Al Khaimah',
    'Umm Al Quwain',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    // This simple page is deprecated in favor of username login.
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: AppSpacing.xl),
                Text('Login', style: context.textStyles.displaySmall?.copyWith(color: scheme.onSurface, fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.xs),
                Text('Welcome back, enter your details', style: context.textStyles.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.xl),
                _LoginCard(
                  tabIndex: _tabIndex,
                  onTabChanged: (i) {
                    if (i == 1) {
                      // Guest is visual only for now; do nothing
                      return;
                    }
                    setState(() => _tabIndex = i);
                  },
                  nameCtrl: _nameCtrl,
                  phoneCtrl: _phoneCtrl,
                  city: _city,
                  cities: _cities,
                  onCityChanged: (v) => setState(() => _city = v),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _onContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MarketplaceColors.accentYellow,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black)))
                        : Text('Continue', style: context.textStyles.titleMedium?.bold.withColor(Colors.black)),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('By continuing, you agree to our Terms & Privacy Policy', style: context.textStyles.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.xl),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  final int tabIndex;
  final ValueChanged<int> onTabChanged;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final String? city;
  final List<String> cities;
  final ValueChanged<String?> onCityChanged;

  const _LoginCard({
    required this.tabIndex,
    required this.onTabChanged,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.city,
    required this.cities,
    required this.onCityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.15), width: 1),
      ),
      padding: AppSpacing.paddingLg,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Tabs(tabIndex: tabIndex, onChanged: onTabChanged),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: nameCtrl,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Name',
            hintText: 'John Doe',
            filled: true,
            fillColor: scheme.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'Phone number',
            hintText: '05XXXXXXXX',
            filled: true,
            fillColor: scheme.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          value: city?.isNotEmpty == true ? city : null,
          items: cities.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
          onChanged: onCityChanged,
          decoration: InputDecoration(
            labelText: 'City (optional)',
            filled: true,
            fillColor: scheme.surfaceContainerHighest,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
          ),
        ),
      ]),
    );
  }
}

class _Tabs extends StatelessWidget {
  final int tabIndex;
  final ValueChanged<int> onChanged;
  const _Tabs({required this.tabIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(children: [
        Expanded(
          child: _Segment(
            label: 'Phone',
            selected: tabIndex == 0,
            onTap: () => onChanged(0),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _Segment(
            label: 'Guest',
            selected: tabIndex == 1,
            onTap: () => onChanged(1),
          ),
        ),
      ]),
    );
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Segment({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? Colors.black.withValues(alpha: 0.1) : Colors.transparent, width: 1),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.black : Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
