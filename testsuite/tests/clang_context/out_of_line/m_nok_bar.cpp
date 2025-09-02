#include <stdlib.h>

namespace baz {
class My_Class {
public:
  int baz(int *x) {
    if (x == nullptr)
      abort();
    return *x + 1;
  };

  int qux(int x) { return x; };
};
} // namespace Baz

namespace Copy {
class My_Class {
public:
  int baz(int *x) {
    if (x == nullptr)
      abort();
    return *x + 1;
  };

  int qux(int x) { return x; };
};
}

namespace Out_Of_Line {
class Some_Class {
public:
   int baz(int  *x);
};
}

int Out_Of_Line::Some_Class::baz(int *x){
  //  content to modify the hash
  if (x == nullptr)
      abort();
    return *x + 1;
}
