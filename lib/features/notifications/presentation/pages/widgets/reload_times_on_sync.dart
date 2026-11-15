import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/features/notifications/presentation/cubit/alerts_sync_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/today_prayer_times_cubit.dart';

class ReloadTimesOnSync extends StatelessWidget {
  const ReloadTimesOnSync({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AlertsSyncCubit, DateTime?>(
      listenWhen: (_, syncedAt) => syncedAt != null,
      listener: (context, _) => context.read<TodayPrayerTimesCubit>().load(),
      child: child,
    );
  }
}
