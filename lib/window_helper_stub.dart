// Stub for non-IO platforms (web, etc.)
Future<void> initWindow() async {}
void onEscPressed() {}
void onF11Pressed() {}
Future<bool> confirmAndExit(dynamic context) async => false;
