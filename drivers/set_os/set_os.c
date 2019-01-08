  
/*
 * Made by pappschlumpf (Erik Müller)
 */

#include <linux/set_os.h>

#include <linux/init.h>
#include <linux/moduleparam.h>

__read_mostly static unsigned int oos_detected = 1;

unsigned int is_oos(void) {
	return oos_detected;
}

static int __init set__custom_os(char *cmdline)
{
	oos_detected = 0;
	return 0;
}
__setup("is_custom_rom", set__custom_os);
