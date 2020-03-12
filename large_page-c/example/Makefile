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
  filler9.o            \
  filler10.o           \
  filler11.o           \
  filler12.o           \
  filler13.o           \
  filler14.o           \
  filler15.o           \
  filler16.o           \

OBJS=$(addprefix $(OBJDIR)/,$(OBJFILES))
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
