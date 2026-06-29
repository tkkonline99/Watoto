/// Web / non-desktop variant: there is no application-support directory to
/// migrate, so this is a no-op. The real implementation (which uses `dart:io`)
/// is selected on native platforms via the conditional import in main.dart.
Future<void> migrateLegacyDesktopData(String supportPath) async {}
