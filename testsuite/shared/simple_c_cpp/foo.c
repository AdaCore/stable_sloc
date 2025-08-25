#include <stdlib.h>
int foo (int* x) {
  if (x == NULL)
    abort();
  return *x - 1;
}