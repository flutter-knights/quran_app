import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

extension PaletteContext on BuildContext {
  ColorPalette get palette =>
      select((SettingsCubit c) => c.state.settingsModel.palette);
}
