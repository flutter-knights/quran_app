import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_state.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_long_press_sheet.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakePlayback extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlayback() : super(const PlaybackState(reciter: Reciter.alafasy));
  Reciter? lastSetReciter;
  @override
  Future<void> setReciter(Reciter r) async {
    lastSetReciter = r;
    emit(state.copyWith(reciter: r));
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _FakeBookmark extends Cubit<BookmarkState> implements BookmarkCubit {
  _FakeBookmark() : super(const BookmarkState());
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

const _ayah = AyahIdentifier(surah: 2, ayah: 5);

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    );

void main() {
  late _FakePlayback playback;
  late _FakeBookmark bookmark;

  setUp(() {
    playback = _FakePlayback();
    bookmark = _FakeBookmark();
  });

  testWidgets('renders 4 action buttons + reciter chips', (tester) async {
    await tester.pumpWidget(_wrap(MultiBlocProvider(
      providers: [
        BlocProvider<PlaybackCubit>.value(value: playback),
        BlocProvider<BookmarkCubit>.value(value: bookmark),
      ],
      child: const AyahLongPressSheet(ayah: _ayah),
    )));
    expect(find.text('Tafsir'), findsOneWidget);
    expect(find.text('Translation'), findsOneWidget);
    expect(find.text('Bookmark'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Reciter'), findsOneWidget);
    // At least one reciter chip
    expect(find.byType(ChoiceChip), findsWidgets);
  });

  testWidgets('tapping a reciter chip calls setReciter', (tester) async {
    await tester.pumpWidget(_wrap(MultiBlocProvider(
      providers: [
        BlocProvider<PlaybackCubit>.value(value: playback),
        BlocProvider<BookmarkCubit>.value(value: bookmark),
      ],
      child: const AyahLongPressSheet(ayah: _ayah),
    )));
    // Find a chip whose label matches Husary's Arabic name (always rendered)
    final chip = find.widgetWithText(ChoiceChip, Reciter.husary.arabicName);
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(playback.lastSetReciter, Reciter.husary);
  });
}
