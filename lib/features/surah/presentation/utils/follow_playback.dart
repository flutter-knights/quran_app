int? nextFollowAction({
  required bool followPlayback,
  required int currentPage,
  required int? playingPage,
}) {
  if (!followPlayback || playingPage == null || playingPage == currentPage) {
    return null;
  }
  return playingPage;
}

bool followAfterManualTurn({
  required bool followPlayback,
  required int newPage,
  required int? playingPage,
}) {
  if (playingPage == null) return followPlayback;
  return newPage == playingPage;
}
