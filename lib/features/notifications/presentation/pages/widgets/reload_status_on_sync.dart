import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/features/notifications/presentation/cubit/alerts_sync_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_cubit.dart';

class ReloadStatusOnSync extends StatelessWidget {
  const ReloadStatusOnSync({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<AlertsSyncCubit, DateTime?>(
      listenWhen: (_, syncedAt) => syncedAt != null,
      listener: (context, _) => context.read<ReliabilityCubit>().load(),
      child: child,
    );
  }
}
