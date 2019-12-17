# The conditional definition below allows us to test how the implementation
# behaves when a value appears that is not supported by giving a value for
# `ENABLE_LARGE_CODE_PAGES` on the command line.
ENABLE_LARGE_CODE_PAGES?="detect"

ifeq ($(ENABLE_LARGE_CODE_PAGES), "detect")
	PLATFORM := $(shell uname -s)
	ENABLE_LARGE_CODE_PAGES=0
	ifeq ($(PLATFORM),Linux)
		ENABLE_LARGE_CODE_PAGES=1
	endif

# To enable support on more platforms once it's implemented, add more ifeq
# blocks here, such as the example below:
#
#	ifeq ($(PLATFORM),FreeBSD)
#		ENABLE_LARGE_CODE_PAGES=1
#	endif

endif

ifneq ($(ENABLE_LARGE_CODE_PAGES), 0)
	CFLAGS+=-DENABLE_LARGE_CODE_PAGES=$(ENABLE_LARGE_CODE_PAGES)
	CPPFLAGS+=-DENABLE_LARGE_CODE_PAGES=$(ENABLE_LARGE_CODE_PAGES)
endif
