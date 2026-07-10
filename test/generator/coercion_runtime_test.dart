import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:florval/src/generator/client_generator.dart';

/// Executes the exact coercion helper source that ClientGenerator emits
/// into client files, simulating the two shapes a top-level primitive
/// response body can arrive in:
///
/// - `application/json` → dio JSON-decodes the body, so `5` arrives as an
///   `int` (and `12.5` as `double`, `true` as `bool`).
/// - `text/plain` / `text/html` → dio does not decode, so the same body
///   arrives as the raw `String` ('5', '12.5', 'true').
void main() {
  group('coercion helpers (runtime)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('florval_coercion_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('coerce both JSON-decoded and plain-text primitive bodies', () {
      final script = StringBuffer();
      for (final source in ClientGenerator.coercionHelperSources.values) {
        script.writeln(source);
      }
      script.writeln('''
void check(Object? actual, Object? expected, String label) {
  if (actual != expected) {
    throw StateError('\$label: expected \$expected but got \$actual');
  }
}

void checkThrows(void Function() fn, String label) {
  try {
    fn();
  } on FormatException {
    return;
  }
  throw StateError('\$label: expected a FormatException');
}

void main() {
  // application/json: dio decodes the body before the client sees it.
  check(_coerceInt(jsonDecode('5')), 5, 'json int');
  check(_coerceInt(jsonDecode('5.0')), 5, 'json int sent as float');
  check(_coerceDouble(jsonDecode('12.5')), 12.5, 'json double');
  check(_coerceDouble(jsonDecode('5')), 5.0, 'json double sent as int');
  check(_coerceBool(jsonDecode('true')), true, 'json bool');
  check(_coerceString(jsonDecode('"hello"')), 'hello', 'json string');

  // text/plain or text/html: dio hands back the raw String body.
  check(_coerceInt('5'), 5, 'text int');
  check(_coerceInt('5\\n'), 5, 'text int with trailing newline');
  check(_coerceDouble('12.5'), 12.5, 'text double');
  check(_coerceBool('true'), true, 'text bool true');
  check(_coerceBool('false'), false, 'text bool false');
  check(_coerceString('hello'), 'hello', 'text string');

  // date-time bodies arrive as strings in both cases.
  check(_coerceDateTime('2024-01-02T03:04:05Z'),
      DateTime.utc(2024, 1, 2, 3, 4, 5), 'date-time string');

  // Unparseable bodies surface as FormatException, not a bad cast.
  checkThrows(() => _coerceInt('not a number'), 'int garbage');
  checkThrows(() => _coerceBool('yes'), 'bool garbage');
  checkThrows(() => _coerceString(null), 'string null');
}
''');

      final scriptFile = File(p.join(tempDir.path, 'coercion_check.dart'));
      // The generated helpers have no imports; jsonDecode needs dart:convert.
      scriptFile
          .writeAsStringSync("import 'dart:convert';\n\n${script.toString()}");

      final result = Process.runSync(
          Platform.resolvedExecutable, [scriptFile.path]);
      expect(result.exitCode, 0,
          reason: 'stdout: ${result.stdout}\nstderr: ${result.stderr}');
    });
  });
}
