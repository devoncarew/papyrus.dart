
library utils_test;

import 'package:unittest/unittest.dart';

import 'package:papyrus/utils.dart';

main() {
  group('utils', () {
    test('prettifyDocs', () {
      // TODO:

    });

    test('htmlEscape', () {
      expect('a', htmlEscape('a'));
      expect('&lt;a&gt;', htmlEscape('<a>'));
    });

    test('stringEscape', () {
      // TODO:

    });

    test('escapeBrackets', () {
      expect('a', escapeBrackets('a'));
      expect('_a_', escapeBrackets('<a>'));
    });

    test('stripComments', () {
      // TODO:

    });

    test('ltrim', () {
      expect('a', ltrim('a'));
      expect('a', ltrim(' a'));
      expect('a ', ltrim('a '));
      expect('a ', ltrim(' a '));
    });
  });
}
