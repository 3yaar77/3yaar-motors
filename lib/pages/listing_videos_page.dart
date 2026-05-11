import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:autoreel/providers/listings_provider.dart';
import 'package:autoreel/pages/reels_page.dart' show ReelsVideoPlayer; // reuse the existing full-screen video player
import 'package:go_router/go_router.dart';
import 'package:autoreel/nav.dart';

class ListingVideosPage extends StatefulWidget {
  const ListingVideosPage({super.key});

  @override
  State<ListingVideosPage> createState() => _ListingVideosPageState();
}

class _ListingVideosPageState extends State<ListingVideosPage> {
  final PageController _pageController = PageController();
  int _activeIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listings = context.watch<ListingsProvider>().listings.where((l) => (l.video?.trim().isNotEmpty ?? false)).toList();

    if (listings.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: SafeArea(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.ondemand_video, color: Colors.white70, size: 64),
              const SizedBox(height: 12),
              const Text('No listing videos yet', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('Add video to your car listings to see them here', style: TextStyle(color: Colors.white70)),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(children: [
        MediaQuery.removePadding(
          context: context,
          removeTop: true,
          removeBottom: true,
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: listings.length,
            onPageChanged: (i) => setState(() => _activeIndex = i),
            itemBuilder: (context, index) {
              final item = listings[index];
              return Stack(children: [
                Positioned.fill(
                  child: ReelsVideoPlayer(url: item.video!.trim(), isActive: index == _activeIndex),
                ),
                // Bottom gradient overlay for readability
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.0),
                            Colors.black.withValues(alpha: 0.6),
                            Colors.black.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Info overlay
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 32 + MediaQuery.viewPaddingOf(context).bottom,
                  child: _ListingInfo(
                    title: '${item.make} ${item.model}'.trim(),
                    price: item.price ?? 0,
                    location: item.location,
                    description: item.description,
                  ),
                ),
                // Back button
                Positioned(
                  top: 0,
                  left: 0,
                  child: SafeArea(
                    top: true,
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, top: 8),
                      child: GestureDetector(
                        onTap: () {
                          try {
                            if (GoRouter.of(context).canPop()) {
                              context.pop();
                            } else {
                              context.go(AppRoutes.home);
                            }
                          } catch (e) {
                            context.go(AppRoutes.home);
                          }
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                          child: const Center(child: Icon(Icons.arrow_back_ios, color: Colors.white, size: 18)),
                        ),
                      ),
                    ),
                  ),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

class _ListingInfo extends StatelessWidget {
  final String title;
  final int price;
  final String location;
  final String description;
  const _ListingInfo({required this.title, required this.price, required this.location, required this.description});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(title, style: t.titleLarge?.copyWith(color: Colors.white) ?? const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600), softWrap: true, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 6),
      if (price > 0) Text('AED $price', style: (t.titleMedium ?? const TextStyle()).copyWith(color: Colors.amber, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(location, style: (t.bodyMedium ?? const TextStyle()).copyWith(color: Colors.white.withValues(alpha: 0.8))),
      if (description.trim().isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(description, style: (t.bodySmall ?? const TextStyle()).copyWith(color: Colors.white70), maxLines: 2, overflow: TextOverflow.ellipsis),
      ],
    ]);
  }
}
