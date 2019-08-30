all: liblarge_page.a

%.o: %.cc
	@g++ -O3 -c $< -o $@

liblarge_page.a: large_page.o
	@ar rcs liblarge_page.a $<

clean:
	@rm -f *.o *.a
