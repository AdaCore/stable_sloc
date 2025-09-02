#include "defs.h"

class SomeClass{
public:
  int bar (int x){
    return x;
  };

  int* PREFIX(dangerous) (int x){
    return &x;
  };
};
