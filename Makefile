PREFIX?=$(CURDIR)/local

BUILD_MODE?=dev

PROCESSORS=0

HOST_UNAME=$(shell uname -s)

ifneq (,$(filter MINGW% CYGW%, $(HOST_UNAME)))
HOST_OS=windows
exeext=.exe
PATH_SEP=;
endif
ifneq (,$(filter Linux, $(HOST_UNAME)))
HOST_OS=linux
exeext=
PATH_SEP=:
endif

RM=rm -f
CP=cp -pf
MKDIR=mkdir -p

GPRBUILD=gprbuild
GPRINSTALL=gprinstall

ifdef INSTR
INSTR_GPR_FLAGS=--src-subdirs=gnatcov-instr --implicit-with=gnatcov_rts.gpr
endif

C_SUPPORT?=True
ifeq ($(C_SUPPORT), True)
include libclang_common.mk
LLVM_LINK_FLAGS = -largs $(LD_FLAGS)
else
CURRENT_DIR := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))
GPR_PROJECT_PATH := $(CURRENT_DIR)/gpr_stubs$(PATH_SEP)$(GPR_PROJECT_PATH)
LLVM_LINK_FLAGS=
endif

all: build

build: instr build-static cli_build

instr:
ifdef INSTR
	gnatcov instrument -Pstable_sloc_cli.gpr -cstmt $(GPRFLAGS)
endif

build-%:
	$(GPRBUILD) -Pstable_sloc.gpr \
			-XSTABLE_SLOC_BUILD_MODE=$(BUILD_MODE) \
			-XLIBRARY_TYPE=$* \
			-XC_SUPPORT=$(C_SUPPORT) \
			-p -j$(PROCESSORS) \
			$(INSTR_GPR_FLAGS) \
			$(LLVM_LINK_FLAGS) \
			$(GPRFLAGS)

cli_build:
	$(GPRBUILD) -p -Pstable_sloc_cli.gpr \
			-XSTABLE_SLOC_BUILD_MODE=$(BUILD_MODE) \
			-XLIBRARY_TYPE=static -p -j$(PROCESSORS) \
			-XC_SUPPORT=$(C_SUPPORT) \
			$(INSTR_GPR_FLAGS) \
			$(LLVM_LINK_FLAGS) \
			$(GPRFLAGS)

install: install-static
	$(MKDIR) $(PREFIX)/bin
	$(CP) bin/stable_sloc_cli$(exeext) $(PREFIX)/bin

install-%:
	$(GPRINSTALL) -f -p -Pstable_sloc.gpr \
			-XSTABLE_SLOC_BUILD_MODE=$(BUILD_MODE) \
			-XLIBRARY_TYPE=$* \
			-XC_SUPPORT=$(C_SUPPORT) \
			--prefix=$(PREFIX) \
			--build-name=$* \
			--build-var=LIBRARY_TYPE \
			--build-var=STABLE_SLOC_LIBRARY_TYPE \
			$(INSTR_GPR_FLAGS) \
			$(GPRFLAGS)

clean: clean-static
clean-%:
	gprclean -Pstable_sloc.gpr \
			-XSTABLE_SLOC_BUILD_MODE=$(BUILD_MODE) \
			-XLIBRARY_TYPE=$* \
			-XC_SUPPORT=$(C_SUPPORT) \
			$(INSTR_GPR_FLAGS) \
			$(GPRFLAGS)
