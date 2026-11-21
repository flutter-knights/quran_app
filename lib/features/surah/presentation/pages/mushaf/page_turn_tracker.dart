class PageTurnTracker {
  int? _target;

  void begin(int page) => _target = page;

  void end() => _target = null;

  bool isManual(int page) {
    if (_target == null) return true;
    if (page == _target) _target = null;
    return false;
  }
}
