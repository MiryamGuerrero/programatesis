// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import "dart:html" as html;

const String _signedOutLockKey = "reuma_signed_out_lock";

bool isSignedOutLock() {
  try {
    return html.window.localStorage[_signedOutLockKey] == "1";
  } catch (_) {
    return false;
  }
}

void setSignedOutLock(bool value) {
  try {
    if (value) {
      html.window.localStorage[_signedOutLockKey] = "1";
    } else {
      html.window.localStorage.remove(_signedOutLockKey);
    }
  } catch (_) {
    // Ignore storage errors (private mode or blocked storage).
  }
}

void clearWebUrlAuthParams() {
  try {
    final location = html.window.location;
    final cleanUrl = location.pathname ?? "/";
    html.window.history.replaceState(null, "", cleanUrl);
  } catch (_) {}
}
