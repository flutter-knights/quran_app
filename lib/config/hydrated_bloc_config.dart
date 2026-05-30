import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path_provider/path_provider.dart';

Future<void> initHydratedCubit() async {
  final directory = await getApplicationDocumentsDirectory();
  final storageDir = HydratedStorageDirectory(directory.path);

  try {
    HydratedBloc.storage =
        await HydratedStorage.build(storageDirectory: storageDir);
  } catch (_) {
    // Corrupt persisted state must not permanently brick launch. Reset it and
    // continue with defaults rather than crashing every time the app opens.
    try {
      await HydratedStorage.build(storageDirectory: storageDir)
          .then((s) => s.clear());
    } catch (_) {}
    HydratedBloc.storage =
        await HydratedStorage.build(storageDirectory: storageDir);
  }
}
