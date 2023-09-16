// run this file
// $ zig build && zig run src/test.c -lc zig-out/lib/libcase.a 
// valgrind leak check
// $ zig build && zig build-exe src/test.c -lc zig-out/lib/libcase.a && valgrind --leak-check=full --show-leak-kinds=all --track-origins=yes test

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "case.h";

int main(void)
{
  char* s = "foo_bar";
  int slen = strlen(s);
  {
    char* actual =  case_upper(s, slen, NULL, 0, 1);
    char* expected = "FOO BAR";
    if(memcmp(expected, actual, slen) != 0) {
      printf("ERROR: expected '%s' got '%s'\n", expected, actual);
      exit(1);
    }
    free(actual);
  }
  {
    char* actual =  case_to(CASE_HEADER, s, slen);
    char* expected = "Foo-Bar";
    if(memcmp(expected, actual, slen) != 0) {
      printf("ERROR: expected '%s' got '%s'\n", expected, actual);
      free(actual);
      exit(1);
    }
    free(actual);
  }
  char buf[20];
  int buflen = sizeof(buf);
  {
    char* actual =  case_to_buf(CASE_CONSTANT, s, slen, buf, buflen);
    char* expected = "FOO_BAR";
    if(memcmp(expected, actual, slen) != 0) {
      printf("ERROR: expected '%s' got '%s'\n", expected, actual);
      exit(1);
    }
  }

  const char* expecteds[CASE_UNKNOWN];
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
    const char* expected = expecteds[i];
    int len = strlen(expected);
    char* case_str = case_id_to_string(i);
    { // case_to
      char* actual = case_to(i, s, slen);
      // printf("slen=%d expected=%s actual=%s\n", slen, expected, actual);
      if(memcmp(expected, actual, len) != 0) {
        printf("ERROR: expected to-%s '%s':%u got '%s':%d\n", 
          case_str, expected, len, actual, strlen(actual));
        free(actual);
        exit(1);
      }
      free(actual);
    }
    { // case_to_buf
      char* actual = case_to_buf(i, s, slen, buf, buflen);
      // printf("slen=%d expected=%s actual=%s\n", slen, expected, actual);
      if(memcmp(expected, actual, len) != 0) {
        printf("ERROR: expected to-%s '%s':%u got '%s':%d\n", 
          case_str, expected, len, actual, strlen(actual));
        exit(1);
      }
    }
    { // case_of
      char case_id = case_of(expected, len);
      // printf("case_id=%d str=%s\n", case_id, case_str);
      if(case_id != i) {
        printf("ERROR: expected case_of('%s')='%s'. got %u='%s'\n", 
          expected, case_str, case_id, case_id_to_string(case_id));
        exit(1);
      }
    }
  }
  return 0;
}