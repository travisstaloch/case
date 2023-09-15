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

char* case_upper(
  char* text, 
  unsigned long text_len, 
  char* fill_text, 
  unsigned long fill_len, 
  char keep_apostrophes
);

char* case_lower(
  char* text, 
  unsigned long text_len, 
  char* fill_text, 
  unsigned long fill_len, 
  char keep_apostrophes
);

char* case_capital(
  char* text, 
  unsigned long text_len, 
  char* fill_text, 
  unsigned long fill_len, 
  char keep_apostrophes
);

char* case_header(char* text, unsigned long text_len);
char* case_constant(char* text, unsigned long text_len);
char* case_snake(char* text, unsigned long text_len);
char* case_kebab(char* text, unsigned long text_len);
char* case_camel(char* text, unsigned long text_len);
char* case_pascal(char* text, unsigned long text_len);

char* case_to_ext(
  Case case_id, 
  char* text, 
  unsigned long text_len,
  char* fill_text, 
  unsigned long fill_len, 
  char keep_apostrophes
);


bool case_is_lower(char* text, unsigned long text_len);
bool case_is_upper(char* text, unsigned long text_len);
bool case_is_capital(char* text, unsigned long text_len);
bool case_is_camel(char* text, unsigned long text_len);
bool case_is_pascal(char* text, unsigned long text_len);
bool case_is_snake(char* text, unsigned long text_len);
bool case_is_kebab(char* text, unsigned long text_len);
bool case_is_header(char* text, unsigned long text_len);
bool case_is_constant(char* text, unsigned long text_len);

char* case_to(Case case_id, char* text, unsigned long text_len);
char  case_of(char* text, unsigned long text_len);
char* case_id_to_string(Case case_id);
