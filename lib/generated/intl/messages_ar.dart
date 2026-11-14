// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a ar locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'ar';

  static String m0(count) => "${count} حديث";

  static String m1(surah, ayah) => "سورة ${surah}، الآية ${ayah}";

  static String m2(count) => "${count} آية";

  static String m3(count) => "${count} كتب";

  static String m4(number) => "انتقل إلى الجزء ${number}";

  static String m5(number) => "انتقل إلى صفحة ${number}";

  static String m6(weekday, day, month, year) =>
      "${weekday}، ${day} ${month} ${year} هـ";

  static String m7(number) => "الجزء ${number}";

  static String m8(page) => "الصفحة ${page}";

  static String m9(percent) => "${percent}% مكتمل";

  static String m10(deg) => "اتجه نحو ${deg}° من الشمال لمواجهة القبلة.";

  static String m11(km) => "${km} كم";

  static String m12(time, prayerName) => "متبقي ${time} على صلاة ${prayerName}";

  static String m13(minutes) => "قبل ${minutes} د";

  static String m14(count) => "+${count} أخرى — حدّد بحثك";

  static String m15(surah, ayah) => "${surah} · آية ${ayah}";

  static String m16(count) => "${count} سورة";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
        "abu_dawood": MessageLookupByLibrary.simpleMessage("سنن أبي داود"),
        "adhanPerPrayerSection":
            MessageLookupByLibrary.simpleMessage("الأذان لكل صلاة"),
        "adhan_and_reminders":
            MessageLookupByLibrary.simpleMessage("الأذان والتذكيرات"),
        "ahadith_count": m0,
        "ahadith_section": MessageLookupByLibrary.simpleMessage("الأحاديث"),
        "al_silsila_sahiha":
            MessageLookupByLibrary.simpleMessage("السلسلة الصحيحة"),
        "al_tirmidhi": MessageLookupByLibrary.simpleMessage("جامع الترمذي"),
        "all_juz": MessageLookupByLibrary.simpleMessage("كل الأجزاء"),
        "all_surahs": MessageLookupByLibrary.simpleMessage("جميع السور"),
        "app_name": MessageLookupByLibrary.simpleMessage("الفرقان"),
        "appearance_section": MessageLookupByLibrary.simpleMessage("المظهر"),
        "arabicLanguage": MessageLookupByLibrary.simpleMessage("اللغة العربية"),
        "arabic_label": MessageLookupByLibrary.simpleMessage("العربية"),
        "asr": MessageLookupByLibrary.simpleMessage("العصر"),
        "asrSchool_hanafi": MessageLookupByLibrary.simpleMessage("الحنفي"),
        "asrSchool_shafi": MessageLookupByLibrary.simpleMessage(
            "الافتراضي (الشافعي، المالكي، الحنبلي)"),
        "author_abu_dawood":
            MessageLookupByLibrary.simpleMessage("الإمام أبو داود السجستاني"),
        "author_albani":
            MessageLookupByLibrary.simpleMessage("محمد ناصر الدين الألباني"),
        "author_bukhari": MessageLookupByLibrary.simpleMessage(
            "الإمام محمد بن إسماعيل البخاري"),
        "author_ibn_majah": MessageLookupByLibrary.simpleMessage(
            "الإمام محمد بن يزيد ابن ماجه القزويني"),
        "author_mishkat": MessageLookupByLibrary.simpleMessage(
            "الإمام محمد بن عبد الله الخطيب التبريزي"),
        "author_muslim": MessageLookupByLibrary.simpleMessage(
            "الإمام مسلم بن الحجاج النيسابوري"),
        "author_nasai":
            MessageLookupByLibrary.simpleMessage("الإمام أحمد بن شعيب النسائي"),
        "author_tirmidhi":
            MessageLookupByLibrary.simpleMessage("الإمام محمد بن عيسى الترمذي"),
        "ayah_label": m1,
        "ayahs_count": m2,
        "bookmark": MessageLookupByLibrary.simpleMessage("حفظ"),
        "bookmark_added": MessageLookupByLibrary.simpleMessage("تم الحفظ"),
        "bookmark_removed":
            MessageLookupByLibrary.simpleMessage("تم إزالة الحفظ"),
        "bookmark_save_failed":
            MessageLookupByLibrary.simpleMessage("تعذّر حفظ المرجعية"),
        "bookmarks_ahadith_section":
            MessageLookupByLibrary.simpleMessage("الأحاديث"),
        "bookmarks_pages_section":
            MessageLookupByLibrary.simpleMessage("الصفحات"),
        "bookmarks_quran_section":
            MessageLookupByLibrary.simpleMessage("القرآن"),
        "bookmarks_screen_title":
            MessageLookupByLibrary.simpleMessage("الإشارات"),
        "bookmarks_title":
            MessageLookupByLibrary.simpleMessage("العلامات المرجعية"),
        "books_count": m3,
        "books_section": MessageLookupByLibrary.simpleMessage("الكتب"),
        "brightness": MessageLookupByLibrary.simpleMessage("السطوع"),
        "calculationMethod_auto":
            MessageLookupByLibrary.simpleMessage("تلقائي (حسب المنطقة)"),
        "calculationMethod_egypt": MessageLookupByLibrary.simpleMessage(
            "الهيئة المصرية العامة للمساحة"),
        "calculationMethod_france":
            MessageLookupByLibrary.simpleMessage("فرنسا"),
        "calculationMethod_gulf":
            MessageLookupByLibrary.simpleMessage("منطقة الخليج"),
        "calculationMethod_isna": MessageLookupByLibrary.simpleMessage(
            "الجمعية الإسلامية لأمريكا الشمالية"),
        "calculationMethod_karachi": MessageLookupByLibrary.simpleMessage(
            "جامعة العلوم الإسلامية، كراتشي"),
        "calculationMethod_kuwait":
            MessageLookupByLibrary.simpleMessage("الكويت"),
        "calculationMethod_methodLabel":
            MessageLookupByLibrary.simpleMessage("الطريقة"),
        "calculationMethod_mwl":
            MessageLookupByLibrary.simpleMessage("رابطة العالم الإسلامي"),
        "calculationMethod_qatar": MessageLookupByLibrary.simpleMessage("قطر"),
        "calculationMethod_russia":
            MessageLookupByLibrary.simpleMessage("روسيا"),
        "calculationMethod_schoolLabel":
            MessageLookupByLibrary.simpleMessage("مذهب حساب العصر"),
        "calculationMethod_section":
            MessageLookupByLibrary.simpleMessage("طريقة حساب أوقات الصلاة"),
        "calculationMethod_singapore":
            MessageLookupByLibrary.simpleMessage("سنغافورة"),
        "calculationMethod_tehran":
            MessageLookupByLibrary.simpleMessage("معهد الجيوفيزياء، طهران"),
        "calculationMethod_turkey":
            MessageLookupByLibrary.simpleMessage("تركيا (ديانت)"),
        "calculationMethod_ummAlQura":
            MessageLookupByLibrary.simpleMessage("أم القرى (مكة)"),
        "chapter_label": MessageLookupByLibrary.simpleMessage("باب"),
        "collections_label": MessageLookupByLibrary.simpleMessage("المجموعات"),
        "coming_soon": MessageLookupByLibrary.simpleMessage("قريبًا"),
        "compass_rose_e": MessageLookupByLibrary.simpleMessage("شرق"),
        "compass_rose_n": MessageLookupByLibrary.simpleMessage("شمال"),
        "compass_rose_ne": MessageLookupByLibrary.simpleMessage("شمال شرق"),
        "compass_rose_nw": MessageLookupByLibrary.simpleMessage("شمال غرب"),
        "compass_rose_s": MessageLookupByLibrary.simpleMessage("جنوب"),
        "compass_rose_se": MessageLookupByLibrary.simpleMessage("جنوب شرق"),
        "compass_rose_sw": MessageLookupByLibrary.simpleMessage("جنوب غرب"),
        "compass_rose_w": MessageLookupByLibrary.simpleMessage("غرب"),
        "continue_reading":
            MessageLookupByLibrary.simpleMessage("متابعة التلاوة"),
        "continuousScroll": MessageLookupByLibrary.simpleMessage("تمرير"),
        "darkMode": MessageLookupByLibrary.simpleMessage("الوضع الداكن"),
        "death_abu_dawood": MessageLookupByLibrary.simpleMessage("٢٧٥ هـ"),
        "death_albani": MessageLookupByLibrary.simpleMessage("١٤٢٠ هـ"),
        "death_bukhari": MessageLookupByLibrary.simpleMessage("٢٥٦ هـ"),
        "death_ibn_majah": MessageLookupByLibrary.simpleMessage("٢٧٣ هـ"),
        "death_mishkat": MessageLookupByLibrary.simpleMessage("٧٤١ هـ"),
        "death_muslim": MessageLookupByLibrary.simpleMessage("٢٦١ هـ"),
        "death_nasai": MessageLookupByLibrary.simpleMessage("٣٠٣ هـ"),
        "death_tirmidhi": MessageLookupByLibrary.simpleMessage("٢٧٩ هـ"),
        "dhuhr": MessageLookupByLibrary.simpleMessage("الظهر"),
        "eachAyah": MessageLookupByLibrary.simpleMessage("كل آية"),
        "fajr": MessageLookupByLibrary.simpleMessage("الفجر"),
        "filter_all_chapters":
            MessageLookupByLibrary.simpleMessage("كل الأبواب"),
        "filter_apply": MessageLookupByLibrary.simpleMessage("تطبيق"),
        "filter_chapter_label": MessageLookupByLibrary.simpleMessage("الباب"),
        "filter_clear": MessageLookupByLibrary.simpleMessage("مسح"),
        "filter_status_label": MessageLookupByLibrary.simpleMessage("الدرجة"),
        "filters_title": MessageLookupByLibrary.simpleMessage("تصفية"),
        "fromAyah": MessageLookupByLibrary.simpleMessage("من آية"),
        "full_title_abu_dawood":
            MessageLookupByLibrary.simpleMessage("سنن أبي داود"),
        "full_title_albani":
            MessageLookupByLibrary.simpleMessage("السلسلة الصحيحة"),
        "full_title_bukhari": MessageLookupByLibrary.simpleMessage(
            "الجامع المسند الصحيح المختصر"),
        "full_title_ibn_majah":
            MessageLookupByLibrary.simpleMessage("سنن ابن ماجه"),
        "full_title_mishkat":
            MessageLookupByLibrary.simpleMessage("مشكاة المصابيح"),
        "full_title_muslim":
            MessageLookupByLibrary.simpleMessage("المسند الصحيح المختصر"),
        "full_title_nasai": MessageLookupByLibrary.simpleMessage("سنن النسائي"),
        "full_title_tirmidhi":
            MessageLookupByLibrary.simpleMessage("جامع الترمذي"),
        "general_section": MessageLookupByLibrary.simpleMessage("عام"),
        "goToPage": MessageLookupByLibrary.simpleMessage("اذهب إلى صفحة"),
        "go_to_juz": m4,
        "go_to_page": m5,
        "hadith_books_appbar_title":
            MessageLookupByLibrary.simpleMessage("الحديث الشريف"),
        "hadith_heading_label":
            MessageLookupByLibrary.simpleMessage("عنوان الحديث"),
        "hadith_number_label": MessageLookupByLibrary.simpleMessage("حديث رقم"),
        "hadith_of_the_day": MessageLookupByLibrary.simpleMessage("حديث اليوم"),
        "hadith_screen_title":
            MessageLookupByLibrary.simpleMessage("الحديث الشريف"),
        "hadith_total_label":
            MessageLookupByLibrary.simpleMessage("إجمالي الأحاديث"),
        "hijriDateWithDay": m6,
        "home_locationCard_body": MessageLookupByLibrary.simpleMessage(
            "نستخدمه فقط لحساب مواقيت صلاة دقيقة."),
        "home_locationCard_enable":
            MessageLookupByLibrary.simpleMessage("تفعيل الموقع"),
        "home_locationCard_openSettings":
            MessageLookupByLibrary.simpleMessage("فتح الإعدادات"),
        "home_locationCard_title": MessageLookupByLibrary.simpleMessage(
            "تحتاج مواقيت الصلاة إلى موقعك"),
        "home_notifHint_allow": MessageLookupByLibrary.simpleMessage("السماح"),
        "home_notifHint_text":
            MessageLookupByLibrary.simpleMessage("فعّل الإشعارات لسماع الأذان"),
        "ibn_e_majah": MessageLookupByLibrary.simpleMessage("سنن ابن ماجه"),
        "infinite": MessageLookupByLibrary.simpleMessage("∞"),
        "isha": MessageLookupByLibrary.simpleMessage("العشاء"),
        "jump_to_page_header":
            MessageLookupByLibrary.simpleMessage("انتقل إلى صفحة"),
        "jumuah": MessageLookupByLibrary.simpleMessage("الجمعة"),
        "juz_label": m7,
        "language_arabic": MessageLookupByLibrary.simpleMessage("العربية"),
        "language_english": MessageLookupByLibrary.simpleMessage("English"),
        "lastRead": MessageLookupByLibrary.simpleMessage("آخر قراءة"),
        "madaniyya": MessageLookupByLibrary.simpleMessage("مدنية"),
        "maghrib": MessageLookupByLibrary.simpleMessage("المغرب"),
        "makkiyya": MessageLookupByLibrary.simpleMessage("مكية"),
        "mishkat": MessageLookupByLibrary.simpleMessage("مشكاة المصابيح"),
        "mushaf_section": MessageLookupByLibrary.simpleMessage("المصحف"),
        "musnad_ahmad": MessageLookupByLibrary.simpleMessage("مسند أحمد"),
        "narrator_label": MessageLookupByLibrary.simpleMessage("الراوي"),
        "next_hadith": MessageLookupByLibrary.simpleMessage("التالي"),
        "no_bookmarks_yet":
            MessageLookupByLibrary.simpleMessage("لا توجد إشارات مرجعية بعد"),
        "notifSettings_disabledBanner_action":
            MessageLookupByLibrary.simpleMessage("فتح الإعدادات"),
        "notifSettings_disabledBanner_text":
            MessageLookupByLibrary.simpleMessage(
                "الإشعارات متوقفة — لن تسمع الأذان."),
        "notifications": MessageLookupByLibrary.simpleMessage("الإشعارات"),
        "notificationsScreenSubtitle":
            MessageLookupByLibrary.simpleMessage("إدارة إشعارات أوقات الصلاة."),
        "onb_appearance_title":
            MessageLookupByLibrary.simpleMessage("خصّص مظهرك"),
        "onb_continue": MessageLookupByLibrary.simpleMessage("متابعة"),
        "onb_enable": MessageLookupByLibrary.simpleMessage("تفعيل"),
        "onb_language_hint":
            MessageLookupByLibrary.simpleMessage("يمكنك تغييرها لاحقًا"),
        "onb_language_title": MessageLookupByLibrary.simpleMessage("اختر لغتك"),
        "onb_location_title":
            MessageLookupByLibrary.simpleMessage("مواقيت صلاتك بدقّة"),
        "onb_location_why": MessageLookupByLibrary.simpleMessage(
            "نستخدم موقعك لحساب مواقيت الصلاة في مدينتك بدقّة. يبقى على جهازك ولا نشاركه."),
        "onb_not_now": MessageLookupByLibrary.simpleMessage("ليس الآن"),
        "onb_notifications_title":
            MessageLookupByLibrary.simpleMessage("لا تفوتك صلاة"),
        "onb_notifications_why": MessageLookupByLibrary.simpleMessage(
            "فعّل الإشعارات لتصلك تنبيهات الأذان وتذكيرات الصلاة في أوقاتها. يمكنك ضبطها لاحقًا."),
        "onb_splash_desc":
            MessageLookupByLibrary.simpleMessage("عند فتح التطبيق لاحقًا"),
        "onb_theme_label": MessageLookupByLibrary.simpleMessage("السمة"),
        "onb_time_format_label":
            MessageLookupByLibrary.simpleMessage("صيغة الوقت"),
        "onb_welcome_headline":
            MessageLookupByLibrary.simpleMessage("القرآن الكريم بين يديك"),
        "onb_welcome_subtitle": MessageLookupByLibrary.simpleMessage(
            "اقرأ، استمع، وتدبّر — مع مواقيت صلاتك في مكان واحد."),
        "pageByPage": MessageLookupByLibrary.simpleMessage("صفحة"),
        "pageRemovedFromBookmarks":
            MessageLookupByLibrary.simpleMessage("أزيلت من المحفوظات"),
        "page_label": m8,
        "paper": MessageLookupByLibrary.simpleMessage("الورق"),
        "pinnedPrayerTimes":
            MessageLookupByLibrary.simpleMessage("أوقات الصلاة المثبتة"),
        "pinnedPrayerTimesSubtitle": MessageLookupByLibrary.simpleMessage(
            "اعرض صلوات اليوم في شريط الإشعارات"),
        "play": MessageLookupByLibrary.simpleMessage("تشغيل"),
        "playTestAdhan":
            MessageLookupByLibrary.simpleMessage("تشغيل أذان تجريبي"),
        "play_surah": MessageLookupByLibrary.simpleMessage("تشغيل السورة"),
        "playbackOptions":
            MessageLookupByLibrary.simpleMessage("خيارات التشغيل"),
        "playback_close": MessageLookupByLibrary.simpleMessage("إغلاق"),
        "playback_next": MessageLookupByLibrary.simpleMessage("الآية التالية"),
        "playback_pause": MessageLookupByLibrary.simpleMessage("إيقاف مؤقت"),
        "playback_previous":
            MessageLookupByLibrary.simpleMessage("الآية السابقة"),
        "playback_restart": MessageLookupByLibrary.simpleMessage("إعادة"),
        "playback_speed": MessageLookupByLibrary.simpleMessage("السرعة"),
        "prayers": MessageLookupByLibrary.simpleMessage("الصلوات"),
        "previous_hadith": MessageLookupByLibrary.simpleMessage("السابق"),
        "progress_complete": m9,
        "qibla_align_manually": m10,
        "qibla_aligned":
            MessageLookupByLibrary.simpleMessage("في اتجاه القبلة"),
        "qibla_app_bar_label":
            MessageLookupByLibrary.simpleMessage("اتجاه القبلة"),
        "qibla_bearing_suffix":
            MessageLookupByLibrary.simpleMessage("اتجاه القبلة"),
        "qibla_calibrate_hint": MessageLookupByLibrary.simpleMessage(
            "حرّك هاتفك على شكل ٨ لمعايرة البوصلة"),
        "qibla_distance_km": m11,
        "qibla_no_compass_title":
            MessageLookupByLibrary.simpleMessage("لا يوجد بوصلة في هذا الجهاز"),
        "qibla_point_to_kaaba":
            MessageLookupByLibrary.simpleMessage("وجِّه هاتفك نحو الكعبة"),
        "qibla_recalibrate":
            MessageLookupByLibrary.simpleMessage("إعادة المعايرة"),
        "qibla_screen_title": MessageLookupByLibrary.simpleMessage("القبلة"),
        "qibla_to_makkah":
            MessageLookupByLibrary.simpleMessage("إلى مكة المكرمة"),
        "qibla_your_location":
            MessageLookupByLibrary.simpleMessage("موقعك الحالي"),
        "quickAccess": MessageLookupByLibrary.simpleMessage("الوصول السريع"),
        "quran_screen_title":
            MessageLookupByLibrary.simpleMessage("القرآن الكريم"),
        "quran_search_no_results":
            MessageLookupByLibrary.simpleMessage("لا توجد نتائج"),
        "range": MessageLookupByLibrary.simpleMessage("النطاق"),
        "readingMode": MessageLookupByLibrary.simpleMessage("وضع القراءة"),
        "readingSettings":
            MessageLookupByLibrary.simpleMessage("إعدادات القراءة"),
        "reciter_label": MessageLookupByLibrary.simpleMessage("القارئ"),
        "remainingTimeLabel": m12,
        "reminderLabel": MessageLookupByLibrary.simpleMessage("ذكرني"),
        "reminderMinutesBefore": m13,
        "reminderOff": MessageLookupByLibrary.simpleMessage("لا"),
        "repeat": MessageLookupByLibrary.simpleMessage("التكرار"),
        "sahih_bukhari": MessageLookupByLibrary.simpleMessage("صحيح البخاري"),
        "sahih_muslim": MessageLookupByLibrary.simpleMessage("صحيح مسلم"),
        "search_hadith_hint":
            MessageLookupByLibrary.simpleMessage("ابحث في هذا الكتاب…"),
        "search_more_results": m14,
        "search_no_results":
            MessageLookupByLibrary.simpleMessage("لا توجد أحاديث مطابقة"),
        "search_quran_hint": MessageLookupByLibrary.simpleMessage(
            "ابحث عن سورة أو جزء أو صفحة أو آية…"),
        "search_section_ayahs": MessageLookupByLibrary.simpleMessage("الآيات"),
        "search_section_surahs": MessageLookupByLibrary.simpleMessage("السور"),
        "search_surah_hint":
            MessageLookupByLibrary.simpleMessage("ابحث عن سورة..."),
        "settings": MessageLookupByLibrary.simpleMessage("الإعدادات"),
        "settings_screen_title":
            MessageLookupByLibrary.simpleMessage("الإعدادات"),
        "share": MessageLookupByLibrary.simpleMessage("مشاركة"),
        "share_failed":
            MessageLookupByLibrary.simpleMessage("تعذّر فتح نافذة المشاركة"),
        "show_splash_screen":
            MessageLookupByLibrary.simpleMessage("شاشة البداية"),
        "start_reading": MessageLookupByLibrary.simpleMessage("ابدأ القراءة"),
        "start_reading_subtitle":
            MessageLookupByLibrary.simpleMessage("ابدأ بسورة الفاتحة"),
        "status_daeef": MessageLookupByLibrary.simpleMessage("ضعيف"),
        "status_hasan": MessageLookupByLibrary.simpleMessage("حسن"),
        "status_mudu": MessageLookupByLibrary.simpleMessage("موضوع"),
        "status_sahih": MessageLookupByLibrary.simpleMessage("صحيح"),
        "sunan_nasai": MessageLookupByLibrary.simpleMessage("سنن النسائي"),
        "sunrise": MessageLookupByLibrary.simpleMessage("الشروق"),
        "surah_ayah_label": m15,
        "surahs_appbar_title": MessageLookupByLibrary.simpleMessage("المصحف"),
        "surahs_count": m16,
        "tab_juz": MessageLookupByLibrary.simpleMessage("الأجزاء"),
        "tab_pages": MessageLookupByLibrary.simpleMessage("الصفحات"),
        "tab_surahs": MessageLookupByLibrary.simpleMessage("السور"),
        "tafsir": MessageLookupByLibrary.simpleMessage("تفسير"),
        "testAdhanScheduledSnack":
            MessageLookupByLibrary.simpleMessage("أذان تجريبي خلال ٥ ثوانٍ"),
        "test_section": MessageLookupByLibrary.simpleMessage("اختبار"),
        "the_noble_quran":
            MessageLookupByLibrary.simpleMessage("القرآن الكريم"),
        "time_format_12h": MessageLookupByLibrary.simpleMessage("١٢"),
        "time_format_24h": MessageLookupByLibrary.simpleMessage("٢٤"),
        "toAyah": MessageLookupByLibrary.simpleMessage("إلى آية"),
        "translation": MessageLookupByLibrary.simpleMessage("ترجمة"),
        "translation_label": MessageLookupByLibrary.simpleMessage("الترجمة"),
        "twentyFourHourFormat":
            MessageLookupByLibrary.simpleMessage("تنسيق 24 ساعة"),
        "undo": MessageLookupByLibrary.simpleMessage("تراجع"),
        "wholeRange": MessageLookupByLibrary.simpleMessage("النطاق")
      };
}
