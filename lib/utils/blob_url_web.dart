import 'dart:html' as html;

String? createObjectUrlFromBytes(List<int> bytes, {String mimeType = 'video/mp4'}) {
  try {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    return url;
  } catch (e) {
    return null;
  }
}

void revokeObjectUrl(String url) {
  try {
    html.Url.revokeObjectUrl(url);
  } catch (_) {}
}