

#define MACRO	0

#define TRUE	1
#define FALSE	(!TRUE)

int g_a,
	g_b,
	g_c;

/* ========================================================================== */
/* 类型定义, 名空间, 作用域路径测试 */

namespace TestNamespace {
	template<typename T>
	class TestTemplate {
		T t;	// 模版
	};

	union TestUnion {
		char x;
		short y;
		int z;
	};
	
	class Foo {
	public:
		struct {
			char A;		/* 一些注释 */
			short B;	// 另外一些注释
		} testAnonStruct;

        typedef struct TestTypedef_st {
            char a;
            short b;
            int c;
            long d;
            long long e;
        } TestTypedef;
		typedef TestTemplate<int> NTI;
        typedef int INT;
		NTI nti;
	protected:
		void Func(void)
		{
			return;
		}
		
	private:
		char m_a;
		short m_b;
		int m_c;
	};
};

namespace TestNamespace2 {
	union TestUnion2 {
		char x2;
		short y2;
		int z2;
	};
}

typedef struct TestTypedef_st {
	char a;
	short b;
	int c;
	long d;
	long long e;
} TestTypedef;

/* ========================================================================== */
/* 类与模版测试 */
template <typename T>
inline const T& Maximum(const T& x,const T& y)
{
	if(y > x)
		return y;
	else
		return x;
}

/* 类前注释 */
template<typename T1, typename T2>
class TestTemplate {
public:
	T t;
};

class Foo {
public:
	char m_a;
	short m_b;
	int m_c;
	void Func(void)
	{
		
	}
};

class Test {
public:
	MyTemplate<Foo> m_foo;
	void Func(void)
	{
		
	}
};

class DFoo : public Foo {
public:
	TestTemplate<Foo, Foo> m_foo;

	Foo & Get() { return Foo(); }
	
	DFoo(){}
	~DFoo(){}
};

/* ========================================================================== */
/* 枚举测试 */
enum {
	anon_en1,
	anon_en2,
	anon_en3
};

enum ENUM {
	en1,
	en2,
	en3
};

/* ========================================================================== */
/* 宏处理测试 */



struct {
	char a;
	short b;
} AnonStruct;

struct Struct {
	char a;
	short b;
	int c;
};





#define TYPEDEF typedef

MODULE_VERSION("$Revision: 1.41 $")

TYPEDEF struct {
	int i;
} STRUCT;

#define XXXXX

XXXXX int XXXXX Func2();


