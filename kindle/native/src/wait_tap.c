/* wait_tap - read the touchscreen and report the next tap's coordinates.
 *
 * Usage: wait_tap <touch-device> <timeout-seconds>
 * On a tap: prints "X Y" and exits 0.
 * On timeout: exits 1 (no output).
 *
 * Region mapping happens in the shell engine (kiosk-native.sh); this
 * helper only decodes raw evdev. It handles both multi-touch capable
 * panels (ABS_MT_POSITION_*) and legacy single-touch (ABS_X/ABS_Y).
 *
 * Built with `make` (zig cc cross-compile) - see ../Makefile.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <poll.h>
#include <sys/time.h>

/* From linux/input.h (avoid glibc-kernel header skew on cross builds,
 * which matters: struct input_event must match the kernel's layout. */
#define EV_KEY         0x01
#define EV_ABS         0x03
#define BTN_TOUCH      0x14a
#define ABS_X          0x00
#define ABS_Y          0x01
#define ABS_MT_POSITION_X 0x35
#define ABS_MT_POSITION_Y 0x36
#define ABS_MT_TRACKING_ID 0x39

struct input_event {
    struct timeval time;
    unsigned short  type;
    unsigned short  code;
    int             value;
};

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "usage: %s <touch-device> <timeout-seconds>\n", argv[0]);
        return 2;
    }

    int fd = open(argv[1], O_RDONLY | O_NONBLOCK);
    if (fd < 0) { perror("open"); return 2; }

    int timeout = atoi(argv[2]);
    if (timeout <= 0) timeout = 5;

    struct pollfd pfd = { .fd = fd, .events = POLLIN };

    /* Raw panel coordinates reported so far in this contact. */
    int mt_x = -1, mt_y = -1;      /* from ABS_MT_POSITION_* */
    int st_x = -1, st_y = -1;     /* from ABS_X/ABS_Y */
    int have_mt = 0;

    long deadline = time(NULL) + timeout;
    struct input_event ev;

    while (1) {
        long now = time(NULL);
        if (now >= deadline) { close(fd); return 1; }

        int r = poll(&pfd, 1, (deadline - now) * 1000);
        if (r <= 0) { close(fd); return 1; }

        if (read(fd, &ev, sizeof(ev)) != (ssize_t)sizeof(ev)) continue;

        if (ev.type == EV_ABS) {
            if (ev.code == ABS_MT_POSITION_X) { mt_x = ev.value; have_mt = 1; }
            else if (ev.code == ABS_MT_POSITION_Y) { mt_y = ev.value; have_mt = 1; }
            else if (ev.code == ABS_X) st_x = ev.value;
            else if (ev.code == ABS_Y) st_y = ev.value;
        }
        else if (ev.type == EV_KEY && ev.code == BTN_TOUCH && ev.value == 1) {
            /* Finger down: we have the position if it was reported
             * before or alongside the BTN_TOUCH event. */
            int x, y;
            if (have_mt && mt_x >= 0 && mt_y >= 0) { x = mt_x; y = mt_y; }
            else if (st_x >= 0 && st_y >= 0)      { x = st_x; y = st_y; }
            else continue;                        /* position not seen yet */

            printf("%d %d\n", x, y);
            fflush(stdout);
            close(fd);
            return 0;
        }
    }
}
