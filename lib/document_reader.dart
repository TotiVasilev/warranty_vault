import 'dart:io';
import 'package:pdfrx/pdfrx.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'vault.dart';

Future<String> readDocument(PendingDoc d) async {
  if (d.doc.ext == 'pdf') {
    await pdfrxFlutterInitialize();
    final pdf = await PdfDocument.openData(d.bytes);
    try {
      final result = StringBuffer();
      for (final page in pdf.pages.take(30)) {
        final text = await page.loadText();
        result.writeln(text?.fullText ?? '');
      }
      return result.toString();
    } finally {
      pdf.dispose();
    }
  }
  final tmp = await getTemporaryDirectory();
  final f = File(p.join(tmp.path, '${d.doc.id}.${d.doc.ext}'));
  await f.writeAsBytes(d.bytes);
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      try {
        return (await recognizer.processImage(
          InputImage.fromFilePath(f.path),
        )).text;
      } finally {
        await recognizer.close();
      }
    }
    // Optional free desktop OCR; install Tesseract and add it to PATH.
    final result = await Process.run('tesseract', [
      f.path,
      'stdout',
      '-l',
      'eng+bul',
    ]);
    if (result.exitCode != 0)
      throw StateError(
        'Tesseract OCR failed. Install English and Bulgarian trained data.',
      );
    return result.stdout as String;
  } finally {
    if (await f.exists()) await f.delete();
  }
}
