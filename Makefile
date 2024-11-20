PREFIX=

BUILD_MODE?=dev

PROCESSORS=0

HOST_UNAME=$(shell uname -s)

ifneq (,$(filter MINGW% CYGW%, $(HOST_UNAME)))
HOST_OS=windows
exeext=.exe
endif
ifneq (,$(filter Linux, $(HOST_UNAME)))
HOST_OS=linux
exeext=
endif

RM=rm -f
CP=cp -pf
MKDIR=mkdir -p

GPRBUILD=gprbuild
GPRINSTALL=gprinstall

ifdef INSTR
INSTR_GPR_FLAGS=--src-subdirs=gnatcov-instr --implicit-with=gnatcov_rts.gpr
endif

all: build

build: instr build-static build-static-pic build-relocatable cli_build

instr:
ifdef INSTR
	gnatcov instrument -Pstable_sloc_cli.gpr -cstmt $(GPRFLAGS)
endif

build-%:
	$(GPRBUILD) -Pstable_sloc.gpr \
			-XSTABLE_SLOC_BUILD_MODE=$(BUILD_MODE) \
			-XLIBRARY_TYPE=$* \
			-p -j$(PROCESSORS) \
			$(INSTR_GPR_FLAGS) \
			$(GPRFLAGS)

cli_build:
	$(GPRBUILD) -p -Pstable_sloc_cli.gpr \
			-XSTABLE_SLOC_BUILD_MODE=$(BUILD_MODE) \
			-XLIBRARY_TYPE=static -p -j$(PROCESSORS) \
			$(INSTR_GPR_FLAGS) \
			$(GPRFLAGS)

install: install-static install-static-pic install-relocatable
	$(MKDIR) $(PREFIX)/bin
	$(CP) bin/stable_sloc_cli$(exeext) $(PREFIX)/bin

install-%:
	$(GPRINSTALL) -p -Pstable_sloc.gpr \
			-XSTABLE_SLOC_BUILD_MODE=$(BUILD_MODE) \
			-XLIBRARY_TYPE=$* \
			--prefix=$(PREFIX) \
			--build-name=$* \
			--build-var=LIBRARY_TYPE \
			--build-var=STABLE_SLOC_LIBRARY_TYPE \
			$(INSTR_GPR_FLAGS) \
			$(GPRFLAGS)

clean: clean-static clean-static-pic clean-relocatable
clean-%:
	gprclean -Pstable_sloc.gpr \
			-XSTABLE_SLOC_BUILD_MODE=$(BUILD_MODE) \
			-XLIBRARY_TYPE=$* \
			$(INSTR_GPR_FLAGS) \
			$(GPRFLAGS)
