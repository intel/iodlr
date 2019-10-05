CC=gcc
CFLAGS=-O3
OBJDIR = obj
OBJS = $(addprefix $(OBJDIR)/,large_page_example.o large_page.o)
LDFLAGS = -Wl,-T ../ld.implicit.script
VPATH =  %.cc ..

all: large_page_example

large_page_example: $(OBJS)
	$(CC) $(OBJS) $(LDFLAGS) -o $@

$(OBJDIR)/%.o : %.cc
	$(CC) $(CFLAGS) -x c -o $@ -c -I.. $<

$(OBJS): | $(OBJDIR)

$(OBJDIR):
	@mkdir -p $(OBJDIR)

clean:
	@rm -rf $(OBJDIR) large_page_example
