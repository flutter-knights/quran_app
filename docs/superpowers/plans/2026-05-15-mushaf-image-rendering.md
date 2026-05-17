# Mushaf Image-Rendering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current QCF-text mushaf rendering with bundled pre-rendered PNG assets + ayah-bounds JSON, eliminating cold-render lag and runtime font shaping.

**Architecture:** Build-time generator (Flutter test) renders all 604 mushaf pages to transparent PNGs (1536px wide) + normalized ayah-rect JSON. Runtime widget paints `Image.asset` tinted by theme under a `CustomPainter` highlight overlay, with a single `GestureDetector` hit-testing against normalized rects. New domain/data/presentation are built alongside the old code with an `Image` suffix, then a single cutover swaps the production route, then old code is deleted and `Image` suffixes are renamed away.

**Tech Stack:** Flutter, flutter_bloc (Cubit), GetIt (`sl`), dartz `Either<Failure, T>`, go_router, `quran` package (build-time only), QCF WOFF fonts (build-time only).

**Spec:** [`docs/superpowers/specs/2026-05-15-mushaf-image-rendering-design.md`](../specs/2026-05-15-mushaf-image-rendering-design.md)

---

## File Structure

**New files (created during Phase 1–3, renamed to canonical names in Phase 5):**

```
test/tools/
  generate_mushaf_assets_test.dart        # Loops 1..604, writes PNG+JSON
  verify_mushaf_assets_test.dart          # Asserts (surah, ayah) coverage
  woff_to_ttf.dart                         # Moved from test/spikes/

assets/mushaf/
  pages/page_001.png .. page_604.png       # Generated PNGs
  bounds/page_001.json .. page_604.json    # Generated bounds JSON

lib/features/surah/
  domain/entities/
    normalized_rect.dart                   # {x, y, w, h} doubles
    ayah_bound_entity.dart                 # {surah, ayah, lines}
    mushaf_page_image_entity.dart          # {pageNumber, ayahs}
  data/models/
    mushaf_page_image_model.dart           # fromJson, extends entity
  data/datasources/
    mushaf_image_local_data_source.dart    # Reads bounds JSON via rootBundle
  domain/repositories/
    mushaf_image_repo.dart                 # Abstract: Either<Failure, T>
  data/repositories/
    mushaf_image_repo_impl.dart            # Maps exceptions to Failure
  domain/usecases/
    get_mushaf_page_image.dart             # Wraps repository.getPage
  presentation/cubit/mushaf_image/
    mushaf_image_state.dart                # {currentPage, highlightedAyah, playingAyah}
    mushaf_image_cubit.dart                # Actions + PlaybackCubit listener
  presentation/pages/mushaf_image/
    mushaf_image_page.dart                 # Scaffold + PageView.builder + page number
    mushaf_image_di.dart                   # GetIt registrations
    widgets/
      mushaf_page_view.dart                # One page in the PageView
      ayah_highlight_painter.dart          # CustomPainter for highlight rects
      ayah_action_sheet.dart               # Long-press menu
      mushaf_page_number_text.dart         # Runtime Arabic-digit overlay
```

**Files deleted in Phase 5:**

```
lib/features/surah/data/datasources/mushaf_local_data_source.dart   (text-based)
lib/features/surah/data/datasources/mushaf_page_cache.dart
lib/features/surah/data/datasources/mushaf_spans_cache.dart
lib/features/surah/data/repositories/mushaf_repo_impl.dart          (old)
lib/features/surah/domain/entities/mushaf_page_entity.dart          (old)
lib/features/surah/domain/repositories/mushaf_repo.dart             (old)
lib/features/surah/domain/usecases/get_mushaf_page.dart             (old)
lib/features/surah/presentation/cubit/mushaf/                       (entire dir)
lib/features/surah/presentation/pages/mushaf/                       (entire dir)
test/spikes/                                                         (entire dir)
```

**Files modified:**

```
pubspec.yaml                                                        # Remove QCF fonts, add mushaf assets
lib/features/surah/presentation/pages/mushaf/mushaf_di.dart         # Replaced by mushaf_image_di.dart in Phase 5 rename
lib/core/di/dependency_injection.dart                               # Calls renamed initMushaf()
lib/config/router/app_router.dart                                   # Adds debug route in Phase 3, swaps in Phase 4
```

---

## Phase 1: Asset Generator (assets committed to repo)

### Task 1: Move the spike into a parameterized generator over all 604 pages

**Files:**
- Create: `test/tools/generate_mushaf_assets_test.dart`
- Create: `test/tools/woff_to_ttf.dart` (copied from `test/spikes/woff_to_ttf.dart`, unchanged)
- Modify: nothing else yet (old spike files stay in place until Phase 5)

- [ ] **Step 1: Copy `woff_to_ttf.dart` verbatim into `test/tools/`**

```bash
cp test/spikes/woff_to_ttf.dart test/tools/woff_to_ttf.dart
```

(On Windows PowerShell: `Copy-Item test/spikes/woff_to_ttf.dart test/tools/woff_to_ttf.dart -Force`)

- [ ] **Step 2: Create the generator test that loops pages 1..604**

Write `test/tools/generate_mushaf_assets_test.dart`:

```dart
// Generates assets/mushaf/pages/page_NNN.png and assets/mushaf/bounds/page_NNN.json
// for every mushaf page (1..604). Run with --concurrency=1 to avoid FontLoader races.
//
// Pipeline per page:
//   WOFF -> in-Dart SFNT (TTF) -> FontLoader -> TextPainter -> Picture -> PNG
//   getBoxesForSelection -> normalized ayah rects -> JSON
//
// Validation per page: PNG > 10KB AND ayahs non-empty AND every ayah has rects.
//
//   flutter test test/tools/generate_mushaf_assets_test.dart --concurrency=1

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_local_data_source.dart';

import 'woff_to_ttf.dart';

const String _headerImagePath = 'assets/images/header.png';
const double _renderWidth = 1536;
const double _aspect = 1.82;
const String _outputPagesDir = 'assets/mushaf/pages';
const String _outputBoundsDir = 'assets/mushaf/bounds';
const String _headerFontFamily = 'QCF_P000';
const String _headerFontPath = 'assets/fonts/QCF/QCF2BSML.woff';
const String _basmalaText = '!"#\n';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFontFromWoff(_headerFontFamily, _headerFontPath);
    Directory(_outputPagesDir).createSync(recursive: true);
    Directory(_outputBoundsDir).createSync(recursive: true);
  });

  for (var pageNumber = 1; pageNumber <= 604; pageNumber++) {
    test('generate page $pageNumber', () async {
      await _renderPage(pageNumber);
    });
  }
}

Future<void> _renderPage(int pageNumber) async {
  final pageFontFamily = 'QCF_P${pageNumber.toString().padLeft(3, '0')}';
  final pageFontPath =
      'assets/fonts/QCF/QCF2${pageNumber.toString().padLeft(3, '0')}.woff';
  await _loadFontFromWoff(pageFontFamily, pageFontPath);

  final page = const MushafLocalDataSource().getPage(pageNumber);

  final fontSize = _renderWidth / 15 * 0.9;
  final lineHeight = _renderWidth / 15 * 1.8;
  final pageHeight = _renderWidth * _aspect;

  final verseStyle = TextStyle(
    fontFamily: pageFontFamily,
    fontSize: fontSize,
    height: lineHeight / fontSize,
    color: Colors.black,
    locale: const Locale('ar'),
  );
  final headerNameStyle = TextStyle(
    fontFamily: _headerFontFamily,
    fontSize: fontSize * 1.4,
    color: Colors.black,
    locale: const Locale('ar'),
  );
  final basmalaStyle = TextStyle(
    fontFamily: _headerFontFamily,
    fontSize: fontSize,
    height: lineHeight / fontSize,
    color: Colors.black,
    locale: const Locale('ar'),
  );

  final headerIndexes = page.surahHeadersIndexes.toSet();
  final basmalaIndexes = page.basmalaIndexes.toSet();
  final topHeaderName = headerIndexes.contains(0) ? page.surahNames.first : null;
  final topReserve = topHeaderName != null ? lineHeight : 0.0;

  final children = <InlineSpan>[];
  final ayahRanges = <({int start, int end})>[];
  var cursor = 0;
  var surahCounter = 0;
  for (var i = 0; i <= page.ayahs.length; i++) {
    if (headerIndexes.contains(i)) {
      if (i == 0) {
        surahCounter++;
      } else {
        final text = '${page.surahNames[surahCounter]}\n';
        children.add(TextSpan(
          text: text,
          style: headerNameStyle.copyWith(height: lineHeight / (fontSize * 1.4)),
        ));
        cursor += text.length;
        surahCounter++;
      }
    }
    if (basmalaIndexes.contains(i)) {
      children.add(TextSpan(text: _basmalaText, style: basmalaStyle));
      cursor += _basmalaText.length;
    }
    if (i < page.ayahs.length) {
      final start = cursor;
      final ayahText = page.ayahs[i];
      children.add(TextSpan(text: ayahText, style: verseStyle));
      cursor += ayahText.length;
      ayahRanges.add((start: start, end: cursor));
    }
  }

  final painter = TextPainter(
    text: TextSpan(children: children),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.center,
    maxLines: 15,
  );
  painter.layout(minWidth: _renderWidth, maxWidth: _renderWidth);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  if (topHeaderName != null) {
    final headerImage = await _loadImage(_headerImagePath);
    canvas.drawImageRect(
      headerImage,
      Rect.fromLTWH(0, 0,
          headerImage.width.toDouble(), headerImage.height.toDouble()),
      Rect.fromLTWH(0, 0, _renderWidth, lineHeight),
      Paint()..colorFilter = const ColorFilter.mode(Colors.black, BlendMode.srcIn),
    );

    final namePainter = TextPainter(
      text: TextSpan(text: topHeaderName, style: headerNameStyle),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    );
    namePainter.layout(minWidth: _renderWidth, maxWidth: _renderWidth);
    final nameDy = (lineHeight - namePainter.height) / 2;
    namePainter.paint(canvas, Offset(0, nameDy + 4));
  }

  canvas.save();
  canvas.translate(0, topReserve);
  painter.paint(canvas, Offset.zero);
  canvas.restore();

  final picture = recorder.endRecording();
  final image =
      await picture.toImage(_renderWidth.toInt(), pageHeight.toInt());
  final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final pngFile = File(
      '$_outputPagesDir/page_${pageNumber.toString().padLeft(3, '0')}.png');
  await pngFile.writeAsBytes(pngBytes!.buffer.asUint8List());

  final pngLen = pngFile.lengthSync();
  expect(pngLen, greaterThan(10 * 1024),
      reason: 'page $pageNumber PNG too small ($pngLen bytes)');

  final bounds = <Map<String, dynamic>>[];
  for (var i = 0; i < ayahRanges.length; i++) {
    final range = ayahRanges[i];
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: range.start, extentOffset: range.end),
      boxHeightStyle: ui.BoxHeightStyle.includeLineSpacingMiddle,
    );
    expect(boxes, isNotEmpty,
        reason: 'page $pageNumber ayah index $i produced no rects');
    final ident = page.ayahIdentifiers[i];
    bounds.add({
      'surah': ident.surah,
      'ayah': ident.ayah,
      'lines': boxes
          .map((b) => {
                'x': double.parse((b.left / _renderWidth).toStringAsFixed(5)),
                'y': double.parse(((b.top + topReserve) / pageHeight).toStringAsFixed(5)),
                'w': double.parse(((b.right - b.left) / _renderWidth).toStringAsFixed(5)),
                'h': double.parse(((b.bottom - b.top) / pageHeight).toStringAsFixed(5)),
              })
          .toList(),
    });
  }
  expect(bounds, isNotEmpty, reason: 'page $pageNumber has no ayahs');

  final jsonFile = File(
      '$_outputBoundsDir/page_${pageNumber.toString().padLeft(3, '0')}.json');
  await jsonFile.writeAsString(jsonEncode({
    'page': pageNumber,
    'ayahs': bounds,
  }));
}

Future<void> _loadFontFromWoff(String family, String assetPath) async {
  final woffBytes = (await rootBundle.load(assetPath)).buffer.asUint8List();
  final ttfBytes = woffToSfnt(woffBytes);
  final loader = FontLoader(family);
  loader.addFont(Future.value(ByteData.view(ttfBytes.buffer)));
  await loader.load();
}

Future<ui.Image> _loadImage(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  return frame.image;
}
```

