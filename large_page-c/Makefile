OUTDIR?=.
CC=gcc
CFLAGS=-O3 -D_FORTIFY_SOURCE=2 -z noexecstack -z relro -z now -fstack-protector -Wformat -Wformat-security -Wall
AR=ar
RM=/bin/rm

.PHONY: all
all: $(OUTDIR)/liblarge_page.a

# Append -DENABLE_LARGE_CODE_PAGES=1 to CFLAGS on supported platforms.
include ../detect-platform.mk

%.o: %.c
	$(CC) $(CFLAGS) -x c -c $< -o $@

$(OUTDIR)/liblarge_page.a: large_page.o
	$(AR) rcs $@ $<

.PHONY: clean
clean:
	$(RM) -f *.o $(OUTDIR)/*.a
