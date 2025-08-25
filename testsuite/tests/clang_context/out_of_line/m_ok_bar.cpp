#include <stdlib.h>

namespace Out_Of_Line {
class Some_Class {
public:
   int baz(int  *x);
};
}

int Out_Of_Line::Some_Class::baz(int *x){
  if (x == nullptr)
      abort();
    return *x + 1;
}