- [ ] **Step 3: Smoke-run the generator on a single page to verify shape**

Run: `flutter test test/tools/generate_mushaf_assets_test.dart --plain-name "generate page 50" --concurrency=1`

Expected output (final line): `+1: All tests passed!`

Verify:
- `assets/mushaf/pages/page_050.png` exists and is > 10KB.
- `assets/mushaf/bounds/page_050.json` exists and contains an `"ayahs"` array with at least one entry.

- [ ] **Step 4: Commit the generator scaffolding**

```bash
git add test/tools/generate_mushaf_assets_test.dart test/tools/woff_to_ttf.dart
git commit -m "feat(mushaf): add 604-page asset generator (test/tools/)"
```

---

### Task 2: Run the full generator and commit the assets

**Files:**
- Create: `assets/mushaf/pages/page_001.png` .. `page_604.png` (604 files)
- Create: `assets/mushaf/bounds/page_001.json` .. `page_604.json` (604 files)

- [ ] **Step 1: Run the full generator (single-threaded)**

Run: `flutter test test/tools/generate_mushaf_assets_test.dart --concurrency=1`

Expected: `+604: All tests passed!` after several minutes. If any single page fails its assertion, investigate that page's font/data before continuing.

- [ ] **Step 2: Spot-check three sample outputs visually**

Open each in any image viewer:
- `assets/mushaf/pages/page_001.png` (Al-Fatiha — top header + body)
- `assets/mushaf/pages/page_002.png` (Al-Baqarah start — top header + basmala + verses)
- `assets/mushaf/pages/page_100.png` (vanilla — verses only, no header)

All three should be transparent-background, black ink, correctly laid out.

- [ ] **Step 3: Commit the generated assets**

```bash
git add assets/mushaf/
git commit -m "feat(mushaf): generate 604 page PNGs and ayah-bounds JSON"
```

---

### Task 3: Asset-coverage verification test

**Files:**
- Create: `test/tools/verify_mushaf_assets_test.dart`

- [ ] **Step 1: Write the coverage test**

```dart
// Asserts every (surah, ayah) from the `quran` package appears exactly once
// across all 604 bounds JSONs.
//
//   flutter test test/tools/verify_mushaf_assets_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;

void main() {
  test('every (surah, ayah) is covered exactly once', () {
    final seen = <String>{};
    for (var page = 1; page <= 604; page++) {
      final path = 'assets/mushaf/bounds/page_${page.toString().padLeft(3, '0')}.json';
      final raw = File(path).readAsStringSync();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final ayahs = (data['ayahs'] as List).cast<Map<String, dynamic>>();
      for (final a in ayahs) {
        final key = '${a['surah']}:${a['ayah']}';
        expect(seen.contains(key), isFalse,
            reason: 'duplicate $key on page $page');
        seen.add(key);
      }
    }

    final expected = <String>{};
    for (var s = 1; s <= 114; s++) {
      for (var a = 1; a <= quran.getVerseCount(s); a++) {
        expected.add('$s:$a');
      }
    }

    final missing = expected.difference(seen);
    expect(missing, isEmpty, reason: 'missing ayahs: ${missing.take(10)}');
    final extra = seen.difference(expected);
    expect(extra, isEmpty, reason: 'unexpected ayahs: ${extra.take(10)}');
  });
}
```

- [ ] **Step 2: Run it**

Run: `flutter test test/tools/verify_mushaf_assets_test.dart`

Expected: `+1: All tests passed!` and zero missing/extra ayahs.

- [ ] **Step 3: Commit**

```bash
git add test/tools/verify_mushaf_assets_test.dart
git commit -m "test(mushaf): verify (surah, ayah) coverage across all 604 pages"
```

---

## Phase 2: New Domain + Data Layer (parallel to old code)

### Task 4: Domain entities — `NormalizedRect`, `AyahBoundEntity`, `MushafPageImageEntity`

**Files:**
- Create: `lib/features/surah/domain/entities/normalized_rect.dart`
- Create: `lib/features/surah/domain/entities/ayah_bound_entity.dart`
- Create: `lib/features/surah/domain/entities/mushaf_page_image_entity.dart`
- Test: `test/features/surah/domain/entities/mushaf_page_image_entity_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/surah/domain/entities/mushaf_page_image_entity_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/ayah_bound_entity.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_image_entity.dart';
import 'package:quran_app/features/surah/domain/entities/normalized_rect.dart';

void main() {
  test('MushafPageImageEntity holds page number and ayah bounds', () {
    final entity = MushafPageImageEntity(
      pageNumber: 2,
      ayahs: const [
        AyahBoundEntity(
          ayah: AyahIdentifier(surah: 2, ayah: 1),
          lines: [NormalizedRect(x: 0.1, y: 0.2, w: 0.3, h: 0.05)],
        ),
      ],
    );

    expect(entity.pageNumber, 2);
    expect(entity.ayahs, hasLength(1));
    expect(entity.ayahs.first.ayah.surah, 2);
    expect(entity.ayahs.first.lines.first.x, 0.1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/surah/domain/entities/mushaf_page_image_entity_test.dart`
Expected: FAIL with "Target of URI doesn't exist".

- [ ] **Step 3: Implement the three entities**

`lib/features/surah/domain/entities/normalized_rect.dart`:

```dart
class NormalizedRect {
  final double x;
  final double y;
  final double w;
  final double h;

  const NormalizedRect({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });
}
```

`lib/features/surah/domain/entities/ayah_bound_entity.dart`:

```dart
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import 'normalized_rect.dart';

class AyahBoundEntity {
  final AyahIdentifier ayah;
  final List<NormalizedRect> lines;

  const AyahBoundEntity({required this.ayah, required this.lines});
}
```

`lib/features/surah/domain/entities/mushaf_page_image_entity.dart`:

```dart
import 'ayah_bound_entity.dart';

class MushafPageImageEntity {
  final int pageNumber;
  final List<AyahBoundEntity> ayahs;

  const MushafPageImageEntity({required this.pageNumber, required this.ayahs});
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/surah/domain/entities/mushaf_page_image_entity_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/domain/entities/normalized_rect.dart lib/features/surah/domain/entities/ayah_bound_entity.dart lib/features/surah/domain/entities/mushaf_page_image_entity.dart test/features/surah/domain/entities/mushaf_page_image_entity_test.dart
git commit -m "feat(mushaf): add image-rendering domain entities"
```

---

### Task 5: Data model — `MushafPageImageModel` (fromJson)

