// ignore_for_file: non_constant_identifier_names
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

class PendingS {
  const PendingS._(this._ar);

  final bool _ar;

  static PendingS of(BuildContext context) =>
      PendingS._(Localizations.localeOf(context).languageCode == 'ar');

  static PendingS forLanguage(String languageCode) =>
      PendingS._(languageCode == 'ar');

  static PendingS get current =>
      PendingS._(Intl.getCurrentLocale().startsWith('ar'));

  String alerts_status_ok(String date) => _ar
      ? 'التنبيهات تعمل، ومجدولة حتى $date'
      : 'Alerts are on, scheduled until $date';
  String get alerts_status_okNoDate => _ar ? 'التنبيهات تعمل' : 'Alerts are on';
  String get alerts_status_attention =>
      _ar ? 'إعداد يحتاج إلى إجراء' : 'A setting needs attention';
  String get alerts_status_off => _ar
      ? 'الإشعارات غير مسموحة، فلن يصل الأذان'
      : 'Notifications are off, so no adhan will arrive';
  String get alerts_prayersSection => _ar ? 'الصلوات' : 'Prayers';
  String get alerts_silentTruth => _ar
      ? 'يتبع الصوت وضع الهاتف الصامت، إلا للصلوات المفعّل لها «يرن حتى في الوضع الصامت».'
      : 'Sound follows your phone\'s silent mode, except for prayers set to ring in silent mode.';
  String get alerts_iosTruth => _ar
      ? 'على iPhone يعمل مقطع قصير من الأذان، ويتبع زر الصامت.'
      : 'On iPhone a short adhan clip plays and follows the mute switch.';
  String get alerts_stripRow_title =>
      _ar ? 'شريط أوقات الصلاة' : 'Prayer times strip';
  String get alerts_stripRow_on => _ar ? 'مفعّل' : 'On';
  String get alerts_stripRow_onExpanded =>
      _ar ? 'مفعّل، عرض موسّع' : 'On, expanded view';
  String get alerts_stripRow_off => _ar ? 'متوقف' : 'Off';
  String get alerts_timesSection => _ar ? 'مواقيت الصلاة' : 'Prayer times';
  String get alerts_autoMethodReason => _ar
      ? 'تُختار الطريقة تلقائيًا حسب بلدك.'
      : 'The method is chosen automatically from your country.';
  String get alerts_testCaption => _ar
      ? 'يصل بعد ثوانٍ إذا كانت الإشعارات مسموحة.'
      : 'Arrives in a few seconds if notifications are allowed.';
  String get alerts_testBlocked => _ar
      ? 'لن يعمل الأذان: الإشعارات غير مسموحة.'
      : 'Nothing will play: notifications are off.';
  String get alerts_testFailed => _ar
      ? 'تعذّر جدولة الأذان التجريبي، حاول مرة أخرى.'
      : 'Couldn\'t schedule the test adhan. Try again.';
  String get alerts_summary_off => _ar ? 'متوقف' : 'Off';
  String get alerts_summary_ringsInSilent =>
      _ar ? 'يرن في الوضع الصامت' : 'rings in silent mode';
  String alerts_summary_reminder(String minutes) =>
      _ar ? 'تذكير قبل $minutes' : 'reminder $minutes before';
  String get alerts_sound_adhan => _ar ? 'الأذان' : 'Adhan';
  String get alerts_sound_fajrAdhan => _ar ? 'أذان الفجر' : 'Fajr adhan';
  String get alerts_sound_adhanClip => _ar ? 'مقطع من الأذان' : 'Adhan clip';
  String get alerts_sound_fajrAdhanClip =>
      _ar ? 'مقطع من أذان الفجر' : 'Fajr adhan clip';
  String get alerts_sound_tone => _ar ? 'نغمة الإشعار' : 'Notification tone';
  String get alerts_sound_vibrate => _ar ? 'اهتزاز فقط' : 'Vibrate only';
  String get alerts_sound_silent => _ar ? 'بدون صوت' : 'Silent';
  String get alerts_sheet_atTime => _ar ? 'عند وقت الصلاة' : 'At prayer time';
  String get alerts_sheet_alertSwitch =>
      _ar ? 'تنبيه وقت الصلاة' : 'Prayer-time alert';
  String get alerts_sheet_sound => _ar ? 'الصوت' : 'Sound';
  String get alerts_sheet_ringInSilent =>
      _ar ? 'يرن حتى في الوضع الصامت' : 'Ring even in silent mode';
  String get alerts_sheet_ringInSilentSub => _ar
      ? 'بصوت المنبّه، فقد يرن رغم «عدم الإزعاج»، في اجتماع أو في المسجد.'
      : 'Uses alarm volume, so it may ring through Do Not Disturb, in a meeting or at the mosque.';
  String get alerts_sheet_beforeTime =>
      _ar ? 'التذكير قبل الصلاة' : 'Reminder before prayer';
  String get alerts_sheet_reminderSwitch =>
      _ar ? 'تذكير قبل الصلاة' : 'Remind me before';
  String alerts_sheet_reminderValue(String minutes) =>
      _ar ? 'قبل $minutes' : '$minutes before';
  String alerts_sheet_reminderArrives(String time) =>
      _ar ? 'يصلك $time' : 'Arrives at $time';
  String get alerts_sheet_reminderSound =>
      _ar ? 'صوت التذكير' : 'Reminder sound';
  String get alerts_sheet_reminderDisabled => _ar
      ? 'يتوقف التذكير مع إيقاف تنبيه وقت الصلاة.'
      : 'The reminder is off while the prayer-time alert is off.';
  String get alerts_sheet_iosNote => _ar
      ? 'يعمل الصوت مقطعًا قصيرًا، ويتبع زر الصامت في الهاتف.'
      : 'Plays a short clip and follows the phone\'s mute switch.';
  String get alerts_picker_prayerSound =>
      _ar ? 'صوت وقت الصلاة' : 'Prayer-time sound';
  String get alerts_picker_silentSub =>
      _ar ? 'يظهر الإشعار دون صوت' : 'The notification shows without sound';
  String alerts_picker_preview(String sound) =>
      _ar ? 'معاينة $sound' : 'Preview $sound';
  String get alerts_picker_stopPreview =>
      _ar ? 'إيقاف المعاينة' : 'Stop preview';
  String get alerts_picker_previewing => _ar ? 'معاينة الآن' : 'Previewing';
  String get strip_title => _ar ? 'شريط أوقات الصلاة' : 'Prayer times strip';
  String get strip_show => _ar ? 'إظهار الشريط' : 'Show the strip';
  String get strip_expanded => _ar ? 'استخدام عرض موسّع' : 'Use expanded view';
  String get strip_countdown => _ar ? 'إظهار العدّاد' : 'Show countdown';
  String get strip_countdownNote => _ar
      ? 'أرقام العدّاد تتبع لغة الهاتف'
      : 'Countdown digits follow the phone\'s language';
  String get strip_highlight => _ar ? 'لون التمييز' : 'Highlight colour';
  String get strip_background => _ar ? 'لون الخلفية' : 'Background colour';
  String get strip_shape => _ar ? 'شكل التمييز' : 'Highlight shape';
  String get strip_note => _ar
      ? 'يلوّن مساحة الأوقات فقط، ويبقى رأس الإشعار بلون النظام.'
      : 'Colours only the times area; the notification header keeps the system colour.';
  String get strip_previewCollapsed => _ar ? 'مطويّ' : 'Collapsed';
  String get strip_previewExpanded => _ar ? 'موسّع' : 'Expanded';
  String get strip_next => _ar ? 'التالية' : 'Next';
  String strip_nextIn(String prayer) => _ar ? '$prayer بعد' : '$prayer in';
  String get strip_color_app => _ar ? 'لون التطبيق' : 'App colour';
  String get strip_color_darkGreen => _ar ? 'أخضر داكن' : 'Dark green';
  String get strip_color_emerald => _ar ? 'زمردي' : 'Emerald';
  String get strip_color_blue => _ar ? 'أزرق' : 'Blue';
  String get strip_color_indigo => _ar ? 'نيلي' : 'Indigo';
  String get strip_color_maroon => _ar ? 'عنابي' : 'Maroon';
  String get strip_color_bronze => _ar ? 'برونزي' : 'Bronze';
  String get strip_bg_auto => _ar ? 'تلقائي حسب النظام' : 'Automatic (system)';
  String get strip_bg_mint => _ar ? 'نعناعي' : 'Mint';
  String get strip_bg_sand => _ar ? 'رملي' : 'Sand';
  String get strip_bg_sky => _ar ? 'سماوي' : 'Sky';
  String get strip_bg_rose => _ar ? 'وردي' : 'Rose';
  String get strip_shape_none => _ar ? 'بدون' : 'None';
  String get strip_shape_rounded => _ar ? 'مستطيل مستدير' : 'Rounded rectangle';
  String get strip_shape_pill => _ar ? 'كبسولة' : 'Pill';
  String get strip_shape_outline => _ar ? 'إطار' : 'Outline';
  String get rel_title => _ar ? 'حالة التنبيهات' : 'Alert status';
  String get rel_needsAction => _ar ? 'يحتاج إجراء' : 'Needs action';
  String get rel_working => _ar ? 'يعمل' : 'Working';
  String get rel_notifications => _ar ? 'الإشعارات' : 'Notifications';
  String get rel_exactAlarms => _ar ? 'المنبهات الدقيقة' : 'Exact alarms';
  String get rel_battery => _ar ? 'تحسين البطارية' : 'Battery optimisation';
  String get rel_allowed => _ar ? 'مسموحة' : 'Allowed';
  String get rel_blocked => _ar ? 'غير مسموحة' : 'Not allowed';
  String get rel_batteryRestricted => _ar ? 'مقيّد' : 'Restricted';
  String get rel_batteryUnrestricted => _ar ? 'بدون قيود' : 'Unrestricted';
  String get rel_batteryHint => _ar
      ? 'قد يؤخّر النظام الأذان أو يوقفه. يلزم اختيار «بدون قيود».'
      : 'The system may delay or stop the adhan. Choose «Unrestricted».';
  String get rel_openSettings => _ar ? 'فتح الإعداد' : 'Open setting';
  String get rel_xiaomiSection => _ar ? 'هواتف شاومي' : 'Xiaomi phones';
  String get rel_unverifiable => _ar
      ? 'لا يستطيع التطبيق قراءة هذا الإعداد، فيكفي تأكيده مرة واحدة.'
      : 'The app can\'t read this setting; confirm it once.';
  String get rel_autostart =>
      _ar ? 'تفعيل التشغيل التلقائي' : 'Turn on autostart';
  String get rel_autostartSub => _ar
      ? 'للسماح بالتنبيه بعد إغلاق التطبيق.'
      : 'Lets alerts arrive after the app is closed.';
  String get rel_xiaomiBattery => _ar
      ? 'اختيار «بدون قيود» في توفير البطارية'
      : 'Choose «No restrictions» in battery saver';
  String get rel_xiaomiBatterySub =>
      _ar ? 'لمنع تأخير الأذان.' : 'Stops the adhan from being delayed.';
  String get rel_lockApp =>
      _ar ? 'قفل التطبيق في التطبيقات الأخيرة' : 'Lock the app in recent apps';
  String get rel_lockAppSub => _ar
      ? 'بسحب بطاقته إلى الأسفل حتى يظهر القفل، وتجنّب «مسح الكل» قبل ذلك.'
      : 'Pull its card down until the lock shows, and avoid «Clear all» before that.';
  String get rel_done => _ar ? 'تمّ' : 'Done';
  String rel_scheduledUntil(String date) =>
      _ar ? 'مجدولة حتى $date' : 'Scheduled until $date';
  String get rel_scheduledNone =>
      _ar ? 'لا تنبيهات مجدولة بعد' : 'Nothing scheduled yet';
  String get rel_scheduledSub => _ar
      ? 'تمتد الجدولة عند كل فتح للتطبيق وبعد كل أذان.'
      : 'Scheduling extends each time the app opens and after every adhan.';
  String get rel_test => _ar ? 'اختبار الأذان' : 'Test the adhan';
  String get onb_alerts_title => _ar ? 'تنبيهات الصلاة' : 'Prayer alerts';
  String get onb_alerts_atTime => _ar ? 'عند وقت الصلاة' : 'At prayer time';
  String get onb_alerts_none => _ar ? 'بدون تنبيه' : 'No alert';
  String get onb_alerts_reminder =>
      _ar ? 'تذكير قبل الصلاة' : 'Reminder before prayer';
  String get onb_alerts_reminderNone => _ar ? 'بدون' : 'None';
  String get onb_alerts_note => _ar
      ? 'الصوت يتبع وضع الهاتف الصامت، ويمكن ضبط كل صلاة لاحقًا من الإعدادات.'
      : 'Sound follows silent mode; each prayer can be adjusted later in Settings.';
  String get onb_later => _ar ? 'لاحقًا' : 'Later';
  String get onb_skip => _ar ? 'تخطٍّ' : 'Skip';
  String get onb_xiaomi_title => _ar
      ? 'حتى لا يتوقف الأذان على هواتف شاومي'
      : 'Keep the adhan working on Xiaomi phones';
  String get onb_xiaomi_lead => _ar
      ? 'يوقف نظام شاومي التطبيقات في الخلفية. ثلاث خطوات تُبقي الأذان في وقته.'
      : 'Xiaomi\'s system stops apps in the background. Three steps keep the adhan on time.';
  String get onb_exactAlarmsWhy => _ar
      ? 'يلزم السماح بها ليصل الأذان في وقته تمامًا.'
      : 'Needed for the adhan to arrive right on time.';
  String get upg_title =>
      _ar ? 'تحسينات في تنبيهات الصلاة' : 'Prayer alerts improved';
  String get upg_silent => _ar
      ? 'يتبع الأذان الآن وضع الهاتف الصامت. لتشغيله رغم الصامت: «يرن حتى في الوضع الصامت» لكل صلاة.'
      : 'The adhan now follows silent mode. To ring anyway, turn on «Ring even in silent mode» for a prayer.';
  String get upg_reminder => _ar
      ? 'تذكير قبل الصلاة من دقيقة إلى ٦٠ دقيقة، بصوت مستقل.'
      : 'A reminder from 1 to 60 minutes before, with its own sound.';
  String get upg_xiaomi => _ar
      ? 'على هواتف شاومي يلزم إعدادان حتى لا يتوقف الأذان.'
      : 'On Xiaomi phones two settings keep the adhan from stopping.';
  String get upg_exactAlarms => _ar
      ? 'المنبهات الدقيقة غير مسموحة، فقد يتأخر الأذان.'
      : 'Exact alarms are not allowed, so the adhan may be late.';
  String get upg_review => _ar ? 'مراجعة الإعدادات' : 'Review settings';
  String missed_title(String prayer) =>
      _ar ? 'فاتك تنبيه $prayer' : 'You missed the $prayer alert';
  String get missed_body => _ar
      ? 'أوقف النظام التطبيق في الخلفية غالبًا. إعدادان على هاتفك يمنعان تكرار ذلك.'
      : 'The system most likely stopped the app in the background. Two settings on your phone prevent this.';
  String get missed_bodyGeneric => _ar
      ? 'قد يكون النظام أوقف التطبيق أو أخّره. صفحة حالة التنبيهات تبيّن ما يلزم تغييره.'
      : 'The system may have stopped or delayed the app. Alert status shows what to change.';
  String late_title(String prayer) =>
      _ar ? 'تأخّر تنبيه $prayer' : 'The $prayer alert was late';
  String get missed_fix => _ar ? 'إصلاح الآن' : 'Fix now';

  String alerts_minutes(num count) {
    final n = count.toInt();
    if (!_ar) return n == 1 ? '1 minute' : '$n minutes';
    if (n == 1) return 'دقيقة واحدة';
    if (n == 2) return 'دقيقتين';
    final mod = n % 100;
    if (mod >= 3 && mod <= 10) return '$n دقائق';
    return '$n دقيقة';
  }

  String alerts_enabledCount(num count) {
    final n = count.toInt();
    if (!_ar) {
      if (n == 0) return 'Off for all prayers';
      return n == 1 ? 'On for 1 prayer' : 'On for $n prayers';
    }
    if (n == 0) return 'متوقف لكل الصلوات';
    if (n == 1) return 'مفعّل لصلاة واحدة';
    if (n == 2) return 'مفعّل لصلاتين';
    final mod = n % 100;
    if (mod >= 3 && mod <= 10) return 'مفعّل لـ$n صلوات';
    return 'مفعّل لـ$n صلاة';
  }
}
