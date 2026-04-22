import "session_lock_stub.dart"
    if (dart.library.html) "session_lock_web.dart" as impl;

bool isSignedOutLock() => impl.isSignedOutLock();

void setSignedOutLock(bool value) => impl.setSignedOutLock(value);
