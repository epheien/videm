#include "main.h"

char c = "senkg\"xyz\"snekg ", /* 注释 */ a = "abxnk\"en", //再注释, 
b = 100;

using namespace TestNamespace;
using namespace TestNamespace2;

/* 类前注释 */
template<typename T1, typename T2> class TestTemplate2 {
public:
	T1 t1;	/* 模版1 */
private:
	T2 t2;	// 模版2
};


int
Print(int a, 
		int b)
{
	int d;
	int c = a;
	//printf("%d\n", c);
	return 0;
}


int main(int argc, char **argv)
{
	DFoo dfoo;
	dfoo.testAnonStruct;
	TestNamespace::Foo nf;
	MyClass mc; /* FIXME: 无法补全 MyClass */
	mc.foo(); /* FIXME: 无法补全 MyClass 成员 */
	nf; /* FIXME: 无名结构变量误认为类的变量 */
	dfoo.testAnonStruct.a; /* FIXME: 无名结构变量不能补全 */
	Foo foo; /* FIXME: omnicpp 不能解析, 可能原因是搜索声明出错. */
	foo;
	//vector<Foo> vf;
	//vf.at(0);
	return 0;
}
