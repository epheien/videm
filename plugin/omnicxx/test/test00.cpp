class A {
public:
    A *a;
    A *af(){  if(this->a); return 0;} // test
    class B {
    };
};

class B {
public:
    B *b;
    A a;
    A *f(){return 0;}
    static B *ff() {return 0;}
};

class C {
public:
    C *c;
    B b;
    class D {
        C *c;
    };
};

class D {
public:
    D *d;
    C c;
};

/* 测试用例
    cases = [
        # general
        "A::B C::D::",
        "A::B()->C().",
        "A::B().C->",
        "A->B().",
        "A->B.",
        "Z Y = ((A*)B)->C.",
        "(A*)B()->C.",
        "static_cast<A*>(B)->C.",
        "A(B.C()->",
        "(A**)::B.",
        "B<X,Y>(Z)->",
        "A<B>::C<D, E>::F.g.",
        "A(B.C()->",
        "A(::B.C()->",

        # 模板实例化
        "A<B, C>::",
    ]
*/

B aa;

int main(int argc, char **argv)
{
    // new
    // A::B *pa = new A::
    A::B *ptr = new A::B();   // test*2; 6 and 24

    A aa;

    class Clazz {
        A xxx;
        Clazz()
        {
            // if ( this->a.
            if (this->xxx.a) // testx
                this->xxx.a = 0;
        }
    };

    int arr[10] = {0};
    A **a;
    // 数组
    // A[B][C[D]].
    a[0][arr[1]].a = 0; // test

    // C++ cast
    // dynamic_cast<A<Z, Y, X> *>(B.b())->C.
    static_cast<B*>(0)->b = 0; // test
    static_cast<B*>((void *)a[0]->af())->a.a = 0; // test

    B b;
    // C cast
    // ((A*)B.b)->C.
    // ((A*)B.b())->C.
    ((A*)b.b)->a->a = 0; // test
    ((A*)b.f())->a->a = 0; // test

    // global
    // ::A->
    // A(::B.
    ::aa.b = 0; // test
    aa.a = 0; // test

    // test; for all

    return 0;
}
