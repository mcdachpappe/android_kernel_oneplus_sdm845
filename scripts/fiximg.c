// SPDX-License-Identifier: GPL-2.0

#include <fcntl.h>
#include <string.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

/*
 * Usage: fiximg /path/to/boot/img 9.0 2018-12-01
 */
int main(int argc, char **argv) {
	int i;
	char *tmp;
	uint32_t data;
	int fd = open(argv[1], O_RDWR);

	int ver[3] = { 0, };
	int spl[3] = { 1, 1, 1 };

	tmp = argv[2];
	for (i = 0; i < 3; i++) {
		tmp = strtok(i ? NULL : tmp, ".");
		if (tmp)
			ver[i] = atoi(tmp);
	}

	printf("%d.%d.%d\n", ver[0], ver[1], ver[2]);

	tmp = argv[3];
	for (i = 0; i < 3; i++) {
		tmp = strtok(i ? NULL : tmp, "-");
		if (tmp)
			spl[i] = atoi(tmp);
	}

	printf("%d-%02d-%02d\n", spl[0], spl[1], spl[2]);

	spl[0] -= 2000;

	data = (((ver[0] << 7 | ver[1]) << 7 | ver[2]) << 7 | spl[0]) << 4 | spl[1];

	lseek(fd, 11 * 4, SEEK_SET);
	write(fd, &data, sizeof(data));
	fsync(fd);
	close(fd);

	return 0;
}
