import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/nav.dart';
import 'package:autoreel/providers/car_provider.dart';

class BrandsPage extends StatelessWidget {
  const BrandsPage({super.key});

  static const List<String> _brands = [
    'Tesla',
    'BMW',
    'Ferrari',
    'Mercedes',
    'Audi',
    'Lamborghini',
    'Porsche',
    'Range Rover',
    'Nissan',
    'Toyota',
  ];

  String _monogram(String brand) {
    switch (brand) {
      case 'BMW':
        return 'BMW';
      case 'Mercedes':
        return 'MB';
      case 'Range Rover':
        return 'RR';
      case 'Porsche':
        return 'P';
      case 'Ferrari':
        return 'F';
      case 'Lamborghini':
        return 'L';
      case 'Tesla':
        return 'T';
      case 'Audi':
        return 'A';
      case 'Nissan':
        return 'N';
      case 'Toyota':
        return 'T';
      default:
        return brand.isNotEmpty ? brand.characters.first.toUpperCase() : '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 700;
    final crossAxisCount = isWide ? 3 : 2;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('All Brands', style: textTheme.headlineMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 18,
                    childAspectRatio: 0.98,
                  ),
                  itemCount: _brands.length,
                  itemBuilder: (context, index) {
                    final brand = _brands[index];
                    return _BrandGridItem(
                      name: brand,
                      code: _monogram(brand),
                      onTap: () {
                        // Apply filter via provider, then go to Home
                        context.read<CarProvider>().setMakeFilter(brand);
                        context.go(AppRoutes.home);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandGridItem extends StatelessWidget {
  final String name;
  final String code;
  final VoidCallback onTap;
  const _BrandGridItem({required this.name, required this.code, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: MarketplaceColors.luxCard,
              border: Border.all(color: MarketplaceColors.luxBorder, width: 1),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 6)),
              ],
            ),
            child: Center(
              child: Text(
                code,
                style: textTheme.titleLarge?.copyWith(color: MarketplaceColors.accentYellow, fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: textTheme.bodyMedium?.copyWith(color: Colors.white70, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ],
      ),
    );
  }
}
