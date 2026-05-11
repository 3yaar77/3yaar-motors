import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:autoreel/theme.dart';
import 'dart:convert';
import 'package:autoreel/utils/blob_url.dart';
// Removed generic media picker import — reel page is video-only
import 'package:autoreel/utils/pick_video.dart'; // web single-video picker helper
import 'package:autoreel/providers/auth_provider.dart';
import 'package:autoreel/providers/reel_provider.dart';
import 'package:autoreel/nav.dart';
// Removed listings provider and local in-memory listings imports to enforce Firestore-only source
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:autoreel/data/car_data.dart';

class UploadReelPage extends StatefulWidget {
  const UploadReelPage({super.key});

  @override
  State<UploadReelPage> createState() => _UploadReelPageState();
}

class _UploadReelPageState extends State<UploadReelPage> with WidgetsBindingObserver {
  // Media state: single video only
  _PickedMedia? _video; // single video only
  bool _initializing = false;
  bool _publishing = false;
  String _listingType = 'Free listing'; // derived at publish
  bool _upgradeEnabled = false;
  String? _paidPackage; // vip | featured | urgent | topBoost

  VideoPlayerController? _previewController;
  bool _previewReady = false;

  // Reel duration limits
  static const int _minVideoSeconds = 5;
  static const int _maxVideoSeconds = 120;

  int _upgradePriceForType(String t) {
    switch (t) {
      case 'VIP listing':
        return 29;
      case 'Featured listing':
        return 49;
      case 'Urgent listing':
        return 19;
      default:
        return 0;
    }
  }

