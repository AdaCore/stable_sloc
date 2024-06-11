PREFIX=

BUILD_MODE?=dev

PROCESSORS=0

all: build

build: build-static build-static-pic build-relocatable
build-%:
	gprbuild -Pstable_sloc.gpr \
			-XSTABLE_SLOC_BUILD_MODE=$(BUILD_MODE) \
			-XLIBRARY_TYPE=$* \
			-p -j$(PROCESSORS)

install: install-static install-static-pic install-relocatable
install-%:
	gprinstall -p -Pstable_sloc.gpr \
			-XSTABLE_SLOC_BUILD_MODE=$(BUILD_MODE) \
			-XLIBRARY_TYPE=$* \
			--prefix=$(PREFIX) \
			--build-name=$* \
			--build-var=LIBRARY_TYPE \
			--build-var=STABLE_SLOC_LIBRARY_TYPE

clean: clean-static clean-static-pic clean-relocatable
clean-%:
	gprclean -Pstable_sloc.gpr \
			-XSTABLE_SLOC_BUILD_MODE=$(BUILD_MODE) \
			-XLIBRARY_TYPE=$*

cli_build:
	gprbuild -p -Pstable_sloc_cli.gpr \
			-XSTABLE_SLOC_BUILD_MODE=$(BUILD_MODE) \
			-XLIBRARY_TYPE=static -p -j$(PROCESSORS)
