import 'package:flutter/material.dart';
import 'package:autoreel/theme.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Terms & Conditions', style: context.textStyles.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: cs.onSurface)), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 24),
        child: DefaultTextStyle.merge(
          style: context.textStyles.bodyMedium?.copyWith(height: 1.5, color: cs.onSurface),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Text('Welcome to our marketplace. By using this app you agree to the following terms and conditions.'),
            SizedBox(height: 12),
            Text('1. Listings and Content'),
            SizedBox(height: 6),
            Text('You are responsible for the content you post. Do not upload prohibited content or violate any laws.'),
            SizedBox(height: 12),
            Text('2. Payments and Promotions'),
            SizedBox(height: 6),
            Text('Any purchases or upgrades are subject to applicable fees and are non-refundable unless required by law.'),
            SizedBox(height: 12),
            Text('3. Liability'),
            SizedBox(height: 6),
            Text('We provide the platform as-is and are not liable for user-to-user transactions.'),
          ]),
        ),
      ),
    );
  }
}
