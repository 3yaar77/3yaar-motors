import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/providers/listings_provider.dart';
import 'package:autoreel/pages/feed_page.dart' show CarMapFeaturedGridCard; // reuse existing card styling for map items

class BrandResultsPage extends StatelessWidget {
  final String make;
  const BrandResultsPage({super.key, required this.make});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [MarketplaceColors.luxBgGradientStart, MarketplaceColors.luxBgGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(make, style: textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
            // Debug line for brand + count
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Consumer<ListingsProvider>(builder: (context, lp, _) {
                final data = lp.toMapList();
                final filtered = data.where((e) => (e['type'] == 'car') && ((e['make'] ?? '').toString().trim() == make.trim())).toList();
                return Text('Brand: $make | Count: ${filtered.length}', style: const TextStyle(color: Colors.white70, fontSize: 12));
              }),
            ),
            Expanded(
              child: Consumer<ListingsProvider>(
                builder: (context, lp, _) {
                  final data = lp.toMapList();
                  final qExact = make.trim();
                  final filtered = data.where((e) {
                    final type = (e['type'] ?? '').toString();
                    if (type != 'car') return false;
                    final mk = (e['make'] ?? '').toString().trim();
                    // Exact brand match only
                    return mk == qExact;
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No listings found', style: TextStyle(color: Colors.white70)));
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 380,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => CarMapFeaturedGridCard(item: filtered[index]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