**Files:**
- Create: `lib/features/surah/data/models/mushaf_page_image_model.dart`
- Test: `test/features/surah/data/models/mushaf_page_image_model_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/surah/data/models/mushaf_page_image_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/data/models/mushaf_page_image_model.dart';

void main() {
  test('MushafPageImageModel.fromJson parses page + ayahs + rects', () {
    final model = MushafPageImageModel.fromJson({
      'page': 2,
      'ayahs': [
        {
          'surah': 2,
          'ayah': 1,
          'lines': [
            {'x': 0.1, 'y': 0.2, 'w': 0.3, 'h': 0.05},
          ],
        },
      ],
    });

    expect(model.pageNumber, 2);
    expect(model.ayahs, hasLength(1));
    expect(model.ayahs.first.ayah.surah, 2);
    expect(model.ayahs.first.ayah.ayah, 1);
    expect(model.ayahs.first.lines.first.x, 0.1);
    expect(model.ayahs.first.lines.first.h, 0.05);
  });

  test('MushafPageImageModel.fromJson handles multi-line ayahs', () {
    final model = MushafPageImageModel.fromJson({
      'page': 5,
      'ayahs': [
        {
          'surah': 2,
          'ayah': 30,
          'lines': [
            {'x': 0.0, 'y': 0.1, 'w': 1.0, 'h': 0.05},
            {'x': 0.0, 'y': 0.15, 'w': 0.8, 'h': 0.05},
          ],
        },
      ],
    });

    expect(model.ayahs.first.lines, hasLength(2));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/surah/data/models/mushaf_page_image_model_test.dart`
Expected: FAIL with "Target of URI doesn't exist".

- [ ] **Step 3: Implement the model**

`lib/features/surah/data/models/mushaf_page_image_model.dart`:

```dart
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../domain/entities/ayah_bound_entity.dart';
import '../../domain/entities/mushaf_page_image_entity.dart';
import '../../domain/entities/normalized_rect.dart';

class MushafPageImageModel extends MushafPageImageEntity {
  const MushafPageImageModel({
    required super.pageNumber,
    required super.ayahs,
  });

  factory MushafPageImageModel.fromJson(Map<String, dynamic> json) {
    final ayahs = (json['ayahs'] as List)
        .cast<Map<String, dynamic>>()
        .map(_ayahFromJson)
        .toList(growable: false);
    return MushafPageImageModel(
      pageNumber: json['page'] as int,
      ayahs: ayahs,
    );
  }

  static AyahBoundEntity _ayahFromJson(Map<String, dynamic> json) {
    return AyahBoundEntity(
      ayah: AyahIdentifier(
        surah: json['surah'] as int,
        ayah: json['ayah'] as int,
      ),
      lines: (json['lines'] as List)
          .cast<Map<String, dynamic>>()
          .map(_rectFromJson)
          .toList(growable: false),
    );
  }

  static NormalizedRect _rectFromJson(Map<String, dynamic> json) {
    return NormalizedRect(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      w: (json['w'] as num).toDouble(),
      h: (json['h'] as num).toDouble(),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/surah/data/models/mushaf_page_image_model_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/data/models/mushaf_page_image_model.dart test/features/surah/data/models/mushaf_page_image_model_test.dart
git commit -m "feat(mushaf): add MushafPageImageModel JSON parsing"
```

---

### Task 6: Data source — `MushafImageLocalDataSource`

**Files:**
- Create: `lib/features/surah/data/datasources/mushaf_image_local_data_source.dart`
- Test: `test/features/surah/data/datasources/mushaf_image_local_data_source_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/surah/data/datasources/mushaf_image_local_data_source_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_image_local_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const dummyJson =
      '{"page":2,"ayahs":[{"surah":2,"ayah":1,"lines":[{"x":0.1,"y":0.2,"w":0.3,"h":0.05}]}]}';

  setUp(() {
    ServicesBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      final key = utf8.decode(message!.buffer.asUint8List());
      if (key == 'assets/mushaf/bounds/page_002.json') {
        return ByteData.view(Uint8List.fromList(utf8.encode(dummyJson)).buffer);
      }
      return null;
    });
  });

  test('getPage loads and parses bounds JSON for given page', () async {
    final ds = MushafImageLocalDataSource();
    final page = await ds.getPage(2);
    expect(page.pageNumber, 2);
    expect(page.ayahs.first.ayah.surah, 2);
  });

  test('getPage caches subsequent calls (single bundle read)', () async {
    final ds = MushafImageLocalDataSource();
    final a = await ds.getPage(2);
    final b = await ds.getPage(2);
    expect(identical(a, b), isTrue);
  });
}
```

Add at the top of the test file:

```dart
import 'dart:convert';
import 'dart:typed_data';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/surah/data/datasources/mushaf_image_local_data_source_test.dart`
Expected: FAIL with "Target of URI doesn't exist".

- [ ] **Step 3: Implement the data source**

`lib/features/surah/data/datasources/mushaf_image_local_data_source.dart`:

```dart
import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/mushaf_page_image_model.dart';

class MushafImageLocalDataSource {
  MushafImageLocalDataSource();

  final Map<int, MushafPageImageModel> _cache = {};

  Future<MushafPageImageModel> getPage(int pageNumber) async {
    final cached = _cache[pageNumber];
    if (cached != null) return cached;

    final path =
        'assets/mushaf/bounds/page_${pageNumber.toString().padLeft(3, '0')}.json';
    final raw = await rootBundle.loadString(path);
    final model = MushafPageImageModel.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    _cache[pageNumber] = model;
    return model;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/surah/data/datasources/mushaf_image_local_data_source_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/data/datasources/mushaf_image_local_data_source.dart test/features/surah/data/datasources/mushaf_image_local_data_source_test.dart
git commit -m "feat(mushaf): add MushafImageLocalDataSource (rootBundle + in-memory cache)"
```

---

### Task 7: Repository (interface + impl) returning `Either<Failure, MushafPageImageEntity>`

**Files:**
- Create: `lib/features/surah/domain/repositories/mushaf_image_repo.dart`
- Create: `lib/features/surah/data/repositories/mushaf_image_repo_impl.dart`
- Test: `test/features/surah/data/repositories/mushaf_image_repo_impl_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/surah/data/repositories/mushaf_image_repo_impl_test.dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_image_local_data_source.dart';
import 'package:quran_app/features/surah/data/models/mushaf_page_image_model.dart';
import 'package:quran_app/features/surah/data/repositories/mushaf_image_repo_impl.dart';

class _StubDataSource extends MushafImageLocalDataSource {
  _StubDataSource(this._result);
  final Object _result; // model or Exception
  @override
  Future<MushafPageImageModel> getPage(int pageNumber) async {
    final r = _result;
    if (r is Exception) throw r;
    return r as MushafPageImageModel;
  }
}

void main() {
  test('returns Right on success', () async {
    final model = MushafPageImageModel.fromJson({
      'page': 2,
      'ayahs': [
        {
          'surah': 2,
          'ayah': 1,
          'lines': [
            {'x': 0.0, 'y': 0.0, 'w': 0.1, 'h': 0.05}
          ],
        },
      ],
    });
    final repo = MushafImageRepositoryImpl(dataSource: _StubDataSource(model));
    final result = await repo.getPage(2);
    expect(result, isA<Right<Failure, dynamic>>());
    result.fold((_) => fail('expected right'), (e) {
      expect(e.pageNumber, 2);
    });
  });

  test('maps exception to CacheFailure', () async {
    final repo = MushafImageRepositoryImpl(
      dataSource: _StubDataSource(Exception('boom')),
    );
    final result = await repo.getPage(99);
    expect(result, isA<Left<Failure, dynamic>>());
    result.fold(
      (f) => expect(f, isA<CacheFailure>()),
      (_) => fail('expected left'),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/surah/data/repositories/mushaf_image_repo_impl_test.dart`
Expected: FAIL with "Target of URI doesn't exist".

- [ ] **Step 3: Implement the repository interface and impl**

`lib/features/surah/domain/repositories/mushaf_image_repo.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/mushaf_page_image_entity.dart';

abstract class MushafImageRepository {
  Future<Either<Failure, MushafPageImageEntity>> getPage(int pageNumber);
}
```

`lib/features/surah/data/repositories/mushaf_image_repo_impl.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/mushaf_page_image_entity.dart';
import '../../domain/repositories/mushaf_image_repo.dart';
import '../datasources/mushaf_image_local_data_source.dart';

class MushafImageRepositoryImpl implements MushafImageRepository {
  MushafImageRepositoryImpl({required this.dataSource});
  final MushafImageLocalDataSource dataSource;

  @override
  Future<Either<Failure, MushafPageImageEntity>> getPage(int pageNumber) async {
    try {
      final model = await dataSource.getPage(pageNumber);
      return Right(model);
    } catch (e) {
      return Left(CacheFailure(message: 'failed to load page $pageNumber: $e'));
    }
  }
}
```

If `CacheFailure` takes different constructor args than `message: String`, open `lib/core/errors/failure.dart` and match its actual signature. (Existing failures use a `message` string in this project.)

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/surah/data/repositories/mushaf_image_repo_impl_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/domain/repositories/mushaf_image_repo.dart lib/features/surah/data/repositories/mushaf_image_repo_impl.dart test/features/surah/data/repositories/mushaf_image_repo_impl_test.dart
git commit -m "feat(mushaf): add MushafImageRepository + impl with Either<Failure, T>"
```

---

### Task 8: Use case — `GetMushafPageImage`

**Files:**
- Create: `lib/features/surah/domain/usecases/get_mushaf_page_image.dart`
- Test: `test/features/surah/domain/usecases/get_mushaf_page_image_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/surah/domain/usecases/get_mushaf_page_image_test.dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_image_entity.dart';
import 'package:quran_app/features/surah/domain/repositories/mushaf_image_repo.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page_image.dart';

class _StubRepo implements MushafImageRepository {
  _StubRepo(this._result);
  final Either<Failure, MushafPageImageEntity> _result;
  @override
  Future<Either<Failure, MushafPageImageEntity>> getPage(int _) async => _result;
}

