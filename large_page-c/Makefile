include cflags.mk

OUTDIR?=.
CC=gcc
CFLAGS+=$(CFLAGS_COMMON)
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
