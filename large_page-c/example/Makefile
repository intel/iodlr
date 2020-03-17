CC=gcc
CFLAGS?=-O3
OBJDIR=$(shell realpath obj)

# align.o must be the first in the list of object files because it must be the
# first item passed to the linker. This will ensure that the text section will
# start at a 2 MiB offset, thus avoiding a scenario where too large a portion of
# it gets snipped off by the necessity that the region getting remapped to large
# pages must start at a 2 MiB boundary.
OBJFILES=              \
  align.o              \
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
LDFLAGS=-Wl,-z,max-page-size=2097152

.PHONY: all
all: large_page_example

LARGE_PAGE_EXAMPLE_DEPS=    \
	$(OBJS)                   \
	$(OBJDIR)/liblarge_page.a \

large_page_example: $(LARGE_PAGE_EXAMPLE_DEPS)
	$(CC) $(LDFLAGS) $(LARGE_PAGE_EXAMPLE_DEPS) -o $@

$(OBJDIR)/liblarge_page.a:
	$(MAKE) -C .. OUTDIR=$(OBJDIR)

$(OBJDIR)/align.o : align.S
	gcc -c -o $@ $<

$(OBJDIR)/%.o : %.c
	$(CC) $(CFLAGS) -x c -o $@ -c -I.. $<

$(OBJS): | $(OBJDIR)

$(OBJDIR):
	@mkdir -p $(OBJDIR)

clean:
	$(MAKE) -C .. OUTDIR=$(OBJDIR) clean
	@rm -rf $(OBJDIR) large_page_example
