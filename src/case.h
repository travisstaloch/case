#include <stdbool.h>

typedef enum {
  CASE_CAMEL,
  CASE_PASCAL,
  CASE_SNAKE,
  CASE_CONSTANT,
  CASE_KEBAB,
  CASE_HEADER,
  CASE_LOWER,
  CASE_UPPER,
  CASE_CAPITAL,
  CASE_UNKNOWN,
} Case;

// returns a string representation of case_id. ie CASE_CAMEL returns "camel".
char *case_id_to_string(Case case_id);
// returns true for lower, upper and capital
bool case_id_has_options(Case case_id);

bool case_is_lower(const char *text, unsigned long text_len);
bool case_is_upper(const char *text, unsigned long text_len);
bool case_is_capital(const char *text, unsigned long text_len);
bool case_is_camel(const char *text, unsigned long text_len);
bool case_is_pascal(const char *text, unsigned long text_len);
bool case_is_snake(const char *text, unsigned long text_len);
bool case_is_kebab(const char *text, unsigned long text_len);
bool case_is_header(const char *text, unsigned long text_len);
bool case_is_constant(const char *text, unsigned long text_len);

Case case_of(const char *text, unsigned long text_len);

char *case_to(Case case_id, const char *text, unsigned long text_len);
char *case_to_ext(Case case_id, const char *text, unsigned long text_len,
                  char *fill_text, unsigned long fill_len,
                  char keep_apostrophes);
char *case_buf_to(Case case_id, const char *text, unsigned long text_len,
                  char *buf, unsigned long buf_len);
char *case_buf_to_ext(Case case_id, const char *text, unsigned long text_len,
                      char *buf, unsigned long buf_len, char *fill_text,
                      unsigned long fill_len, char keep_apostrophes);
