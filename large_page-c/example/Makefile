CC=gcc
CFLAGS?=-O3
OBJDIR=obj
OBJS=$(addprefix $(OBJDIR)/,large_page_example.o large_page.o)
LDFLAGS=-Wl,-T ../ld.implicit.script -Wl,-z,max-page-size=2097152
VPATH=%.c ..

.PHONY: all
all: large_page_example

large_page_example: $(OBJS)
	$(CC) $(LDFLAGS) $(OBJS) -o $@

$(OBJDIR)/%.o : %.c
	$(CC) $(CFLAGS) -x c -o $@ -c -I.. $<

$(OBJS): | $(OBJDIR)

$(OBJDIR):
	@mkdir -p $(OBJDIR)

clean:
	@rm -rf $(OBJDIR) large_page_example
