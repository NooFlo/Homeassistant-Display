# Cross-compile the native helpers for the Kindle (armv7, static).
#
# Requires zig: https://ziglang.org/download/
# Then: make && the binaries land in ../bin/
#
# Static musl build so the binary runs on the Kindle's old glibc-era
# firmware without any library dependencies.
#
# Alternatively use any arm-linux-musleabihf toolchain
# (crosstool-ng, musl-cross-make) by setting CC.

CC     ?= zig cc -target arm-linux-musleabihf
CFLAGS ?= -O2 -static -Wall -Wextra
OUT    ?= ../bin

all: $(OUT)/wait_tap

$(OUT)/wait_tap: src/wait_tap.c
	@mkdir -p $(OUT)
	$(CC) $(CFLAGS) -o $@ src/wait_tap.c

clean:
	rm -f $(OUT)/wait_tap

.PHONY: all clean
