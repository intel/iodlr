CC=gcc
CFLAGS?=-O3
OBJDIR=$(shell realpath obj)

OBJFILES=              \
  large_page_example.o \
  filler1.o            \
  filler2.o            \
  filler3.o            \
  filler4.o            \
  filler5.o            \
  filler6.o            \
  filler7.o            \
  filler8.o            \

OBJS=$(addprefix $(OBJDIR)/,$(OBJFILES))

.PHONY: all
all: large_page_example

LARGE_PAGE_EXAMPLE_DEPS=    \
	$(OBJS)                   \
	$(OBJDIR)/liblarge_page.a \

large_page_example: $(LARGE_PAGE_EXAMPLE_DEPS)
	$(CC) $(LDFLAGS) $(LARGE_PAGE_EXAMPLE_DEPS) -o $@

$(OBJDIR)/liblarge_page.a:
	$(MAKE) -C .. OUTDIR=$(OBJDIR)

$(OBJDIR)/%.o : %.c $(OBJDIR)
	$(CC) $(CFLAGS) -x c -o $@ -c -I.. $<

$(OBJS): | $(OBJDIR)

$(OBJDIR):
	mkdir -p $(OBJDIR)

clean:
	$(MAKE) -C .. OUTDIR=$(OBJDIR) clean
	rm -rf $(OBJDIR) large_page_example
