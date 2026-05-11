String? createObjectUrlFromBytes(List<int> bytes, {String mimeType = 'video/mp4'}) {
  // Not supported on IO by default; return null. Preview will use local file path.
  return null;
}

void revokeObjectUrl(String url) {
  // No-op on IO
}