import 'dart:async';
import 'dart:html' as html;

class PickedVideo {
  final String name;
  final String mimeType;
  final List<int> bytes;
  final String objectUrl;
  PickedVideo({required this.name, required this.mimeType, required this.bytes, required this.objectUrl});
}

Future<PickedVideo?> pickVideoWithWebFilePicker() async {
  final completer = Completer<PickedVideo?>();
  try {
    final input = html.FileUploadInputElement();
    input.accept = 'video/*';
    input.multiple = false;

    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) {
        completer.complete(null);
        return;
      }
      final file = files.first;
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      await reader.onLoad.first;
      final data = reader.result as List<int>;
      final blobUrl = html.Url.createObjectUrl(file);
      completer.complete(PickedVideo(name: file.name, mimeType: file.type.isNotEmpty ? file.type : 'video/mp4', bytes: data, objectUrl: blobUrl));
    });

    input.onError.listen((event) => completer.completeError(event));
    input.click();
  } catch (e) {
    completer.completeError(e);
  }
  return completer.future;
}