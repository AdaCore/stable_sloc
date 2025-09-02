class SomeClass{
public:
  int bar (int x){
    return x;
  };

private:
  int* dangerous (int x){
    return &x;
  };

  int identity (int x){
    return x;
  }
};
