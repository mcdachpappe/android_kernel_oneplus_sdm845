#include <linux/set_androidver.h>
#include <linux/init.h>
#include <linux/moduleparam.h>

__read_mostly static unsigned int android12_detected = 0;

unsigned int is_android12(void) {
	return android12_detected;
}

static int __init set__androidver(char *cmdline)
{
	android12_detected = 1;
	return 0;
}
__setup("is_androidR", set__androidver);
