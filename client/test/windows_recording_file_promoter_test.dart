import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:signbridge/core/services/windows_recording_file_promoter.dart';

void main() {
  late Directory temporary;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('signbridge_promote_');
  });

  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  test('verifies destination before removing camera source', () async {
    final source = File(p.join(temporary.path, 'camera-output.mp4'));
    final bytes = List<int>.generate(2048, (index) => index % 239);
    await source.writeAsBytes(bytes);
    final destination = p.join(temporary.path, 'recordings', 'capture.mp4');

    final result = await const WindowsRecordingFilePromoter().promote(
      source: source,
      destinationPath: destination,
    );

    expect(await result.readAsBytes(), bytes);
    expect(await source.exists(), isFalse);
    expect(await File('$destination.partial').exists(), isFalse);
  });

  test('keeps camera source when destination already exists', () async {
    final source = File(p.join(temporary.path, 'camera-output.mp4'));
    await source.writeAsBytes([1, 2, 3]);
    final destination = File(p.join(temporary.path, 'existing.mp4'));
    await destination.writeAsBytes([9]);

    await expectLater(
      const WindowsRecordingFilePromoter().promote(
        source: source,
        destinationPath: destination.path,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(await source.readAsBytes(), [1, 2, 3]);
    expect(await destination.readAsBytes(), [9]);
  });
}
