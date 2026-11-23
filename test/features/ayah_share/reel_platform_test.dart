import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pro_video_editor is pinned exactly', () {
    final pubspec = File('pubspec.yaml').readAsLinesSync();

    expect(pubspec, contains('  pro_video_editor: 2.54.0'));
  });

  test('Info.plist explains the photo library use', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();

    expect(
      plist,
      matches(
        RegExp(
          r'<key>NSPhotoLibraryUsageDescription</key>\s*'
          r'<string>Used only if you choose to save a shared ayah video\.</string>',
        ),
      ),
    );
    expect(
      plist,
      matches(
        RegExp(
          r'<key>NSPhotoLibraryAddUsageDescription</key>\s*'
          r'<string>Used only to save a shared ayah image or video to your photos\.</string>',
        ),
      ),
    );
  });

  test('the Arabic InfoPlist.strings is bundled', () {
    final strings = File(
      'ios/Runner/ar.lproj/InfoPlist.strings',
    ).readAsStringSync();
    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(strings.trim().split('\n'), [
      '"NSPhotoLibraryUsageDescription" = "يُستخدم فقط إذا اخترت حفظ مقطع آية شاركته.";',
      '"NSPhotoLibraryAddUsageDescription" = "يُستخدم فقط لحفظ صورة آية أو مقطعها الذي شاركته في صورك.";',
    ]);
    expect(project, contains('ar.lproj/InfoPlist.strings'));
    expect(project, matches(RegExp(r'knownRegions = \([^)]*\bar,[^)]*\);')));
  });
}
