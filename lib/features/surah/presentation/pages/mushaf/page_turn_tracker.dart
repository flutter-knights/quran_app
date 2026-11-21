class PageTurnTracker {
  int? _target;
  int _turn = 0;

  int begin(int page) {
    _target = page;
    return ++_turn;
  }

  void end(int turn) {
    if (turn == _turn) _target = null;
  }

  bool isManual(int page) {
    if (_target == null) return true;
    if (page == _target) _target = null;
    return false;
  }
}
