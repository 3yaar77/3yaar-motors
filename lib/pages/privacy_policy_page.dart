import 'package:flutter/material.dart';
import 'package:autoreel/theme.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Privacy Policy', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 24),
        child: DefaultTextStyle.merge(
          style: context.textStyles.bodyMedium?.copyWith(height: 1.5, color: cs.onSurface),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('We respect your privacy and are committed to protecting your personal data.'),
            SizedBox(height: 12),
            Text('Data Collection'),
            SizedBox(height: 6),
            Text('We collect information you provide and usage data to improve the service.'),
            SizedBox(height: 12),
            Text('Data Usage'),
            SizedBox(height: 6),
            Text('We use your data to operate the app, provide features, and communicate with you.'),
            SizedBox(height: 12),
            Text('Contact'),
            SizedBox(height: 6),
            Text('For questions, contact support.'),
          ]),
        ),
      ),
    );
  }
}
