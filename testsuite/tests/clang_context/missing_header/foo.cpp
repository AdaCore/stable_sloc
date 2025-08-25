#include "some_header.h"

class SomeClass{
public:
  int bar (int x){
    return x;
  };

  int* dangerous (int x){
    return header_namespace::undefined_symbol(x);
  };
};
