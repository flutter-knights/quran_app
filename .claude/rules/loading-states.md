# Loading States

**Always skeletonize loading.** Whenever the UI is waiting on data (initial load, pagination/"load more", search, refetch after a filter change, a detail screen fetching its content), show a **shimmer skeleton** that mirrors the real content's layout — never a bare `CircularProgressIndicator`/`LinearProgressIndicator` as the primary loading state.

## How
- Use the `skeletonizer` package, matching the existing convention: wrap real placeholder widgets (Text/badges/cards with dummy content) in a `Skeletonizer`, rather than hand-placing `Bone.*` widgets.
- Reuse the shared skeletons where they fit:
  - `AppListSkeleton` (`lib/core/widgets/design/app_list_skeleton.dart`) — full scrollable list screens.
  - `HomeSkeleton` (`lib/core/widgets/design/home_skeleton.dart`) — home layout.
  - For a single placeholder (e.g. a card, a "load more" footer), wrap one `SurfaceCard` of placeholder content in `Skeletonizer` — do **not** embed `AppListSkeleton` (a `ListView`) as a list item; its height is unbounded there.
- The skeleton should resemble the loaded layout (same card shape, rough text line count) so the transition is seamless.

## Reasonable exception
- A brief, secondary progress indicator over **already-visible** content (e.g. a thin bar while fetching the next/previous item on a detail page that's already showing data) may stay a slim `LinearProgressIndicator` — skeletonizing content the user is already reading would be jarring. Skeletons are for content that isn't on screen yet.
