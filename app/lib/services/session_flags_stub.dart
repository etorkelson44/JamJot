/// Non-web: installed apps always stay signed in until sign-out.
void setKeepSignedIn(bool keep) {}

bool get keepSignedIn => true;

void markThisTabSignedIn() {}

bool get thisTabSignedIn => true;

String? _activeStudent;
DateTime _lastSeen = DateTime.now();

void storeActiveStudent(String? id) {
  _activeStudent = id;
  _lastSeen = DateTime.now();
}

void touchActiveSession() => _lastSeen = DateTime.now();

String? freshActiveStudent(Duration maxIdle) =>
    DateTime.now().difference(_lastSeen) > maxIdle ? null : _activeStudent;
