import 'dart:io';

/// Logger for florval CLI output with optional ANSI color support.
class FlorvalLogger {
  /// Whether to output debug messages.
  final bool verbose;

  /// Whether ANSI color codes are supported.
  final bool _supportsAnsi;

  FlorvalLogger({this.verbose = false})
      : _supportsAnsi = stdout.supportsAnsiEscapes;

  /// Informational message (default output).
  void info(String message) {
    stdout.writeln('florval: $message');
  }

  /// Success message (green).
  void success(String message) {
    stdout.writeln(_green('florval: $message'));
  }

  /// Warning message (yellow, to stderr).
  void warn(String message) {
    stderr.writeln(_yellow('florval [WARN]: $message'));
  }

  /// Error message (red, to stderr).
  void error(String message) {
    stderr.writeln(_red('florval [ERROR]: $message'));
  }

  /// Debug message (only shown when verbose is true).
  void debug(String message) {
    if (verbose) {
      stdout.writeln(_dim('florval [DEBUG]: $message'));
    }
  }

  String _green(String text) =>
      _supportsAnsi ? '\x1B[32m$text\x1B[0m' : text;

  String _yellow(String text) =>
      _supportsAnsi ? '\x1B[33m$text\x1B[0m' : text;

  String _red(String text) =>
      _supportsAnsi ? '\x1B[31m$text\x1B[0m' : text;

  String _dim(String text) =>
      _supportsAnsi ? '\x1B[2m$text\x1B[0m' : text;
}
