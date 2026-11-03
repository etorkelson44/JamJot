/// Non-web: installed apps always stay signed in until sign-out.
void setKeepSignedIn(bool keep) {}

bool get keepSignedIn => true;

void markThisTabSignedIn() {}

bool get thisTabSignedIn => true;
