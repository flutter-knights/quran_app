# Prayer Times: After-Isha Refresh & Monthly Caching — Design Spec

**Date:** 2026-05-13  
**Branch:** feature/001-surah-list  
**Status:** Approved, ready for implementation

---

## Problem Summary

Two independent but related issues:

1. **After-Isha UX**: When Isha time passes, a `PrayerCountdownRequestRefresh` fires and triggers `DailyPrayerContextLoading`, causing a UI flash. The prayer list correctly switches to tomorrow's timings and the date correctly stays today, but the flash looks like the date is "changing with the prayer times." Additionally, there is no midnight refresh — the context stays stale until the user manually reopens the app.

2. **Monthly cache gap**: The API endpoint `GET /v1/calendar` with no `month`/`year` always returns the *current* month. `prayerTimesBackgroundPreCache` (which was supposed to pre-fetch ahead) is dead code — it is defined but never called. `clearOldCache` uses `DateTime.tryParse` on `"dd-MM-yyyy"` keys, which always returns null, so old cache entries are never deleted.

---

## Desired Behaviour

### After-Isha
- Date header: stays on today's Gregorian/Hijri date (no change until midnight)
- Prayer list: switches to tomorrow's prayer times
- Highlighted card: Fajr (next prayer)
- No visible loading flash when the switch happens
- After midnight: context auto-refreshes to the true new day (date + times both update)

### Monthly caching
- On every app open, a background check fires after a successful context load
- If today is within the last 7 days of the month AND next month's data is not yet cached → fetch and cache next month silently
- `clearOldCache` actually removes entries older than yesterday

---

## Architecture Overview

```
HomePage
  └─ BlocListener<PrayerCountdownCubit>
       └─ on PrayerCountdownRequestRefresh
            └─ DailyPrayerContextCubit.fetchDailyPrayerContext(silent: true)

DailyPrayerContextCubit.fetchDailyPrayerContext(silent)
  ├─ if !silent → emit DailyPrayerContextLoading
  ├─ GetDailyPrayerContext()  ← stream use case (unchanged)
  └─ on success → unawaited(preCachePrayerTimes(location))

PreCachePrayerTimes (new use case)
  └─ PrayerTimesRepository.preCacheNextMonthIfNeeded(location)
       └─ if within last 7 days of month AND next month not cached
            └─ PrayerTimeRemoteDataSource.getPrayerTimesList(location, month, year)
                 └─ PrayerTimesLocalDataSource.cache(list)

PrayerCountdownCubit._emitTick()
  ├─ Isha trigger:    currentPrayer==isha && now.day==contextDay && !_isIshaRefreshed && !_hasPendingRefresh
  └─ Midnight trigger: now.day != contextDay && !_hasPendingRefresh
       └─ both emit PrayerCountdownRequestRefresh (handled silently by HomePage)
```

---

## Detailed Changes

### 1. `PrayerTimeRemoteDataSource`

Add optional `month` and `year` named parameters to `getPrayerTimesList`:

```dart
Future<List<PrayerTimes>> getPrayerTimesList(
  Location location, {
  int? month,
  int? year,
}) async {
  final response = await dio.get(
    'http://api.aladhan.com/v1/calendar',
    queryParameters: {
      'latitude': location.latitude,
      'longitude': location.longitude,
      if (month != null) 'month': month,
      if (year != null) 'year': year,
    },
  );
  // existing mapping unchanged
}
```

When `month`/`year` are omitted the API defaults to the current month — no existing behaviour changes.

### 2. `PrayerTimesLocalDataSource.clearOldCache`

Replace the broken `DateTime.tryParse(key)` with the correct format parser:

```dart
final format = DateFormat('dd-MM-yyyy', 'en');
try {
  final keyDate = format.parse(key);
  if (keyDate.isBefore(threshold)) keysToRemove.add(key);
} catch (_) {}
```

### 3. `PrayerTimesRepository` (abstract)

Rename `prayerTimesBackgroundPreCache` → `preCacheNextMonthIfNeeded`. Update signature:

```dart
Future<void> preCacheNextMonthIfNeeded(Location location);
```

### 4. `PrayerTimesRepositoryImpl`

