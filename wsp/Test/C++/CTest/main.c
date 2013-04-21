#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
	char s[] = "/home/eph/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/home/eph/CodeSourcery/Sourcery_G++_Lite/bin";
	const char tk[] = "\\";
	
	puts(s);
	puts("-------------------------");
	
	char *p = NULL;
	
	p = strtok(s, tk);
	while ( p )
	{
		puts(p);
		p = strtok(NULL, tk);
	}

	
	printf("hello world\n");
	return 0;
}
