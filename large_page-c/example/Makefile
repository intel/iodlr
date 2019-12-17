CC=gcc
CFLAGS?=-O3
OBJDIR=$(shell realpath obj)
OBJS=$(addprefix $(OBJDIR)/,large_page_example.o)
LDFLAGS=-Wl,-T ../ld.implicit.script -Wl,-z,max-page-size=2097152

.PHONY: all
all: large_page_example

LARGE_PAGE_EXAMPLE_DEPS=    \
	$(OBJS)                   \
	$(OBJDIR)/liblarge_page.a \

large_page_example: $(LARGE_PAGE_EXAMPLE_DEPS)
	$(CC) $(LDFLAGS) $(LARGE_PAGE_EXAMPLE_DEPS) -o $@

$(OBJDIR)/liblarge_page.a:
	$(MAKE) -C .. OUTDIR=$(OBJDIR)

$(OBJDIR)/%.o : %.c
	$(CC) $(CFLAGS) -x c -o $@ -c -I.. $<

$(OBJS): | $(OBJDIR)

$(OBJDIR):
	@mkdir -p $(OBJDIR)

clean:
	$(MAKE) -C .. OUTDIR=$(OBJDIR) clean
	@rm -rf $(OBJDIR) large_page_example