  // Form fields
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  final _locationCtrl = TextEditingController(text: 'Dubai');
  final _phoneCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final List<String> _conditions = const ['New', 'Used', 'Agency warranty', 'GCC specs'];
  String? _selectedCondition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _titleCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _priceCtrl.dispose();
    _mileageCtrl.dispose();
    _locationCtrl.dispose();
    _phoneCtrl.dispose();
    _descCtrl.dispose();
    // No images on this page
    if (_video?.objectUrl != null && _video!.objectUrl!.isNotEmpty) {
      try { revokeObjectUrl(_video!.objectUrl!); } catch (e) { debugPrint('revoke video url fail: $e'); }
    }
    try { _previewController?.dispose(); } catch (e) { debugPrint('dispose preview controller error: $e'); }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No-op: we don't autoplay previews in simplified flow
  }

  // Removed image picker — this page accepts video only

  // Pick single video (5–120s)
  Future<void> _pickVideo() async {
    if (_initializing) return;
    setState(() => _initializing = true);
    try {
      _PickedMedia? pickedMedia;
      if (kIsWeb) {
        final v = await pickVideoWithWebFilePicker();
        if (v == null) return;
        pickedMedia = _PickedMedia(
          id: UniqueKey().toString(),
          name: v.name,
          isVideo: true,
          objectUrl: v.objectUrl,
          bytes: Uint8List.fromList(v.bytes),
          path: null,
          mimeType: v.mimeType,
        );
        try {
          final c = VideoPlayerController.networkUrl(Uri.parse(pickedMedia.objectUrl!));
          await c.initialize();
          final d = c.value.duration;
          await c.dispose();
          if (d.inSeconds > _maxVideoSeconds) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max video length is 2 minutes')));
            }
            try { revokeObjectUrl(pickedMedia.objectUrl!); } catch (_) {}
            return;
          } else if (d.inSeconds < _minVideoSeconds) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Min video length is 5 seconds')));
            }
            try { revokeObjectUrl(pickedMedia.objectUrl!); } catch (_) {}
            return;
          }
          pickedMedia.duration = d;
        } catch (e) { debugPrint('web duration probe error: $e'); }
      } else {
        try {
          final v = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: Duration(seconds: _maxVideoSeconds));
          if (v == null) return;
          // Read bytes so we can upload via putData on all platforms (avoid dart:io File on web)
          Uint8List? bytes;
          try {
            bytes = await v.readAsBytes();
          } catch (e) {
            debugPrint('read video bytes error: $e');
          }
          pickedMedia = _PickedMedia(
            id: UniqueKey().toString(),
            name: v.name,
            isVideo: true,
            objectUrl: null,
            bytes: bytes,
            path: v.path,
            mimeType: 'video/*',
          );
          try {
            final c = VideoPlayerController.networkUrl(Uri.file(v.path));
            await c.initialize();
            final d = c.value.duration;
            // Validate min/max
            if (d.inSeconds > _maxVideoSeconds) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max video length is 2 minutes')));
              }
              await c.dispose();
              return;
            } else if (d.inSeconds < _minVideoSeconds) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Min video length is 5 seconds')));
              }
              await c.dispose();
              return;
            }
            pickedMedia.duration = d;
            await c.dispose();
          } catch (e) { debugPrint('io duration probe error: $e'); }
        } catch (e) {
          debugPrint('pick video error: $e');
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick video.')));
          return;
        }
      }

      if (pickedMedia != null) {
        // Replace any existing video
        if (_video?.objectUrl != null) {
          try { revokeObjectUrl(_video!.objectUrl!); } catch (_) {}
        }
        setState(() {
          _video = pickedMedia;
          _previewReady = false;
        });
        await _initPreviewControllerForPicked(pickedMedia);
      }
    } catch (e) {
      debugPrint('pick video outer error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick video.')));
    } finally {
      if (mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _initPreviewControllerForPicked(_PickedMedia media) async {
    try { await _previewController?.dispose(); } catch (_) {}
    try {
      if (kIsWeb && (media.objectUrl != null && media.objectUrl!.isNotEmpty)) {
        _previewController = VideoPlayerController.networkUrl(Uri.parse(media.objectUrl!));
      } else if (!kIsWeb && media.path != null && media.path!.isNotEmpty) {
        _previewController = VideoPlayerController.networkUrl(Uri.file(media.path!));
      } else if (kIsWeb && media.bytes != null) {
        // As a fallback on web, create a Blob URL from bytes
        final url = createObjectUrlFromBytes(media.bytes!, mimeType: media.mimeType ?? 'video/mp4');
        if (url != null) {
          _video = _PickedMedia(id: media.id, name: media.name, isVideo: true, objectUrl: url, bytes: media.bytes, path: media.path, mimeType: media.mimeType, duration: media.duration);
          _previewController = VideoPlayerController.networkUrl(Uri.parse(url));
        }
      }
      if (_previewController != null) {
        await _previewController!.initialize();
        _previewController!.setLooping(false);
        if (mounted) setState(() => _previewReady = true);
      }
    } catch (e) {
      debugPrint('init preview controller error: $e');
      if (mounted) setState(() => _previewReady = false);
    }
  }

  String _formatDuration(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hh = d.inHours;
    return hh > 0 ? '$hh:$mm:$ss' : '$mm:$ss';
  }

  String _sanitizeFileName(String name) => name.replaceAll(RegExp(r"[^A-Za-z0-9._-]"), '_');

  Future<void> _publish() async {
    if (_publishing) return;
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      context.pushNamed('login', queryParameters: {'redirect': AppRoutes.uploadReel});
      return;
    }
    // Require a single video
    if (_video == null || _video!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one video (5–120s).')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    // Basic duration check for web/IO (if we probed)
    final dSecs = ((_video!.duration)?.inSeconds ?? 0);
    if (dSecs > _maxVideoSeconds) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max video length is 2 minutes')));
      return;
    } else if (dSecs < _minVideoSeconds) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Min video length is 5 seconds')));
      return;
    }

    // Upgrade toggle path
    if (_upgradeEnabled) {
      if (_paidPackage == null || _paidPackage!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a paid package')));
        return;
      }
      final ok = await context.pushNamed('payment', queryParameters: {'id': '', 'type': 'new', 'pkg': _paidPackage!});
      if (ok != true) return;
    }

    setState(() => _publishing = true);
    try {
      // 1) Log picked video details (debug diagnostics)
      final v = _video!;
      final hasBytes = v.bytes != null && v.bytes!.isNotEmpty;
      final hasPath = (v.path != null && v.path!.isNotEmpty);
      final hasObjectUrl = (v.objectUrl != null && v.objectUrl!.isNotEmpty);
      debugPrint('[UploadReel] Submit start: name=${v.name} mime=${v.mimeType} bytes=${v.bytes?.length ?? 0} path=${v.path} objectUrl=$hasObjectUrl duration=${v.duration}');

      // 2) Validate that we have a real file/blob, not a placeholder string id
      if (kIsWeb) {
        if (!hasBytes) {
          debugPrint('[UploadReel] Invalid web video: missing bytes.');
          throw Exception('Invalid video selected. Please pick again.');
        }
      } else {
        if (!hasBytes && !hasPath) {
          debugPrint('[UploadReel] Invalid mobile/desktop video: missing bytes and path.');
          throw Exception('Invalid video selected. Please pick again.');
        }
      }

      final uid = auth.currentUser?.uid ?? '';
      final displayName = auth.currentUser?.displayName ?? 'Seller';
      final price = int.tryParse(_priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final year = int.tryParse(_yearCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
      final mileage = int.tryParse(_mileageCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''));
      final normalizedPhone = _phoneCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');

      // Create Firestore doc first to get id
      final col = FirebaseFirestore.instance.collection('reels');
      final docRef = col.doc();
      final ts = DateTime.now().millisecondsSinceEpoch;

      // No images in reel flow — keep empty
      final List<String> imageUrls = <String>[];

      // Upload single video to listings/videos/
      final List<String> videoUrls = <String>[];
      try {
        final ext = (v.name.contains('.') ? v.name.split('.').last : 'mp4');
        final fileName = '${ts}_${docRef.id}.${_sanitizeFileName(ext)}';
        final ref = FirebaseStorage.instance.ref('listings/videos/$fileName');
        final meta = SettableMetadata(contentType: (v.mimeType != null && v.mimeType!.isNotEmpty && v.mimeType != 'video/*') ? v.mimeType : 'video/mp4');
        if (hasBytes) {
          debugPrint('[UploadReel] Uploading video bytes (${v.bytes!.length} bytes) to $fileName');
          final snap = await ref.putData(v.bytes!, meta);
          final url = await snap.ref.getDownloadURL();
          videoUrls.add(url);
          debugPrint('[UploadReel] Upload success: $url');
        } else if (hasPath) {
          // On some platforms we might rely on path, but we already attempted to read bytes earlier
          debugPrint('[UploadReel] No bytes but have path. This path should have been read to bytes earlier.');
          throw Exception('Unable to read selected video file. Please reselect.');
        } else if (hasObjectUrl) {
          // We do not upload from objectUrl directly; must have bytes
          debugPrint('[UploadReel] Have objectUrl but no bytes — cannot upload.');
          throw Exception('Invalid video reference. Please reselect the video.');
        }
      } catch (e) {
        debugPrint('[UploadReel] Video upload error: $e');
        rethrow; // Surface to outer catch to show user error
      }

      if (videoUrls.isEmpty) {
        throw Exception('Video upload failed. No URL returned.');
      }

      // Derive listing type/flags from toggle selection
      String finalListingType = 'Free listing';
      bool isVip = false, isFeatured = false, isUrgent = false;
      if (_upgradeEnabled) {
        switch (_paidPackage) {
          case 'vip': finalListingType = 'VIP listing'; isVip = true; break;
          case 'featured': finalListingType = 'Featured listing'; isFeatured = true; break;
          case 'urgent': finalListingType = 'Urgent listing'; isUrgent = true; break;
          case 'topBoost': finalListingType = 'Top Boost'; break;
        }
      }

      final data = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'brand': _brandCtrl.text.trim(),
        'model': _modelCtrl.text.trim(),
        'year': year,
        'price': price,
        'mileage': mileage,
        'location': _locationCtrl.text.trim(),
        'condition': (_selectedCondition ?? '').trim(),
        'transmission': 'Automatic',
        // No category needed in dedicated 'reels' collection
        'imageUrls': imageUrls,
        'videoUrls': videoUrls,
        'videoUrl': videoUrls.first,
        'ownerId': uid,
        'ownerName': displayName,
        'ownerPhone': normalizedPhone,
        'sellerPhone': normalizedPhone, // added for compatibility with UI
        'listingType': finalListingType,
        'isVip': isVip,
        'isFeatured': isFeatured,
        'isUrgent': isUrgent,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'views': 0,
        'viewsCount': 0,
        // Back-compat fields
        'make': _brandCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
      };

      await docRef.set(data);
      // Exact required success log for saved document
      try {
        debugPrint('Saved listing: ' + jsonEncode(data));
      } catch (_) {
        debugPrint('Saved listing: $data');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reel published')));
      context.go(AppRoutes.home);
    } catch (e) {
      debugPrint('Publish reel error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to publish reel. ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Upload Reel'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 120),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Removed image upload UI — reels page is video-only
          const SizedBox(height: AppSpacing.lg),
          // Video box
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: MarketplaceColors.luxCard,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 18, offset: const Offset(0, 10))],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              onTap: _initializing ? null : _pickVideo,
              child: Stack(children: [
                Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.play_circle_outline, size: 52, color: Colors.white70),
                    const SizedBox(height: 8),
                    Text('Add reel video', style: t.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('One video only • 5–120s', style: t.bodySmall?.copyWith(color: Colors.white70)),
                    if (_video != null) ...[
                      const SizedBox(height: 8),
                      Text(_video!.name, style: t.labelLarge?.copyWith(color: Colors.white70), overflow: TextOverflow.ellipsis),
                    ]
                  ]),
                ),
                if (_initializing) const Positioned.fill(child: ColoredBox(color: Colors.black54))
              ]),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_video != null)
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                height: 120,
                width: double.infinity,
                child: Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: Colors.black,
                      child: _previewController != null && _previewController!.value.isInitialized && _previewReady
                          ? LayoutBuilder(builder: (context, constraints) {
                              final ar = _previewController!.value.aspectRatio == 0 ? 9 / 16 : _previewController!.value.aspectRatio;
                              final videoW = constraints.maxHeight * ar; // compute width to allow cover
                              return FittedBox(
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                child: SizedBox(
                                  width: videoW,
                                  height: constraints.maxHeight,
                                  child: VideoPlayer(_previewController!),
                                ),
                              );
                            })
                          : const Center(child: Icon(Icons.play_circle_outline, size: 40, color: Colors.white70)),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () async {
                        try { _previewController?.pause(); } catch (_) {}
                        try { await _previewController?.dispose(); } catch (_) {}
                        if (_video?.objectUrl != null && _video!.objectUrl!.isNotEmpty) {
                          try { revokeObjectUrl(_video!.objectUrl!); } catch (_) {}
                        }
                        setState(() { _video = null; _previewController = null; _previewReady = false; });
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
                        child: const Icon(Icons.close, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.play_arrow_rounded, color: Colors.white70, size: 20),
                const SizedBox(width: 6),
                Expanded(child: Text(_video!.name, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 2),
              Text(_formatDuration(_video!.duration ?? const Duration(seconds: 0)), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white70)),
            ]),
          const SizedBox(height: AppSpacing.xl),
          Form(
            key: _formKey,
            child: Column(children: [
              // Upgrade toggle and paid options (no Free inside section)
              Container(
                decoration: BoxDecoration(color: MarketplaceColors.luxCard, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
                child: SwitchListTile(
                  title: const Text('Upgrade this listing', style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Enable to choose a paid package', style: TextStyle(color: Colors.white70)),
                  value: _upgradeEnabled,
                  onChanged: (v) => setState(() { _upgradeEnabled = v; if (!v) _paidPackage = null; }),
                  activeColor: Colors.black,
                  activeTrackColor: MarketplaceColors.accentYellow,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
              ),
              if (_upgradeEnabled) ...[
                const SizedBox(height: 6),
                _paidTile(scheme, 'VIP listing', 'vip'),
                _paidTile(scheme, 'Featured listing', 'featured'),
                _paidTile(scheme, 'Urgent listing', 'urgent'),
                _paidTile(scheme, 'Top Boost', 'topBoost', customPrice: 75),
              ],
              const SizedBox(height: AppSpacing.md),
              // Removed Title field
              // _LabeledField(label: 'Title', controller: _titleCtrl, validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
              // const SizedBox(height: AppSpacing.md),
              _LabeledField(
                label: 'Brand / Make',
                controller: _brandCtrl,
                readOnly: true,
                onTap: () async {
                  final brands = getAllBrands(includeOther: false);
                  final sel = await _showSearchablePicker(title: 'Select Brand', options: brands);
                  if (sel != null && mounted) {
                    setState(() {
                      _brandCtrl.text = sel;
                      _modelCtrl.clear();
                    });
                  }
                },
                suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              _LabeledField(
                label: 'Model',
                controller: _modelCtrl,
                readOnly: true,
                onTap: () async {
                  final brand = _brandCtrl.text.trim();
                  if (brand.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a brand first')));
                    return;
                  }
                  final models = getModelsForBrand(brand).where((m) => m != kOtherOption).toList();
                  final sel = await _showSearchablePicker(title: 'Select Model', options: models);
                  if (sel != null && mounted) {
                    setState(() => _modelCtrl.text = sel);
                  }
                },
                suffixIcon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: AppSpacing.md),
              _LabeledField(
                label: 'Year',
                controller: _yearCtrl,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // optional
                  final n = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
                  if (n == null) return 'Enter a valid year';
                  if (n < 1950 || n > DateTime.now().year + 1) return 'Year out of range';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _LabeledField(label: 'Price (AED)', controller: _priceCtrl, keyboardType: TextInputType.number, validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
                if (n == null || n <= 0) return 'Enter a valid number';
                return null;
              }),
              const SizedBox(height: AppSpacing.md),
              _LabeledField(
                label: 'Mileage (KM)',
                controller: _mileageCtrl,
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null; // optional
                  final n = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
                  if (n == null || n < 0) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _LabeledField(label: 'Location', controller: _locationCtrl),
              const SizedBox(height: AppSpacing.md),
              _LabeledField(label: 'Description', controller: _descCtrl, maxLines: 4),
            ]),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _publishing ? null : _publish,
              icon: const Icon(Icons.publish, color: Colors.black),
              label: Text('Publish Reel', style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.black)),
              style: ElevatedButton.styleFrom(
                backgroundColor: MarketplaceColors.accentYellow,
                foregroundColor: Colors.black,
                padding: AppSpacing.paddingMd,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _listingTile(ColorScheme scheme, String label) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: MarketplaceColors.luxCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: RadioListTile<String>(
        value: label,
        groupValue: _listingType,
        onChanged: (v) => setState(() => _listingType = v ?? 'Free listing'),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        subtitle: (_listingType == label) ? Text('AED ${_upgradePriceForType(label)}', style: const TextStyle(color: Colors.white70)) : null,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _paidTile(ColorScheme scheme, String label, String value, {int? customPrice}) {
    final price = customPrice ?? _upgradePriceForType(label);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: MarketplaceColors.luxCard,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: RadioListTile<String>(
        value: value,
        groupValue: _paidPackage,
        onChanged: (v) => setState(() => _paidPackage = v),
        title: Text(label, style: const TextStyle(color: Colors.white)),
        subtitle: (_paidPackage == value) ? Text('AED $price', style: const TextStyle(color: Colors.white70)) : null,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }
}

class _PickedMedia {
  final String id;
  final String name;
  final bool isVideo;
  final String? objectUrl; // web blob URL
  final Uint8List? bytes; // image bytes (IO/web)
  final String? path; // IO file path
  final String? mimeType;
  Duration? duration; // optional, for videos
  _PickedMedia({required this.id, required this.name, required this.isVideo, this.objectUrl, this.bytes, this.path, this.mimeType, this.duration});
  factory _PickedMedia.empty() => _PickedMedia(id: '', name: '', isVideo: false);
  bool get isEmpty => id.isEmpty;
}

class _MediaThumb extends StatelessWidget {
  final _PickedMedia media;
  final VoidCallback onRemove;
  const _MediaThumb({required this.media, required this.onRemove});

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final width = 90.0;
    final height = 120.0;
    Widget content;
    if (!media.isVideo) {
      // Image thumbnail
      if (media.bytes != null) {
        content = Image.memory(media.bytes!, width: width, height: height, fit: BoxFit.cover);
      } else if (media.objectUrl != null) {
        content = Image.network(media.objectUrl!, width: width, height: height, fit: BoxFit.cover);
      } else if (media.path != null && media.path!.isNotEmpty) {
        // Fallback for IO paths; Image.file is not available on web, so avoid here
        content = Container(width: width, height: height, color: Colors.black26, alignment: Alignment.center, child: const Icon(Icons.image, color: Colors.white70));
      } else {
        content = const ColoredBox(color: Colors.black26, child: SizedBox(width: 80, height: 110));
      }
    } else {
      // Video placeholder thumbnail (no generation). Dark card with play icon and label.
      content = Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.play_circle_fill, color: Colors.white70, size: 28),
          const SizedBox(height: 6),
          const Text('Video', style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );
    }

    return Stack(children: [
      ClipRRect(borderRadius: BorderRadius.circular(12), child: content),
      // Remove button
      Positioned(
        top: 4,
        right: 4,
        child: GestureDetector(
          onTap: onRemove,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), shape: BoxShape.circle, border: Border.all(color: Colors.white24)),
            child: const Icon(Icons.close, color: Colors.white, size: 16),
          ),
        ),
      ),
      // Type label
      Positioned(
        left: 6,
        bottom: 6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(6)),
          child: Text(media.isVideo ? 'Video' : 'Image', style: const TextStyle(color: Colors.white, fontSize: 10)),
        ),
      ),
      // Duration label for videos, if available
      if (media.isVideo && media.duration != null)
        Positioned(
          right: 6,
          bottom: 6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(6)),
            child: Text(_formatDuration(media.duration!), style: const TextStyle(color: Colors.white, fontSize: 10)),
          ),
        ),
    ]);
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final int maxLines;
  final String? Function(String?)? validator;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;
  const _LabeledField({required this.label, required this.controller, this.keyboardType = TextInputType.text, this.maxLines = 1, this.validator, this.readOnly = false, this.onTap, this.suffixIcon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: MarketplaceColors.luxCard,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

extension _UploadReelPageStateExt on _UploadReelPageState {
  Future<String?> _showSearchablePicker({required String title, required List<String> options}) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
      builder: (ctx) {
        String query = '';
        List<String> filtered = List<String>.from(options);
        return StatefulBuilder(builder: (context, setSt) {
          void applyFilter(String q) {
            setSt(() {
              query = q;
              filtered = options.where((e) => e.toLowerCase().contains(q.toLowerCase())).toList();
            });
          }
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(children: [
                    Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700))),
                    IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: Colors.white70))
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    onChanged: applyFilter,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: MarketplaceColors.luxCard,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    ),
                  ),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                    itemBuilder: (context, index) {
                      final value = filtered[index];
                      return ListTile(
                        title: Text(value, style: const TextStyle(color: Colors.white)),
                        onTap: () => Navigator.of(context).pop(value),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ]),
            ),
          );
        });
      },
    );
  }
}