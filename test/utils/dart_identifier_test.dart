import 'package:test/test.dart';
import 'package:florval/src/utils/dart_identifier.dart';

void main() {
  group('sanitizeToCamelCase', () {
    test('returns null for empty string', () {
      expect(sanitizeToCamelCase(''), isNull);
    });

    test('returns null for purely non-ASCII string', () {
      expect(sanitizeToCamelCase('正常'), isNull);
      expect(sanitizeToCamelCase('レコード番号'), isNull);
      expect(sanitizeToCamelCase('극めて重度'), isNull);
    });

    test('converts ASCII strings normally', () {
      expect(sanitizeToCamelCase('user_name'), 'userName');
      expect(sanitizeToCamelCase('created_at'), 'createdAt');
      expect(sanitizeToCamelCase('BMI'), 'bmi');
    });

    test('strips non-ASCII and converts remainder', () {
      expect(sanitizeToCamelCase('BMI値'), 'bmi');
      expect(sanitizeToCamelCase('user名前'), 'user');
      expect(sanitizeToCamelCase('record_番号_id'), 'recordId');
    });

    test('returns null when stripping leaves nothing', () {
      expect(sanitizeToCamelCase('日本語のみ'), isNull);
    });
  });

  group('safeProviderParamName', () {
    test('renames Riverpod reserved names', () {
      // Notifier/AsyncNotifier instance members
      expect(safeProviderParamName('state'), 'stateParam');
      expect(safeProviderParamName('ref'), 'refParam');
      expect(safeProviderParamName('future'), 'futureParam');
      expect(safeProviderParamName('build'), 'buildParam');
      expect(safeProviderParamName('update'), 'updateParam');
      expect(safeProviderParamName('updateShouldNotify'),
          'updateShouldNotifyParam');
      expect(safeProviderParamName('listenSelf'), 'listenSelfParam');
      // Generated provider constructor super parameters
      expect(safeProviderParamName('name'), 'nameParam');
      expect(safeProviderParamName('from'), 'fromParam');
      expect(safeProviderParamName('dependencies'), 'dependenciesParam');
    });

    test('does not rename non-reserved names', () {
      expect(safeProviderParamName('code'), 'code');
      expect(safeProviderParamName('userId'), 'userId');
      expect(safeProviderParamName('status'), 'status');
    });

    test('renames Dart reserved words', () {
      expect(safeProviderParamName('in'), 'inParam');
      expect(safeProviderParamName('is'), 'isParam');
      expect(safeProviderParamName('default'), 'defaultParam');
      expect(safeProviderParamName('class'), 'classParam');
      expect(safeProviderParamName('new'), 'newParam');
      expect(safeProviderParamName('return'), 'returnParam');
      expect(safeProviderParamName('var'), 'varParam');
      expect(safeProviderParamName('void'), 'voidParam');
      expect(safeProviderParamName('switch'), 'switchParam');
    });
  });

  group('sanitizeParamName', () {
    test('converts normal ASCII parameter names', () {
      expect(sanitizeParamName('user_id'), 'userId');
      expect(sanitizeParamName('limit'), 'limit');
      expect(sanitizeParamName('page_size'), 'pageSize');
    });

    test('falls back to positional name for empty input', () {
      expect(sanitizeParamName(''), 'param0');
      expect(sanitizeParamName('', index: 3), 'param3');
    });

    test('falls back to positional name for purely non-ASCII input', () {
      expect(sanitizeParamName('カテゴリ'), 'param0');
      expect(sanitizeParamName('カテゴリ', index: 2), 'param2');
    });

    test('strips non-ASCII and converts remainder', () {
      expect(sanitizeParamName('user名前'), 'user');
      expect(sanitizeParamName('BMI値'), 'bmi');
    });

    test('handles names starting with digits', () {
      expect(sanitizeParamName('2fa_code'), 'param2faCode');
      expect(sanitizeParamName('3d'), 'param3d');
    });

    test('appends underscore for Dart reserved words', () {
      expect(sanitizeParamName('in'), 'in_');
      expect(sanitizeParamName('is'), 'is_');
      expect(sanitizeParamName('default'), 'default_');
      expect(sanitizeParamName('class'), 'class_');
      expect(sanitizeParamName('new'), 'new_');
      expect(sanitizeParamName('return'), 'return_');
      expect(sanitizeParamName('var'), 'var_');
      expect(sanitizeParamName('for'), 'for_');
      expect(sanitizeParamName('while'), 'while_');
      expect(sanitizeParamName('switch'), 'switch_');
    });

    test('does not modify valid non-reserved names', () {
      expect(sanitizeParamName('status'), 'status');
      expect(sanitizeParamName('userId'), 'userId');
      expect(sanitizeParamName('filter'), 'filter');
    });
  });
}
