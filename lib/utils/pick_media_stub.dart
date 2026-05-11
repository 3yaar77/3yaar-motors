class PickedMediaWeb {
  final String name;
  final String mimeType;
  final List<int> bytes;
  final String objectUrl;
  final bool isVideo;
  PickedMediaWeb({required this.name, required this.mimeType, required this.bytes, required this.objectUrl, required this.isVideo});
}

Future<List<PickedMediaWeb>> pickMultipleMediaWeb({String accept = 'image/*,video/*'}) async {
  // Not supported on IO in this helper; web-only. Use ImagePicker in UI for IO.
  return <PickedMediaWeb>[];
}