void main() {
  test('forwards page number to repository', () async {
    const entity =
        MushafPageImageEntity(pageNumber: 7, ayahs: []);
    final useCase = GetMushafPageImage(_StubRepo(const Right(entity)));
    final result = await useCase(7);
    result.fold((_) => fail('expected right'),
        (e) => expect(e.pageNumber, 7));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/surah/domain/usecases/get_mushaf_page_image_test.dart`
Expected: FAIL with "Target of URI doesn't exist".

- [ ] **Step 3: Implement the use case**

`lib/features/surah/domain/usecases/get_mushaf_page_image.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/mushaf_page_image_entity.dart';
import '../repositories/mushaf_image_repo.dart';

class GetMushafPageImage {
  GetMushafPageImage(this.repository);
  final MushafImageRepository repository;

  Future<Either<Failure, MushafPageImageEntity>> call(int pageNumber) {
    return repository.getPage(pageNumber);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/surah/domain/usecases/get_mushaf_page_image_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/domain/usecases/get_mushaf_page_image.dart test/features/surah/domain/usecases/get_mushaf_page_image_test.dart
git commit -m "feat(mushaf): add GetMushafPageImage use case"
```

---

## Phase 3: New Presentation Layer (behind debug route)

### Task 9: New cubit state — `MushafImageState`

**Files:**
- Create: `lib/features/surah/presentation/cubit/mushaf_image/mushaf_image_state.dart`

- [ ] **Step 1: Write the state class** (no test — state is data-only, exercised by cubit tests in Task 10)

`lib/features/surah/presentation/cubit/mushaf_image/mushaf_image_state.dart`:

```dart
import 'package:equatable/equatable.dart';

import '../../../../quran_playback/domain/entities/ayah_identifier.dart';

class MushafImageState extends Equatable {
  final int currentPage;
  final AyahIdentifier? highlightedAyah;
  final AyahIdentifier? playingAyah;

  const MushafImageState({
    required this.currentPage,
    this.highlightedAyah,
    this.playingAyah,
  });

  factory MushafImageState.initial(int page) =>
      MushafImageState(currentPage: page);

  MushafImageState copyWith({
    int? currentPage,
    AyahIdentifier? highlightedAyah,
    AyahIdentifier? playingAyah,
    bool clearHighlighted = false,
    bool clearPlaying = false,
  }) {
    return MushafImageState(
      currentPage: currentPage ?? this.currentPage,
      highlightedAyah: clearHighlighted ? null : (highlightedAyah ?? this.highlightedAyah),
      playingAyah: clearPlaying ? null : (playingAyah ?? this.playingAyah),
    );
  }

  @override
  List<Object?> get props => [currentPage, highlightedAyah, playingAyah];
}
```

If `AyahIdentifier` does not yet implement `==` / `hashCode`, add an `Equatable` mixin or override there. Verify by reading `lib/features/quran_playback/domain/entities/ayah_identifier.dart` — if it currently is a plain class with `final int surah, ayah`, extend it to override `==` and `hashCode` so equality comparisons in state work:

```dart
// lib/features/quran_playback/domain/entities/ayah_identifier.dart
class AyahIdentifier {
  final int surah;
  final int ayah;

  const AyahIdentifier({required this.surah, required this.ayah});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AyahIdentifier && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);
}
```

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze lib/features/surah/presentation/cubit/mushaf_image/mushaf_image_state.dart`
Expected: zero issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/surah/presentation/cubit/mushaf_image/mushaf_image_state.dart lib/features/quran_playback/domain/entities/ayah_identifier.dart
git commit -m "feat(mushaf): add MushafImageState (+ AyahIdentifier equality)"
```

---

### Task 10: `MushafImageCubit` with `setPage`, `toggleHighlight`, and `PlaybackCubit` bridge

**Files:**
- Create: `lib/features/surah/presentation/cubit/mushaf_image/mushaf_image_cubit.dart`
- Test: `test/features/surah/presentation/cubit/mushaf_image/mushaf_image_cubit_test.dart`

The cubit subscribes to the existing `CurrentAyahNotifier` (which is itself a `ValueNotifier<AyahIdentifier?>` already wired to `PlaybackCubit`) — it doesn't talk to `PlaybackCubit` directly.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/surah/presentation/cubit/mushaf_image/mushaf_image_cubit_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf_image/mushaf_image_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf_image/mushaf_image_state.dart';

class _FakeNotifier extends ValueNotifier<AyahIdentifier?> {
  _FakeNotifier() : super(null);
}

MushafImageCubit _buildCubit(_FakeNotifier n, {int initialPage = 1}) =>
    MushafImageCubit(initialPage: initialPage, currentAyahNotifier: n);

void main() {
  group('MushafImageCubit', () {
    blocTest<MushafImageCubit, MushafImageState>(
      'setPage updates currentPage and clears highlight',
      build: () => _buildCubit(_FakeNotifier())
        ..toggleHighlight(const AyahIdentifier(surah: 1, ayah: 1)),
      act: (c) => c.setPage(5),
      expect: () => [
        const MushafImageState(currentPage: 5),
      ],
    );

    blocTest<MushafImageCubit, MushafImageState>(
      'toggleHighlight sets when null',
      build: () => _buildCubit(_FakeNotifier()),
      act: (c) => c.toggleHighlight(const AyahIdentifier(surah: 2, ayah: 3)),
      expect: () => [
        const MushafImageState(
          currentPage: 1,
          highlightedAyah: AyahIdentifier(surah: 2, ayah: 3),
        ),
      ],
    );

    blocTest<MushafImageCubit, MushafImageState>(
      'toggleHighlight clears when same key',
      build: () => _buildCubit(_FakeNotifier())
        ..toggleHighlight(const AyahIdentifier(surah: 2, ayah: 3)),
      act: (c) => c.toggleHighlight(const AyahIdentifier(surah: 2, ayah: 3)),
      expect: () => [
        const MushafImageState(currentPage: 1),
      ],
    );

    blocTest<MushafImageCubit, MushafImageState>(
      'toggleHighlight replaces when different key',
      build: () => _buildCubit(_FakeNotifier())
        ..toggleHighlight(const AyahIdentifier(surah: 2, ayah: 3)),
      act: (c) => c.toggleHighlight(const AyahIdentifier(surah: 2, ayah: 4)),
      expect: () => [
        const MushafImageState(
          currentPage: 1,
          highlightedAyah: AyahIdentifier(surah: 2, ayah: 4),
        ),
      ],
    );

    blocTest<MushafImageCubit, MushafImageState>(
      'updates playingAyah when CurrentAyahNotifier emits',
      build: () {
        final n = _FakeNotifier();
        return _buildCubit(n);
      },
      act: (c) {
        // The notifier is captured by closure of build(); reach it via
        // the cubit's own reference for the test.
        c.debugNotifier.value = const AyahIdentifier(surah: 5, ayah: 7);
      },
      expect: () => [
        const MushafImageState(
          currentPage: 1,
          playingAyah: AyahIdentifier(surah: 5, ayah: 7),
        ),
      ],
    );

    blocTest<MushafImageCubit, MushafImageState>(
      'clears playingAyah when CurrentAyahNotifier emits null',
      build: () {
        final n = _FakeNotifier()..value = const AyahIdentifier(surah: 5, ayah: 7);
        return _buildCubit(n);
      },
      act: (c) {
        c.debugNotifier.value = null;
      },
      expect: () => [
        const MushafImageState(currentPage: 1),
      ],
    );
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/surah/presentation/cubit/mushaf_image/mushaf_image_cubit_test.dart`
Expected: FAIL with "Target of URI doesn't exist".

- [ ] **Step 3: Implement the cubit**

`lib/features/surah/presentation/cubit/mushaf_image/mushaf_image_cubit.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../utils/current_ayah_notifier.dart';
import 'mushaf_image_state.dart';

class MushafImageCubit extends Cubit<MushafImageState> {
  MushafImageCubit({
    required int initialPage,
    required ValueNotifier<AyahIdentifier?> currentAyahNotifier,
  })  : _notifier = currentAyahNotifier,
        super(MushafImageState.initial(initialPage)) {
    _notifier.addListener(_onPlayingAyahChanged);
    _onPlayingAyahChanged();
  }

  final ValueNotifier<AyahIdentifier?> _notifier;

  /// Test-only accessor for the underlying playback notifier.
  @visibleForTesting
  ValueNotifier<AyahIdentifier?> get debugNotifier => _notifier;

  void setPage(int page) {
    emit(state.copyWith(currentPage: page, clearHighlighted: true));
  }

  void toggleHighlight(AyahIdentifier ayah) {
    if (state.highlightedAyah == ayah) {
      emit(state.copyWith(clearHighlighted: true));
    } else {
      emit(state.copyWith(highlightedAyah: ayah));
    }
  }

  void _onPlayingAyahChanged() {
    final next = _notifier.value;
    if (next == null) {
      if (state.playingAyah != null) emit(state.copyWith(clearPlaying: true));
    } else {
      if (state.playingAyah != next) emit(state.copyWith(playingAyah: next));
    }
  }

  @override
  Future<void> close() {
    _notifier.removeListener(_onPlayingAyahChanged);
    return super.close();
  }
}
```

The constructor takes `ValueNotifier<AyahIdentifier?>` (not the concrete `CurrentAyahNotifier`) so tests can pass a fake. Production DI will inject the registered `CurrentAyahNotifier` singleton (which is also a `ValueNotifier<AyahIdentifier?>`).

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/surah/presentation/cubit/mushaf_image/mushaf_image_cubit_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/cubit/mushaf_image/mushaf_image_cubit.dart test/features/surah/presentation/cubit/mushaf_image/mushaf_image_cubit_test.dart
git commit -m "feat(mushaf): add MushafImageCubit with CurrentAyahNotifier bridge"
```

---

### Task 11: `AyahHighlightPainter` — `CustomPainter` for the highlight overlay

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf_image/widgets/ayah_highlight_painter.dart`

- [ ] **Step 1: Implement the painter**

`lib/features/surah/presentation/pages/mushaf_image/widgets/ayah_highlight_painter.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../domain/entities/ayah_bound_entity.dart';
import '../../../../domain/entities/normalized_rect.dart';

class AyahHighlightPainter extends CustomPainter {
  AyahHighlightPainter({
    required this.ayahs,
    required this.highlightedAyah,
    required this.playingAyah,
    required this.highlightColor,
    required this.playingColor,
    required this.animationValue,
  });

  final List<AyahBoundEntity> ayahs;
  final AyahIdentifier? highlightedAyah;
  final AyahIdentifier? playingAyah;
  final Color highlightColor;
  final Color playingColor;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (playingAyah != null) {
      _paintFor(canvas, size, playingAyah!, playingColor.withOpacity(0.15 * animationValue));
    }
    if (highlightedAyah != null) {
      _paintFor(canvas, size, highlightedAyah!, highlightColor.withOpacity(0.25 * animationValue));
    }
  }

  void _paintFor(Canvas canvas, Size size, AyahIdentifier key, Color color) {
    final paint = Paint()..color = color;
    for (final bound in ayahs) {
      if (bound.ayah != key) continue;
      for (final r in bound.lines) {
        final rect = _denormalize(r, size);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          paint,
        );
      }
    }
  }

  Rect _denormalize(NormalizedRect r, Size size) {
    return Rect.fromLTWH(
      r.x * size.width,
      r.y * size.height,
      r.w * size.width,
      r.h * size.height,
    );
  }

  @override
  bool shouldRepaint(AyahHighlightPainter old) {
    return old.highlightedAyah != highlightedAyah ||
        old.playingAyah != playingAyah ||
        old.animationValue != animationValue ||
        old.highlightColor != highlightColor ||
        old.playingColor != playingColor ||
        !identical(old.ayahs, ayahs);
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze lib/features/surah/presentation/pages/mushaf_image/widgets/ayah_highlight_painter.dart`
Expected: zero issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf_image/widgets/ayah_highlight_painter.dart
git commit -m "feat(mushaf): add AyahHighlightPainter (lerped overlay)"
```

---

### Task 12: `MushafPageView` widget — image + painter + single-gesture hit-test

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf_image/widgets/mushaf_page_view.dart`

- [ ] **Step 1: Implement the widget**

`lib/features/surah/presentation/pages/mushaf_image/widgets/mushaf_page_view.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../../core/di/dependency_injection.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../domain/entities/ayah_bound_entity.dart';
import '../../../../domain/entities/mushaf_page_image_entity.dart';
import '../../../../domain/usecases/get_mushaf_page_image.dart';
import '../../../cubit/mushaf_image/mushaf_image_cubit.dart';
import '../../../cubit/mushaf_image/mushaf_image_state.dart';
import 'ayah_action_sheet.dart';
import 'ayah_highlight_painter.dart';

class MushafPageView extends StatefulWidget {
  const MushafPageView({super.key, required this.pageNumber});

  final int pageNumber;

  @override
  State<MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends State<MushafPageView>
    with SingleTickerProviderStateMixin {
  late final Future<MushafPageImageEntity> _entityFuture;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _entityFuture = sl<GetMushafPageImage>()(widget.pageNumber).then((e) {
      return e.fold<MushafPageImageEntity>(
        (f) => throw StateError('failed to load page ${widget.pageNumber}: $f'),
        (right) => right,
      );
    });
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _imagePath =>
      'assets/mushaf/pages/page_${widget.pageNumber.toString().padLeft(3, '0')}.png';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MushafPageImageEntity>(
      future: _entityFuture,
      builder: (context, snapshot) {
        final entity = snapshot.data;
        return AspectRatio(
          aspectRatio: 1 / 1.82,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _imagePath,
                    color: Theme.of(context).colorScheme.onSurface,
                    colorBlendMode: BlendMode.srcIn,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    fit: BoxFit.fill,
                  ),
                  if (entity != null)
                    BlocBuilder<MushafImageCubit, MushafImageState>(
                      buildWhen: (a, b) =>
                          a.highlightedAyah != b.highlightedAyah ||
                          a.playingAyah != b.playingAyah,
                      builder: (context, state) {
                        // Trigger fade-in when a highlight appears.
                        if (state.highlightedAyah != null ||
                            state.playingAyah != null) {
                          _controller.forward(from: 0);
                        }
                        return AnimatedBuilder(
                          animation: _controller,
                          builder: (_, __) => CustomPaint(
                            painter: AyahHighlightPainter(
                              ayahs: entity.ayahs,
                              highlightedAyah: state.highlightedAyah,
                              playingAyah: state.playingAyah,
                              highlightColor: Theme.of(context).colorScheme.secondary,
                              playingColor: Theme.of(context).colorScheme.primary,
                              animationValue: _controller.value,
                            ),
                          ),
                        );
                      },
                    ),
                  if (entity != null)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) => _handleTap(context, details.localPosition, constraints, entity.ayahs),
                        onLongPressStart: (details) => _handleLongPress(context, details.localPosition, constraints, entity.ayahs),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  AyahIdentifier? _hitTest(Offset local, BoxConstraints c, List<AyahBoundEntity> ayahs) {
    final nx = local.dx / c.maxWidth;
    final ny = local.dy / c.maxHeight;
    for (final bound in ayahs) {
      for (final r in bound.lines) {
        if (nx >= r.x && nx <= r.x + r.w && ny >= r.y && ny <= r.y + r.h) {
          return bound.ayah;
        }
      }
    }
    return null;
  }

  void _handleTap(BuildContext context, Offset local, BoxConstraints c, List<AyahBoundEntity> ayahs) {
    final hit = _hitTest(local, c, ayahs);
    if (hit != null) context.read<MushafImageCubit>().toggleHighlight(hit);
  }

  void _handleLongPress(BuildContext context, Offset local, BoxConstraints c, List<AyahBoundEntity> ayahs) {
    final hit = _hitTest(local, c, ayahs);
    if (hit == null) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => AyahActionSheet(ayah: hit),
    );
  }
}
```

- [ ] **Step 2: Verify compilation (will fail on AyahActionSheet import — that's expected, next task)**

Run: `flutter analyze lib/features/surah/presentation/pages/mushaf_image/widgets/mushaf_page_view.dart`
Expected: ONE error pointing at the missing `ayah_action_sheet.dart` import. All other issues should be zero. If anything else is flagged, fix before continuing.

- [ ] **Step 3: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf_image/widgets/mushaf_page_view.dart
git commit -m "feat(mushaf): add MushafPageView widget (image + highlight overlay + hit-test)"
```

---

### Task 13: `AyahActionSheet` widget (long-press menu)

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf_image/widgets/ayah_action_sheet.dart`

- [ ] **Step 1: Implement the action sheet**

`lib/features/surah/presentation/pages/mushaf_image/widgets/ayah_action_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quran/quran.dart' as quran;

import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';

class AyahActionSheet extends StatelessWidget {
  const AyahActionSheet({super.key, required this.ayah});

  final AyahIdentifier ayah;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Play from here'),
            onTap: () => Navigator.of(context).pop(_Action.play),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book),
            title: const Text('Tafsir'),
            onTap: () => Navigator.of(context).pop(_Action.tafsir),
          ),
          ListTile(
            leading: const Icon(Icons.bookmark_border),
            title: const Text('Bookmark'),
            onTap: () => Navigator.of(context).pop(_Action.bookmark),
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy'),
            onTap: () async {
              final text = quran.getVerse(ayah.surah, ayah.ayah);
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) Navigator.of(context).pop(_Action.copy);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share'),
            onTap: () => Navigator.of(context).pop(_Action.share),
          ),
        ],
      ),
    );
  }
}

enum _Action { play, tafsir, bookmark, copy, share }
```

The visible strings (`Play from here`, etc.) will be localized in a follow-up — for this plan we ship English-only labels and migrate to `S.of(context)` as part of the bookmark/tafsir/share wiring task (intentionally out of scope here, see the spec's "Open questions / deferred" section).

- [ ] **Step 2: Verify compilation of both files together**

Run: `flutter analyze lib/features/surah/presentation/pages/mushaf_image/`
Expected: zero issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf_image/widgets/ayah_action_sheet.dart
git commit -m "feat(mushaf): add AyahActionSheet (long-press menu, English placeholder labels)"
```

---

### Task 14: Page-number text overlay widget

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf_image/widgets/mushaf_page_number_text.dart`

- [ ] **Step 1: Implement the overlay**

`lib/features/surah/presentation/pages/mushaf_image/widgets/mushaf_page_number_text.dart`:

```dart
import 'package:flutter/material.dart';

class MushafPageNumberText extends StatelessWidget {
  const MushafPageNumberText({super.key, required this.pageNumber});

  final int pageNumber;

  static const _digits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  String get _arabic =>
      pageNumber.toString().split('').map((c) => _digits[int.parse(c)]).join();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        _arabic,
        locale: const Locale('ar'),
        style: TextStyle(
          fontSize: 16,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze lib/features/surah/presentation/pages/mushaf_image/widgets/mushaf_page_number_text.dart`
Expected: zero issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf_image/widgets/mushaf_page_number_text.dart
git commit -m "feat(mushaf): add page-number overlay with Eastern Arabic digits"
```

---

### Task 15: `MushafImagePage` screen (PageView + page-number overlay)

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf_image/mushaf_image_page.dart`

- [ ] **Step 1: Implement the page**

`lib/features/surah/presentation/pages/mushaf_image/mushaf_image_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../cubit/mushaf_image/mushaf_image_cubit.dart';
import '../../cubit/mushaf_image/mushaf_image_state.dart';
import 'widgets/mushaf_page_number_text.dart';
import 'widgets/mushaf_page_view.dart';

class MushafImagePage extends StatefulWidget {
  const MushafImagePage({super.key, required this.initialPage});
  final int initialPage;

  @override
  State<MushafImagePage> createState() => _MushafImagePageState();
}

class _MushafImagePageState extends State<MushafImagePage> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    // RTL paging: index 0 = page 604, index 603 = page 1.
    _controller = PageController(initialPage: 604 - widget.initialPage);
    _controller.addListener(_precacheNeighbours);
  }

  @override
  void dispose() {
    _controller.removeListener(_precacheNeighbours);
    _controller.dispose();
    super.dispose();
  }

  int _pageNumberFor(int index) => 604 - index;

  void _precacheNeighbours() {
    final idx = _controller.page?.round();
    if (idx == null) return;
    for (final neighbour in [idx - 1, idx + 1]) {
      if (neighbour < 0 || neighbour > 603) continue;
      final page = _pageNumberFor(neighbour);
      precacheImage(
        AssetImage('assets/mushaf/pages/page_${page.toString().padLeft(3, '0')}.png'),
        context,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: 604,
                onPageChanged: (i) =>
                    context.read<MushafImageCubit>().setPage(_pageNumberFor(i)),
                itemBuilder: (_, i) => MushafPageView(pageNumber: _pageNumberFor(i)),
              ),
            ),
            BlocBuilder<MushafImageCubit, MushafImageState>(
              buildWhen: (a, b) => a.currentPage != b.currentPage,
              builder: (context, state) =>
                  MushafPageNumberText(pageNumber: state.currentPage),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify compilation**

Run: `flutter analyze lib/features/surah/presentation/pages/mushaf_image/`
Expected: zero issues.

- [ ] **Step 3: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf_image/mushaf_image_page.dart
git commit -m "feat(mushaf): add MushafImagePage screen with RTL PageView + neighbour precache"
```

---

### Task 16: DI registration for the new image-rendering stack

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf_image/mushaf_image_di.dart`
- Modify: `lib/core/di/dependency_injection.dart` (add `initMushafImage();` call)

- [ ] **Step 1: Write the DI module**

`lib/features/surah/presentation/pages/mushaf_image/mushaf_image_di.dart`:

```dart
import '../../../../../core/di/dependency_injection.dart';

import '../../../data/datasources/mushaf_image_local_data_source.dart';
import '../../../data/repositories/mushaf_image_repo_impl.dart';
import '../../../domain/repositories/mushaf_image_repo.dart';
import '../../../domain/usecases/get_mushaf_page_image.dart';
import '../../cubit/mushaf_image/mushaf_image_cubit.dart';
import '../../utils/current_ayah_notifier.dart';

void initMushafImage() {
  sl.registerLazySingleton<MushafImageLocalDataSource>(
    () => MushafImageLocalDataSource(),
  );
  sl.registerLazySingleton<MushafImageRepository>(
    () => MushafImageRepositoryImpl(dataSource: sl()),
  );
  sl.registerLazySingleton(() => GetMushafPageImage(sl()));
  sl.registerFactoryParam<MushafImageCubit, int, void>(
    (initialPage, _) => MushafImageCubit(
      initialPage: initialPage,
      currentAyahNotifier: sl<CurrentAyahNotifier>(),
    ),
  );
}
```

`CurrentAyahNotifier` is already registered as a `LazySingleton` in the existing `initMushaf()` (see `lib/features/surah/presentation/pages/mushaf/mushaf_di.dart`). Until Phase 5 deletes that file, both DI modules coexist and the notifier is registered exactly once.

- [ ] **Step 2: Wire it into `dependency_injection.dart`**

Open `lib/core/di/dependency_injection.dart` and find the section that calls `initMushaf()` (or similar). Add a call to `initMushafImage()` right after it:

```dart
// existing imports...
import '../../features/surah/presentation/pages/mushaf_image/mushaf_image_di.dart';

void setupDependencies() {
  // ...
  initMushaf();
  initMushafImage(); // <-- add this line
  // ...
}
```

(Adapt the import path / function name to match the file's actual structure.)

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze`
Expected: zero issues.

- [ ] **Step 4: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf_image/mushaf_image_di.dart lib/core/di/dependency_injection.dart
git commit -m "chore(mushaf): register image-rendering stack with GetIt"
```

---

### Task 17: Debug route for side-by-side comparison

**Files:**
- Modify: `lib/config/router/app_router.dart`

- [ ] **Step 1: Add a debug route**

Open `lib/config/router/app_router.dart`. Add the imports at the top:

```dart
import 'package:quran_app/features/surah/presentation/pages/mushaf_image/mushaf_image_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf_image/mushaf_image_cubit.dart';
```

Add a path constant alongside the others:

```dart
static const String mushafImagePath = "/mushafImage";
```

Add a route entry inside the `routes: [ ... ]` list, beside the existing `mushafPath` route:

```dart
GoRoute(
  path: mushafImagePath,
  pageBuilder: GoTransitions.fade.withFade.build(
    builder: (context, state) {
      final int pageNo = (state.extra as int?) ?? 1;
      return BlocProvider(
        create: (_) => sl<MushafImageCubit>().call(param1: pageNo),
        child: MushafImagePage(initialPage: pageNo),
      );
    },
  ),
),
```

Note: GetIt's `registerFactoryParam` is invoked as `sl<T>(param1: …)` in the `get_it` API — match the project's usage style if `sl<T>(param1: …)` syntax differs.

- [ ] **Step 2: Add a temporary debug entry-point in HomePage to navigate to `/mushafImage`**

This is exploratory — pick any visible-on-screen control (e.g., long-press the existing mushaf button, or a debug-only `FloatingActionButton`) and have it call `context.push('/mushafImage', extra: 1)`. The exact placement is at the implementer's discretion; the goal is to be able to manually launch the new screen on real device.

- [ ] **Step 3: Run the app on a real device or emulator and verify**

Run: `flutter run` (or the project's preferred run command)

Manual verification checklist:
- Open `/mushafImage` → page 1 visible, surah name centered in header band.
- Swipe right → page 2 visible (Al-Baqarah start, header + basmala + 5 ayahs). No first-swipe lag.
- Swipe forward several pages → all render correctly, no stutter.
- Tap an ayah → highlight appears, animates in.
- Tap same ayah again → highlight clears.
- Long-press an ayah → bottom sheet opens with the 5 actions.
- Toggle theme (light/dark) → ink color updates instantly without re-decoding the image.
- Page number at bottom shows correct Eastern Arabic digit for current page.

- [ ] **Step 4: Commit**

```bash
git add lib/config/router/app_router.dart lib/features/home/presentation/pages/home_page.dart
git commit -m "feat(mushaf): add /mushafImage debug route for side-by-side comparison"
```

(Adapt the `home_page.dart` path to wherever you added the debug entry point.)

---

## Phase 4: Cutover

### Task 18: Swap the production `/mushaf` route to use `MushafImagePage`

**Files:**
- Modify: `lib/config/router/app_router.dart`

- [ ] **Step 1: Update the `/mushaf` route's builder**

In `lib/config/router/app_router.dart`, find the existing route:

```dart
GoRoute(
  path: mushafPath,
  pageBuilder: GoTransitions.fade.withFade.build(
    builder: (context, state) {
      final int pageNo = (state.extra as int?) ?? 1;
      return BlocProvider.value(
        value: sl<PlaybackCubit>(),
        child: MushafPage(pageNumber: pageNo),
      );
    },
  ),
),
```

Replace its `builder` body so it constructs the new screen:

```dart
GoRoute(
  path: mushafPath,
  pageBuilder: GoTransitions.fade.withFade.build(
    builder: (context, state) {
      final int pageNo = (state.extra as int?) ?? 1;
      return MultiBlocProvider(
        providers: [
          BlocProvider.value(value: sl<PlaybackCubit>()),
          BlocProvider(create: (_) => sl<MushafImageCubit>(param1: pageNo)),
        ],
        child: MushafImagePage(initialPage: pageNo),
      );
    },
  ),
),
```

Add the missing imports at the top:

```dart
import 'package:quran_app/features/surah/presentation/pages/mushaf_image/mushaf_image_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf_image/mushaf_image_cubit.dart';
```

The unused `MushafPage` import from `mushaf_pages.dart` can stay until Phase 5 (it's still referenced by Phase-5 deletion work).

- [ ] **Step 2: Verify the app builds and the production route works**

Run: `flutter analyze` → expected: zero issues.
Run: `flutter run` → from any production link to the mushaf, verify the new screen is what loads.

- [ ] **Step 3: Commit**

```bash
git add lib/config/router/app_router.dart
git commit -m "feat(mushaf): cut over /mushaf route to MushafImagePage"
```

---

## Phase 5: Cleanup — delete old code, rename `Image` suffixes away, strip QCF fonts

### Task 19: Delete the old text-rendering code

**Files (all deleted):**
- `lib/features/surah/data/datasources/mushaf_local_data_source.dart`
- `lib/features/surah/data/datasources/mushaf_page_cache.dart`
- `lib/features/surah/data/datasources/mushaf_spans_cache.dart`
- `lib/features/surah/data/repositories/mushaf_repo_impl.dart`
- `lib/features/surah/domain/entities/mushaf_page_entity.dart`
- `lib/features/surah/domain/repositories/mushaf_repo.dart`
- `lib/features/surah/domain/usecases/get_mushaf_page.dart`
- `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart`
- `lib/features/surah/presentation/cubit/mushaf/mushaf_state.dart`
- `lib/features/surah/presentation/pages/mushaf/mushaf_pages.dart`
- `lib/features/surah/presentation/pages/mushaf/mushaf_di.dart`
- `lib/features/surah/presentation/pages/mushaf/widgets/ayah_text_span_builder.dart`
- `lib/features/surah/presentation/pages/mushaf/widgets/basmala_text.dart`
- `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_layout.dart`
- `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_content.dart`
- `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_text.dart`
- `lib/features/surah/presentation/pages/mushaf/widgets/surah_header.dart`
- `test/spikes/render_page_spike_test.dart`
- `test/spikes/woff_to_ttf.dart`

- [ ] **Step 1: Move the `CurrentAyahNotifier` registration into the new DI module**

`CurrentAyahNotifier` lives in `lib/features/surah/presentation/utils/current_ayah_notifier.dart` (it is NOT deleted — the new cubit depends on it). Today it's registered in old `mushaf_di.dart`. Before deleting that file, port the registration into `mushaf_image_di.dart`:

```dart
// mushaf_image_di.dart — add this line at the top of initMushafImage()
import '../../../../../features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../utils/current_ayah_notifier.dart';

void initMushafImage() {
  sl.registerLazySingleton<CurrentAyahNotifier>(
    () => CurrentAyahNotifier(playbackCubit: sl<PlaybackCubit>()),
  );
  // ... existing registrations ...
}
```

- [ ] **Step 2: Remove the call to old `initMushaf()` from `dependency_injection.dart`**

Open `lib/core/di/dependency_injection.dart`. Remove the `initMushaf()` line and the corresponding import to `mushaf_di.dart`. Keep the `initMushafImage()` call.

- [ ] **Step 3: Delete the files**

```bash
rm -r lib/features/surah/presentation/pages/mushaf/
rm -r lib/features/surah/presentation/cubit/mushaf/
rm lib/features/surah/data/datasources/mushaf_local_data_source.dart
rm lib/features/surah/data/datasources/mushaf_page_cache.dart
rm lib/features/surah/data/datasources/mushaf_spans_cache.dart
rm lib/features/surah/data/repositories/mushaf_repo_impl.dart
rm lib/features/surah/domain/entities/mushaf_page_entity.dart
rm lib/features/surah/domain/repositories/mushaf_repo.dart
rm lib/features/surah/domain/usecases/get_mushaf_page.dart
rm -r test/spikes/
```

(On PowerShell: `Remove-Item -Recurse -Force <path>` per item.)

- [ ] **Step 4: Remove the leftover import from `app_router.dart`**

In `lib/config/router/app_router.dart`, remove:

```dart
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_pages.dart';
```

Also delete the debug `/mushafImage` route added in Task 17 — the production `/mushaf` route is now the only mushaf path needed.

- [ ] **Step 5: Verify compilation**

Run: `flutter analyze`
Expected: zero issues. If any unresolved references remain (e.g., from `home_page.dart`'s debug navigation), delete those references.

- [ ] **Step 6: Run the full test suite**

Run: `flutter test`
Expected: zero failures.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore(mushaf): remove text-rendering pipeline and debug route"
```

---

### Task 20: Rename `Image`-suffixed types to canonical names

**Files renamed (`Image` suffix dropped from class names, file names, and directory names):**

| Old path | New path |
|---|---|
| `lib/features/surah/domain/entities/mushaf_page_image_entity.dart` | `lib/features/surah/domain/entities/mushaf_page_entity.dart` |
| `lib/features/surah/data/models/mushaf_page_image_model.dart` | `lib/features/surah/data/models/mushaf_page_model.dart` |
| `lib/features/surah/data/datasources/mushaf_image_local_data_source.dart` | `lib/features/surah/data/datasources/mushaf_local_data_source.dart` |
| `lib/features/surah/domain/repositories/mushaf_image_repo.dart` | `lib/features/surah/domain/repositories/mushaf_repo.dart` |
| `lib/features/surah/data/repositories/mushaf_image_repo_impl.dart` | `lib/features/surah/data/repositories/mushaf_repo_impl.dart` |
| `lib/features/surah/domain/usecases/get_mushaf_page_image.dart` | `lib/features/surah/domain/usecases/get_mushaf_page.dart` |
| `lib/features/surah/presentation/cubit/mushaf_image/` (dir) | `lib/features/surah/presentation/cubit/mushaf/` |
| `lib/features/surah/presentation/cubit/mushaf_image/mushaf_image_state.dart` | `lib/features/surah/presentation/cubit/mushaf/mushaf_state.dart` |
| `lib/features/surah/presentation/cubit/mushaf_image/mushaf_image_cubit.dart` | `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart` |
| `lib/features/surah/presentation/pages/mushaf_image/` (dir) | `lib/features/surah/presentation/pages/mushaf/` |
| `lib/features/surah/presentation/pages/mushaf_image/mushaf_image_page.dart` | `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart` |
| `lib/features/surah/presentation/pages/mushaf_image/mushaf_image_di.dart` | `lib/features/surah/presentation/pages/mushaf/mushaf_di.dart` |

**Class renames:**

| Old class | New class |
|---|---|
| `MushafPageImageEntity` | `MushafPageEntity` |
| `MushafPageImageModel` | `MushafPageModel` |
| `MushafImageLocalDataSource` | `MushafLocalDataSource` |
| `MushafImageRepository` | `MushafRepository` |
| `MushafImageRepositoryImpl` | `MushafRepositoryImpl` |
| `GetMushafPageImage` | `GetMushafPage` |
| `MushafImageState` | `MushafState` |
| `MushafImageCubit` | `MushafCubit` |
| `MushafImagePage` | `MushafPage` |
| `initMushafImage` | `initMushaf` |

- [ ] **Step 1: Rename the files (preserve git history with `git mv`)**

```bash
git mv lib/features/surah/domain/entities/mushaf_page_image_entity.dart lib/features/surah/domain/entities/mushaf_page_entity.dart
git mv lib/features/surah/data/models/mushaf_page_image_model.dart lib/features/surah/data/models/mushaf_page_model.dart
git mv lib/features/surah/data/datasources/mushaf_image_local_data_source.dart lib/features/surah/data/datasources/mushaf_local_data_source.dart
git mv lib/features/surah/domain/repositories/mushaf_image_repo.dart lib/features/surah/domain/repositories/mushaf_repo.dart
git mv lib/features/surah/data/repositories/mushaf_image_repo_impl.dart lib/features/surah/data/repositories/mushaf_repo_impl.dart
git mv lib/features/surah/domain/usecases/get_mushaf_page_image.dart lib/features/surah/domain/usecases/get_mushaf_page.dart
git mv lib/features/surah/presentation/cubit/mushaf_image lib/features/surah/presentation/cubit/mushaf
git mv lib/features/surah/presentation/cubit/mushaf/mushaf_image_state.dart lib/features/surah/presentation/cubit/mushaf/mushaf_state.dart
git mv lib/features/surah/presentation/cubit/mushaf/mushaf_image_cubit.dart lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart
git mv lib/features/surah/presentation/pages/mushaf_image lib/features/surah/presentation/pages/mushaf
git mv lib/features/surah/presentation/pages/mushaf/mushaf_image_page.dart lib/features/surah/presentation/pages/mushaf/mushaf_page.dart
git mv lib/features/surah/presentation/pages/mushaf/mushaf_image_di.dart lib/features/surah/presentation/pages/mushaf/mushaf_di.dart
```

- [ ] **Step 2: Rename classes and identifiers across the codebase**

Find-and-replace each rename listed in the table above across `lib/`, `test/`, and `docs/superpowers/`. Use your editor's project-wide rename or:

```bash
# Run each pair against tracked Dart files. Order matters: longer names first to avoid
# accidentally matching a substring of a longer identifier.
grep -rl 'MushafPageImageEntity' lib test | xargs sed -i 's/MushafPageImageEntity/MushafPageEntity/g'
grep -rl 'MushafPageImageModel'  lib test | xargs sed -i 's/MushafPageImageModel/MushafPageModel/g'
grep -rl 'MushafImageLocalDataSource' lib test | xargs sed -i 's/MushafImageLocalDataSource/MushafLocalDataSource/g'
grep -rl 'MushafImageRepositoryImpl' lib test | xargs sed -i 's/MushafImageRepositoryImpl/MushafRepositoryImpl/g'
grep -rl 'MushafImageRepository' lib test | xargs sed -i 's/MushafImageRepository/MushafRepository/g'
grep -rl 'GetMushafPageImage' lib test | xargs sed -i 's/GetMushafPageImage/GetMushafPage/g'
grep -rl 'MushafImageState' lib test | xargs sed -i 's/MushafImageState/MushafState/g'
grep -rl 'MushafImageCubit' lib test | xargs sed -i 's/MushafImageCubit/MushafCubit/g'
grep -rl 'MushafImagePage' lib test | xargs sed -i 's/MushafImagePage/MushafPage/g'
grep -rl 'initMushafImage' lib test | xargs sed -i 's/initMushafImage/initMushaf/g'
```

On Windows PowerShell, equivalent:

```powershell
$pairs = @(
  @('MushafPageImageEntity','MushafPageEntity'),
  @('MushafPageImageModel','MushafPageModel'),
  @('MushafImageLocalDataSource','MushafLocalDataSource'),
  @('MushafImageRepositoryImpl','MushafRepositoryImpl'),
  @('MushafImageRepository','MushafRepository'),
  @('GetMushafPageImage','GetMushafPage'),
  @('MushafImageState','MushafState'),
  @('MushafImageCubit','MushafCubit'),
  @('MushafImagePage','MushafPage'),
  @('initMushafImage','initMushaf')
)
foreach ($p in $pairs) {
  Get-ChildItem -Recurse -Include *.dart lib,test |
    ForEach-Object {
      (Get-Content $_.FullName) -replace [regex]::Escape($p[0]), $p[1] |
        Set-Content -NoNewline $_.FullName
    }
}
```

- [ ] **Step 3: Update import paths that reference the renamed files**

Run a final pass to fix path references (only the file basenames changed; the directory layout largely stayed):

```bash
grep -rl 'mushaf_page_image_entity' lib test | xargs sed -i 's/mushaf_page_image_entity/mushaf_page_entity/g'
grep -rl 'mushaf_page_image_model' lib test | xargs sed -i 's/mushaf_page_image_model/mushaf_page_model/g'
grep -rl 'mushaf_image_local_data_source' lib test | xargs sed -i 's/mushaf_image_local_data_source/mushaf_local_data_source/g'
grep -rl 'mushaf_image_repo_impl' lib test | xargs sed -i 's/mushaf_image_repo_impl/mushaf_repo_impl/g'
grep -rl 'mushaf_image_repo' lib test | xargs sed -i 's/mushaf_image_repo/mushaf_repo/g'
grep -rl 'get_mushaf_page_image' lib test | xargs sed -i 's/get_mushaf_page_image/get_mushaf_page/g'
grep -rl 'mushaf_image_state' lib test | xargs sed -i 's/mushaf_image_state/mushaf_state/g'
grep -rl 'mushaf_image_cubit' lib test | xargs sed -i 's/mushaf_image_cubit/mushaf_cubit/g'
grep -rl 'mushaf_image_page' lib test | xargs sed -i 's/mushaf_image_page/mushaf_page/g'
grep -rl 'mushaf_image_di' lib test | xargs sed -i 's/mushaf_image_di/mushaf_di/g'
grep -rl 'cubit/mushaf_image/' lib test | xargs sed -i 's|cubit/mushaf_image/|cubit/mushaf/|g'
grep -rl 'pages/mushaf_image/' lib test | xargs sed -i 's|pages/mushaf_image/|pages/mushaf/|g'
```

(PowerShell-equivalent using the same loop pattern as Step 2.)

- [ ] **Step 4: Verify compilation**

Run: `flutter analyze`
Expected: zero issues.

- [ ] **Step 5: Run all tests**

Run: `flutter test`
Expected: all tests pass. Test file names still use `_image_` and can be renamed in this same step if desired (`git mv test/features/surah/...mushaf_page_image_...` → `mushaf_page_...`); use the same sed batch on test file names.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor(mushaf): rename Image-suffixed types to canonical names"
```

---

### Task 21: Strip QCF font registrations and add mushaf asset entries in `pubspec.yaml`

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 1: Remove all 605 QCF font entries**

Open `pubspec.yaml` and find the `fonts:` section under `flutter:`. Delete every entry whose `family:` starts with `QCF_P` (one for `QCF_P000` = `QCF2BSML.woff`, and 604 for `QCF_P001`..`QCF_P604`).

Also delete the `assets/fonts/QCF/` line from the `flutter.assets:` list if present — the fonts no longer ship with the app.

- [ ] **Step 2: Add new mushaf asset entries**

Under `flutter.assets:`, add:

```yaml
flutter:
  assets:
    # ... existing entries ...
    - assets/mushaf/pages/
    - assets/mushaf/bounds/
```

- [ ] **Step 3: Verify the bundle builds and ships the assets**

Run: `flutter pub get`
Expected: clean exit.

Run: `flutter build apk --debug` (or `flutter build ios --debug`)
Expected: build succeeds. Confirm the resulting APK/IPA does not contain `assets/fonts/QCF/` and does contain `assets/mushaf/pages/page_604.png`.

- [ ] **Step 4: Run the app and verify mushaf still renders**

Run: `flutter run`

Manual checks:
- Open mushaf from production link → first page visible, swipe works.
- Theme switch → tint updates.
- Tap/long-press ayah → interactions still work.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml
git commit -m "chore(mushaf): drop 604 QCF fonts, register assets/mushaf/* asset entries"
```

---

### Task 22: Golden tests for tinted page rendering

**Files:**
- Create: `test/features/surah/presentation/pages/mushaf/mushaf_page_view_golden_test.dart`
- Create: `test/features/surah/presentation/pages/mushaf/goldens/page_002_light.png` (auto-generated on first run)
- Create: `test/features/surah/presentation/pages/mushaf/goldens/page_002_dark.png`
- Create: `test/features/surah/presentation/pages/mushaf/goldens/page_100_light.png`
- Create: `test/features/surah/presentation/pages/mushaf/goldens/page_100_dark.png`

- [ ] **Step 1: Write the golden test**

```dart
// test/features/surah/presentation/pages/mushaf/mushaf_page_view_golden_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_di.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart';

Widget _harness(Widget child, {required Brightness brightness}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: BlocProvider(
      create: (_) => MushafCubit(initialPage: 2),
      child: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  setUpAll(() {
    if (!GetIt.I.isRegistered<MushafCubit>()) {
      initMushaf();
    }
  });

  testWidgets('page 2 renders correctly in light theme', (tester) async {
    await tester.pumpWidget(_harness(
      const MushafPageView(pageNumber: 2),
      brightness: Brightness.light,
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MushafPageView),
      matchesGoldenFile('goldens/page_002_light.png'),
    );
  });

  testWidgets('page 2 renders correctly in dark theme', (tester) async {
    await tester.pumpWidget(_harness(
      const MushafPageView(pageNumber: 2),
      brightness: Brightness.dark,
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MushafPageView),
      matchesGoldenFile('goldens/page_002_dark.png'),
    );
  });

  testWidgets('page 100 renders correctly in light theme', (tester) async {
    await tester.pumpWidget(_harness(
      const MushafPageView(pageNumber: 100),
      brightness: Brightness.light,
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MushafPageView),
      matchesGoldenFile('goldens/page_100_light.png'),
    );
  });

  testWidgets('page 100 renders correctly in dark theme', (tester) async {
    await tester.pumpWidget(_harness(
      const MushafPageView(pageNumber: 100),
      brightness: Brightness.dark,
    ));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MushafPageView),
      matchesGoldenFile('goldens/page_100_dark.png'),
    );
  });
}
```

- [ ] **Step 2: Generate the golden files**

Run: `flutter test --update-goldens test/features/surah/presentation/pages/mushaf/mushaf_page_view_golden_test.dart`

Expected: 4 PNG files created under `test/features/surah/presentation/pages/mushaf/goldens/`. Manually inspect each to confirm correct rendering (header on page 2, vanilla page on 100, dark mode shows light ink on dark background).

- [ ] **Step 3: Re-run without `--update-goldens` to confirm idempotency**

Run: `flutter test test/features/surah/presentation/pages/mushaf/mushaf_page_view_golden_test.dart`
Expected: `+4: All tests passed!`

- [ ] **Step 4: Commit**

```bash
git add test/features/surah/presentation/pages/mushaf/
git commit -m "test(mushaf): golden tests for tinted page rendering (light + dark)"
```

---

### Task 23: Final verification

**Files:** none

- [ ] **Step 1: Full analyze**

Run: `flutter analyze`
Expected: zero issues.

- [ ] **Step 2: Full test suite**

Run: `flutter test`
Expected: all tests pass.

- [ ] **Step 3: Manual smoke**

Run: `flutter run`

Confirm:
- Cold launch → mushaf opens on last-read page.
- Swipe forward to a never-seen page → no perceptible lag.
- Tap → highlight; tap same → clear.
- Long-press → action sheet.
- Light/dark theme switch is immediate.
- Page number shows correct Eastern Arabic digits.
- Playback (if wired) shows the playing-ayah underlay.

- [ ] **Step 4: Verify QCF fonts are gone from the bundle**

Run: `flutter build apk --debug && unzip -l build/app/outputs/flutter-apk/app-debug.apk | grep -E 'QCF|mushaf'`

Expected: zero `QCF` lines, hundreds of `assets/mushaf/...` lines.

- [ ] **Step 5: Final commit (only if Steps 1-4 produced any incidental cleanups)**

```bash
git status
# if anything changed:
git add -A
git commit -m "chore(mushaf): final cleanup after image-rendering cutover"
```

---

## Summary of expected commits

After executing this plan you should have roughly 23 commits on the branch:

1. `feat(mushaf): add 604-page asset generator (test/tools/)`
2. `feat(mushaf): generate 604 page PNGs and ayah-bounds JSON`
3. `test(mushaf): verify (surah, ayah) coverage across all 604 pages`
4. `feat(mushaf): add image-rendering domain entities`
5. `feat(mushaf): add MushafPageImageModel JSON parsing`
6. `feat(mushaf): add MushafImageLocalDataSource (rootBundle + in-memory cache)`
7. `feat(mushaf): add MushafImageRepository + impl with Either<Failure, T>`
8. `feat(mushaf): add GetMushafPageImage use case`
9. `feat(mushaf): add MushafImageState (+ AyahIdentifier equality)`
10. `feat(mushaf): add MushafImageCubit (setPage, toggleHighlight, setPlayingAyah)`
11. `feat(mushaf): add AyahHighlightPainter (lerped overlay)`
12. `feat(mushaf): add MushafPageView widget (image + highlight overlay + hit-test)`
13. `feat(mushaf): add AyahActionSheet (long-press menu, English placeholder labels)`
14. `feat(mushaf): add page-number overlay with Eastern Arabic digits`
15. `feat(mushaf): add MushafImagePage screen with RTL PageView + neighbour precache`
16. `chore(mushaf): register image-rendering stack with GetIt`
17. `feat(mushaf): add /mushafImage debug route for side-by-side comparison`
18. `feat(mushaf): cut over /mushaf route to MushafImagePage`
19. `chore(mushaf): remove text-rendering pipeline and debug route`
20. `refactor(mushaf): rename Image-suffixed types to canonical names`
21. `chore(mushaf): drop 604 QCF fonts, register assets/mushaf/* asset entries`
22. `test(mushaf): golden tests for tinted page rendering (light + dark)`
23. (optional) `chore(mushaf): final cleanup after image-rendering cutover`