- **`getPrayerTimes`**: no change — after-Isha behaviour (return `date: today, timings: tomorrow`) is correct and already precise (tomorrow's Fajr time-string is from `tomorrowData`, so `parse24hTime(today).add(1.day)` produces the exact correct DateTime).

- **`preCacheNextMonthIfNeeded`** (replaces `prayerTimesBackgroundPreCache`):

```
1. now = DateTime.now()
2. daysLeft = daysInMonth(now.year, now.month) - now.day
3. if daysLeft > 7 → return
4. nextMonth = DateTime(now.year, now.month + 1, 1)   // Dart handles Dec→Jan
5. if getCached(date: nextMonth) != null → return
6. fetch = remoteDataSource.getPrayerTimesList(location,
     month: nextMonth.month, year: nextMonth.year)
7. await localDataSource.cache(fetch)
```

Helper: `daysInMonth(year, month) = DateTime(year, month + 1, 0).day`

### 5. `PreCachePrayerTimes` (new use case)

**File:** `lib/features/home/domain/usecases/pre_cache_prayer_times.dart`

```dart
class PreCachePrayerTimes {
  final PrayerTimesRepository prayerTimesRepository;
  PreCachePrayerTimes({required this.prayerTimesRepository});

  Future<void> call(Location location) =>
      prayerTimesRepository.preCacheNextMonthIfNeeded(location);
}
```

### 6. `DailyPrayerContextCubit`

Add `silent` parameter and fire-and-forget pre-cache call:

```dart
Future<void> fetchDailyPrayerContext({bool silent = false}) async {
  if (!silent) emit(DailyPrayerContextLoading());

  await getDailyPrayerContext(NoParams()).forEach((result) {
    if (isClosed) return;
    result.fold(
      (failure) => emit(DailyPrayerContextFailed(failure.message)),
      (dailyPrayerContext) {
        emit(DailyPrayerContextLoaded(dailyPrayerContext));
        unawaited(preCachePrayerTimes(dailyPrayerContext.location));
      },
    );
  });
}
```

### 7. `PrayerCountdownCubit`

Replace `_isRefreshed: bool` with two flags, and change `_dailyPrayerContext` from `late` to nullable so `startTimer` can safely read the previous day before overwriting:

```dart
DailyPrayerContext? _dailyPrayerContext; // was: late DailyPrayerContext
bool _isIshaRefreshed = false;           // blocks Isha re-fire on same day
bool _hasPendingRefresh = false;         // blocks any emit while refresh is in flight
```

`_emitTick` already guards against null via `if (_dailyPrayerContext == null) return;` at the top.

**`startTimer(newContext)`:**
```dart
void startTimer(DailyPrayerContext newContext) {
  final oldDay = _dailyPrayerContext?.date.gregorianDate().day;
  final newDay = newContext.date.gregorianDate().day;

  _dailyPrayerContext = newContext;
  _hasPendingRefresh = false;

  if (oldDay == null || oldDay != newDay) {
    _isIshaRefreshed = false; // new calendar day → allow Isha refresh again
  } else {
    _isIshaRefreshed = true;  // same day → Isha refresh just completed, suppress re-fire
  }

  _timer?.cancel();
  _emitTick();
  _timer = Timer.periodic(1.seconds, (_) => _emitTick());
}
```

**`_emitTick()` refresh conditions** (added after the existing countdown emit):
```dart
if (!_hasPendingRefresh) {
  final contextDay = _dailyPrayerContext.date.gregorianDate().day;
  final isIshaTime = currentPrayer == PrayerName.isha &&
                     now.day == contextDay &&
                     !_isIshaRefreshed;
  final isMidnight = now.day != contextDay;

  if (isIshaTime || isMidnight) {
    _hasPendingRefresh = true;
    emit(PrayerCountdownRequestRefresh());
  }
}
```

### 8. `HomePage`

Change the listener to use silent refresh:

```dart
if (state is PrayerCountdownRequestRefresh) {
  context.read<DailyPrayerContextCubit>()
      .fetchDailyPrayerContext(silent: true);
}
```

### 9. `home_di.dart`

Register new use case and update `DailyPrayerContextCubit`:

```dart
sl.registerLazySingleton(
  () => PreCachePrayerTimes(prayerTimesRepository: sl()),
);

sl.registerFactory(
  () => DailyPrayerContextCubit(
    getDailyPrayerContext: sl(),
    preCachePrayerTimes: sl(),
  ),
);
```

---

## Files Changed

| File | Change |
|---|---|
| `data/datasources/remote/prayer_time_remote_data_source.dart` | Add `month`/`year` params |
| `data/datasources/local/prayer_times_local_data_source.dart` | Fix `clearOldCache` date parsing |
| `domain/repositories/prayer_times_repository.dart` | Rename method |
| `data/repositories/prayer_times_repository_impl.dart` | Rewrite `preCacheNextMonthIfNeeded` |
| `domain/usecases/pre_cache_prayer_times.dart` | **New file** |
| `presentation/cubit/daily_prayer_context_cubit.dart` | Add `silent` param + pre-cache call |
| `presentation/cubit/prayer_countdown_cubit.dart` | Fix refresh flags, add midnight trigger |
| `presentation/pages/home_page.dart` | Silent refresh in listener |
| `home_di.dart` | Register new use case, update cubit factory |

---

## Edge Cases

| Scenario | Behaviour |
|---|---|
| Last day of month, fresh install, user reaches Isha before pre-cache completes | `tomorrowData == null` → fallback returns today's data. Pre-cache completes within seconds so this window is negligible. |
| After midnight, app stays open | Midnight trigger in `_emitTick` fires once, silent refresh fetches new day's data. |
| December → January pre-cache | `DateTime(year, 13, 1)` → Dart normalises to January 1 of next year. |
| Location unavailable during pre-cache | `preCachePrayerTimes` failure is swallowed (fire-and-forget); main context already loaded successfully. |

---

## Out of Scope

- Switching to HTTPS (separate concern)
- Yearly calendar fetch
- Hijri calendar day-boundary logic (Islamic day starts at Maghrib)
