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
  });
}
