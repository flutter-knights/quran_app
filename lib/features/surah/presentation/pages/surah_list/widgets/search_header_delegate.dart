import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';
import 'package:quran_app/generated/l10n.dart';

import 'browse_tab.dart';

/// Pinned header: a comprehensive search field over a browse-tab selector.
/// Stays put while the list scrolls (the old design's pinned-search behaviour).
class SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  SearchHeaderDelegate({
    required this.selectedTab,
    required this.onTabChanged,
    required this.onQueryChanged,
    required this.controller,
  });

  final BrowseTab selectedTab;
  final ValueChanged<BrowseTab> onTabChanged;
  final ValueChanged<String> onQueryChanged;
  final TextEditingController controller;

  static const double _height = 116;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scheme = context.colorScheme;
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            style: TextStyle(fontSize: 14, color: scheme.onSurface),
            decoration: InputDecoration(
              isDense: true,
              hintText: S.of(context).search_quran_hint,
              hintStyle:
                  TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              prefixIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : GestureDetector(
                      onTap: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
              suffixIconConstraints: const BoxConstraints(minWidth: 40),
              filled: true,
              fillColor: scheme.surfaceContainer,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppSegmentedSelector<BrowseTab>(
              selected: selectedTab,
              onChanged: onTabChanged,
              options: [
                SegmentOption(
                  value: BrowseTab.surah,
                  label: S.of(context).tab_surahs,
                ),
                SegmentOption(
                  value: BrowseTab.juz,
                  label: S.of(context).tab_juz,
                ),
                SegmentOption(
                  value: BrowseTab.page,
                  label: S.of(context).tab_pages,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Always rebuild: the body re-emits a SearchState on every keystroke, which
  // reconstructs this delegate. Returning true keeps the clear-icon and tab
  // highlight in sync with the live query/tab. The header is cheap to rebuild.
  @override
  bool shouldRebuild(covariant SearchHeaderDelegate oldDelegate) => true;
}
