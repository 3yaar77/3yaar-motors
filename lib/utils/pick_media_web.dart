import 'dart:async';
import 'dart:html' as html;

class PickedMediaWeb {
  final String name;
  final String mimeType;
  final List<int> bytes;
  final String objectUrl; // blob: URL
  final bool isVideo;
  PickedMediaWeb({required this.name, required this.mimeType, required this.bytes, required this.objectUrl, required this.isVideo});
}

Future<List<PickedMediaWeb>> pickMultipleMediaWeb({String accept = 'image/*,video/*'}) async {
  final completer = Completer<List<PickedMediaWeb>>();
  try {
    final input = html.FileUploadInputElement();
    input.accept = accept;
    input.multiple = true;

    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) {
        completer.complete(<PickedMediaWeb>[]);
        return;
      }
      final List<PickedMediaWeb> out = [];
      for (final file in files) {
        try {
          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);
          await reader.onLoad.first;
          final data = reader.result as List<int>;
          final blobUrl = html.Url.createObjectUrl(file);
          final type = (file.type.isNotEmpty ? file.type : 'application/octet-stream').toLowerCase();
          final isVideo = type.startsWith('video/');
          out.add(PickedMediaWeb(name: file.name, mimeType: type, bytes: data, objectUrl: blobUrl, isVideo: isVideo));
        } catch (_) {}
      }
      completer.complete(out);
    });

    input.onError.listen((event) => completer.completeError(event));
    input.click();
  } catch (e) {
    completer.completeError(e);
  }
  return completer.future;
}
