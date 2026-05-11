import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:autoreel/providers/accessory_provider.dart';
import 'package:autoreel/theme.dart';
import 'package:autoreel/widgets/accessory_grid_card.dart';
import 'package:autoreel/nav.dart';

const List<String> kAccessoryCategories = [
  'All',
  'Wheels & Tires',
  'Screens & Audio',
  'Lights',
  'Interior Parts',
  'Exterior Parts',
  'Cleaning & Care',
  'Performance Parts',
  'Accessories',
  'Other',
];

class AccessoriesPage extends StatefulWidget {
  const AccessoriesPage({super.key});
  @override
  State<AccessoriesPage> createState() => _AccessoriesPageState();
}

class _AccessoriesPageState extends State<AccessoriesPage> {
  String _category = 'All';
  String _condition = 'All';

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AccessoryProvider>();
    final items = p.items;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accessories'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: MarketplaceColors.accentYellow),
            onPressed: () => context.pushNamed('add_accessory_listing'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [MarketplaceColors.luxBgGradientStart, MarketplaceColors.luxBgGradientEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _category,
                  items: kAccessoryCategories
                      .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (v) {
                    setState(() => _category = v ?? 'All');
                    p.setCategoryFilter(_category);
                  },
                  decoration: InputDecoration(
                    labelText: 'Category',
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    labelStyle: const TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: MarketplaceColors.luxItemCard,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _condition,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    DropdownMenuItem(value: 'New', child: Text('New')),
                    DropdownMenuItem(value: 'Used', child: Text('Used')),
                  ],
                  onChanged: (v) {
                    setState(() => _condition = v ?? 'All');
                    p.setConditionFilter(_condition);
                  },
                  decoration: InputDecoration(
                    labelText: 'Condition',
                    filled: true,
                    fillColor: Colors.black.withValues(alpha: 0.15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    labelStyle: const TextStyle(color: Colors.white70),
                  ),
                  dropdownColor: MarketplaceColors.luxItemCard,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ]),
          ),
          Expanded(
            child: p.isLoading
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? const Center(child: Text('No accessories yet', style: TextStyle(color: Colors.white70)))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          mainAxisExtent: 250,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) => AccessoryGridCard(accessory: items[index]),
                      ),
          ),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 60,
          color: Colors.black,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(onPressed: () => context.go(AppRoutes.home), icon: const Icon(Icons.home, color: Colors.white)),
              IconButton(onPressed: () => context.pushNamed('favorites'), icon: const Icon(Icons.favorite_border, color: Colors.white)),
              IconButton(onPressed: () => context.pushNamed('messages'), icon: const Icon(Icons.chat_bubble_outline, color: Colors.white)),
              IconButton(onPressed: () => context.pushNamed('reels'), icon: const Icon(Icons.play_circle_outline, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}
