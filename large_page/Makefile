all: liblarge_page.a

CC=g++
CFLAGS=-O3 -D_FORTIFY_SOURCE=2 -fsanitize=address -z noexecstack -z relro -z now -fstack-protector -Wformat -Wformat-security -v
AR=ar
RM=/bin/rm

%.o: %.cc
	$(CC) $(CFLAGS) -c $< -o $@

liblarge_page.a: large_page.o
	$(AR) rcs liblarge_page.a $<

clean:
	$(RM) -f *.o *.a
