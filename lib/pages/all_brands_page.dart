import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/data/car_data.dart';

class AllBrandsPage extends StatelessWidget {
  const AllBrandsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;
    final crossAxisCount = isWide ? 4 : 3;
    final brands = getAllBrands(includeOther: false);

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
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 6),
                Text('All Brands', style: textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
              ]),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 18,
                  childAspectRatio: 0.9,
                ),
                itemCount: brands.length,
                itemBuilder: (context, index) {
                  final name = brands[index];
                  return _BrandLogoTile(
                    name: name,
                    onTap: () => context.pushNamed(
                      'brand_results',
                      queryParameters: {
                        'brand': name,
                      },
                    ),
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

class _BrandLogoTile extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _BrandLogoTile({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E1E1E),
            border: Border.all(color: MarketplaceColors.luxBorder, width: 1),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 6))],
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(name, style: textTheme.bodyMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    );
  }
}
