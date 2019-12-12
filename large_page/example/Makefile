OBJDIR = obj
OBJS = $(addprefix $(OBJDIR)/,large_page_example.o large_page.o)
CPPFLAGS=-O3 -std=c++11 -D_FORTIFY_SOURCE=2 -fsanitize=address -z noexecstack -z relro -z now -fstack-protector -Wformat -Wformat-security -Wall
LDFLAGS = -Wl,-T ../ld.implicit.script -fsanitize=address
VPATH =  %.cc ..

all: large_page_example

large_page_example: $(OBJS)
	@g++ $(OBJS) $(LDFLAGS) -o $@

$(OBJDIR)/%.o : %.cc
	@g++ $(CPPFLAGS) -o $@ -c -I.. $<

$(OBJS): | $(OBJDIR)

$(OBJDIR):
	@mkdir -p $(OBJDIR)

clean:
	@rm -rf $(OBJDIR) large_page_example
