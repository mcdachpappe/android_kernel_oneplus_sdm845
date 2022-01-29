#include <linux/set_androidversion.h>
#include <linux/init.h>
#include <linux/moduleparam.h>

__read_mostly static unsigned int pre_android_S_detected = 0;

unsigned int pre_android_S(void) {
	return pre_android_S_detected;
}

static int __init set__androidversion(char *cmdline)
{
	pre_android_S_detected = 1;

	return 0;
}
__setup("pre_android_S", set__androidversion);
