class PickedVideo {
  final String name;
  final String mimeType;
  final List<int> bytes;
  final String objectUrl; // empty on IO
  PickedVideo({required this.name, required this.mimeType, required this.bytes, required this.objectUrl});
}

Future<PickedVideo?> pickVideoWithWebFilePicker() async {
  // Not supported on IO in this helper; use ImagePicker in UI instead.
  return null;
}