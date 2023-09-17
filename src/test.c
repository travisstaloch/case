// run this file
// $ zig build && zig run src/test.c -lc zig-out/lib/libcase.a
// valgrind leak check
// $ zig build && zig build-exe src/test.c -lc zig-out/lib/libcase.a && valgrind
// --leak-check=full --show-leak-kinds=all --track-origins=yes test

#include "case.h";
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(void) {
  char *s = "foo_bar";
  int slen = strlen(s);
  {
    char *actual = case_to(CASE_HEADER, s, slen);
    char *expected = "Foo-Bar";
    if (memcmp(expected, actual, slen) != 0) {
      printf("ERROR: expected '%s' got '%s'\n", expected, actual);
      free(actual);
      exit(1);
    }
    free(actual);
  }
  char buf[20];
  int buflen = sizeof(buf);
  {
    char *actual = case_buf_to(CASE_CONSTANT, s, slen, buf, buflen);
    char *expected = "FOO_BAR";
    if (memcmp(expected, actual, slen) != 0) {
      printf("ERROR: expected '%s' got '%s'\n", expected, actual);
      exit(1);
    }
  }

  const char *expecteds[CASE_UNKNOWN];
  expecteds[CASE_CAMEL] = "fooBar";
  expecteds[CASE_PASCAL] = "FooBar";
  expecteds[CASE_SNAKE] = "foo_bar";
  expecteds[CASE_CONSTANT] = "FOO_BAR";
  expecteds[CASE_KEBAB] = "foo-bar";
  expecteds[CASE_HEADER] = "Foo-Bar";
  expecteds[CASE_LOWER] = "foo bar";
  expecteds[CASE_UPPER] = "FOO BAR";
  expecteds[CASE_CAPITAL] = "Foo Bar";

  // test all cases
  for (char i = 0; i < CASE_UNKNOWN; ++i) {
    const char *expected = expecteds[i];
    int len = strlen(expected);
    char *case_str = case_id_to_string(i);
    { // case_to
      char *actual;
      if (case_id_has_options(i))
        actual = case_to_ext(i, s, slen, "", 0, false);
      else
        actual = case_to(i, s, slen);
      // printf("expected=%s actual=%s\n", expected, actual);
      if (memcmp(expected, actual, len) != 0) {
        printf("ERROR: expected to-%s '%s':%u got '%s':%d\n", case_str,
               expected, len, actual, strlen(actual));
        free(actual);
        exit(1);
      }
      free(actual);
    }
    { // case_buf_to
      char *actual;
      if (case_id_has_options(i))
        actual = case_buf_to_ext(i, s, slen, buf, buflen, "", 0, false);
      else
        actual = case_buf_to(i, s, slen, buf, buflen);
      // printf("slen=%d expected=%s actual=%s\n", slen, expected, actual);
      if (memcmp(expected, actual, len) != 0) {
        printf("ERROR: expected to-%s '%s':%u got '%s':%d\n", case_str,
               expected, len, actual, strlen(actual));
        exit(1);
      }
    }
    { // case_of
      char case_id = case_of(expected, len);
      // printf("case_id=%d str=%s\n", case_id, case_str);
      if (case_id != i) {
        printf("ERROR: expected case_of('%s')='%s'. got %u='%s'\n", expected,
               case_str, case_id, case_id_to_string(case_id));
        exit(1);
      }
    }
    { // case_is_
      bool ok = false;
      switch (i) {
      case CASE_CAMEL: {
        ok = case_is_camel(expected, len);
      }; break;
      case CASE_PASCAL: {
        ok = case_is_pascal(expected, len);
      }; break;
      case CASE_SNAKE: {
        ok = case_is_snake(expected, len);
      }; break;
      case CASE_CONSTANT: {
        ok = case_is_constant(expected, len);
      }; break;
      case CASE_KEBAB: {
        ok = case_is_kebab(expected, len);
      }; break;
      case CASE_HEADER: {
        ok = case_is_header(expected, len);
      }; break;
      case CASE_LOWER: {
        ok = case_is_lower(expected, len);
      }; break;
      case CASE_UPPER: {
        ok = case_is_upper(expected, len);
      }; break;
      case CASE_CAPITAL: {
        ok = case_is_capital(expected, len);
      }; break;
      default: {
        assert(0 && "unreachable");
      }; break;
      }
      // printf("case_id=%d str=%s\n", case_id, case_str);
      if (!ok) {
        printf("ERROR: expected case_is_%s('%s'). got false\n", case_str,
               expected, case_str);
        exit(1);
      }
    }
  }
  return 0;
}