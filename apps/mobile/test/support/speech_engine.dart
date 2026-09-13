import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the device's text-to-speech engine: every call is answered
/// at once, so a line "finishes" as soon as it is spoken.
///
/// A widget test otherwise has no engine, and under the test clock a platform
/// call with no handler never gets its reply. That did not matter while
/// nothing waited for narration. Lessons and quizzes now move on only once
/// the feedback has been heard (`SpeechBeat`), so without an engine that
/// answers they sit out the full safety cap instead of the beat.
///
/// Call from `setUp` so it covers every test in the file.
void useInstantSpeechEngine() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    _channel,
    (call) async => switch (call.method) {
      'getLanguages' => ['en-US', 'fr-FR', 'sw-KE'],
      'getVoices' => <Object>[],
      _ => 1,
    },
  );
}

/// Call from `tearDown`.
void resetSpeechEngine() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, null);
}

const _channel = MethodChannel('flutter_tts');
