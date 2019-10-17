.PHONY: all
all: liblarge_page.a

CC=gcc
CFLAGS=-O3 -D_FORTIFY_SOURCE=2 -z noexecstack -z relro -z now -fstack-protector -Wformat -Wformat-security -Wall
AR=ar
RM=/bin/rm

%.o: %.c
	$(CC) $(CFLAGS) -x c -c $< -o $@

liblarge_page.a: large_page.o
	$(AR) rcs liblarge_page.a $<

.PHONY: clean
clean:
	$(RM) -f *.o *.a
