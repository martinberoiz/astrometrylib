# gmake CC=gcc EXTRA_LDFLAGS=-Lvendor/gsl/mingw/x64

OS       ?= $(shell uname -s)
CC       ?= cc
CXX      ?= c++
RM       ?= rm -f
CP       ?= cp -a
MKDIR    ?= mkdir
RMDIR    ?= rmdir
WINDRES  ?= windres
# Solaris/Illumos flavors
# ginstall from coreutils
ifeq ($(OS),SunOS)
INSTALL  ?= ginstall
endif
INSTALL  ?= install
CFLAGS   ?= -Wall
CXXFLAGS ?= -Wall
LDFLAGS  ?= -Wall
ifndef COVERAGE
  CFLAGS   += -O3 -pipe -DNDEBUG -fomit-frame-pointer
  CXXFLAGS += -O3 -pipe -DNDEBUG -fomit-frame-pointer
  LDFLAGS  += -O3 -pipe -DNDEBUG -fomit-frame-pointer
else
  CFLAGS   += -O1 -fno-omit-frame-pointer
  CXXFLAGS += -O1 -fno-omit-frame-pointer
  LDFLAGS  += -O1 -fno-omit-frame-pointer
endif
ifeq "$(ANLIB_GPO)" "generate"
  CFLAGS   += -fprofile-generate
  CXXFLAGS += -fprofile-generate
  LDFLAGS  += -fprofile-generate -Wl,-fprofile-instr-generate
endif
ifeq "$(ANLIB_GPO)" "use"
  CFLAGS   += -fprofile-use
  CXXFLAGS += -fprofile-use
  LDFLAGS  += -fprofile-use -Wl,-fprofile-instr-use
endif
CAT ?= $(if $(filter $(OS),Windows_NT),type,cat)

ifneq (,$(findstring /cygdrive/,$(PATH)))
	UNAME := Cygwin
else
ifneq (,$(findstring Windows_NT,$(OS)))
	UNAME := Windows
else
ifneq (,$(findstring mingw32,$(MAKE)))
	UNAME := Windows
else
ifneq (,$(findstring MINGW32,$(shell uname -s)))
	UNAME := Windows
else
	UNAME := $(shell uname -s)
endif
endif
endif
endif

LDFLAGS += -lgsl

ifndef ANLIB_VERSION
	ifneq ($(wildcard ./.git/ ),)
		ANLIB_VERSION ?= $(shell git describe --abbrev=4 --dirty --always --tags)
	endif
	ifneq ($(wildcard VERSION),)
		ANLIB_VERSION ?= $(shell $(CAT) VERSION)
	endif
endif
ifdef ANLIB_VERSION
	CFLAGS   += -DANLIB_VERSION="\"$(ANLIB_VERSION)\""
	CXXFLAGS += -DANLIB_VERSION="\"$(ANLIB_VERSION)\""
endif

CXXFLAGS += -std=c++11
LDFLAGS  += -std=c++11

ifeq (Windows,$(UNAME))
#	ifneq ($(BUILD),shared)
#		STATIC_ALL     ?= 1
#	endif
	STATIC_LIBGCC    ?= 1
	STATIC_LIBSTDCPP ?= 1
else
	STATIC_ALL       ?= 0
	STATIC_LIBGCC    ?= 0
	STATIC_LIBSTDCPP ?= 0
endif

ifndef ANLIB_PATH
	ANLIB_PATH = $(CURDIR)/astrometrylib
endif
ifdef ANLIB_PATH
	CFLAGS   += -I $(ANLIB_PATH)/src/include
	CXXFLAGS += -I $(ANLIB_PATH)/src/include
else
	# this is needed for mingw
	CFLAGS   += -I include
	CXXFLAGS += -I include
endif

ifndef GSL_PATH
	GSL_PATH += $(CURDIR)/vendor/gsl
endif

ifndef STB_PATH
	STB_PATH += $(CURDIR)/vendor/stb
endif

ifndef SEP_PATH
	SEP_PATH += $(CURDIR)/vendor/sep
endif

CFLAGS += -I $(GSL_PATH)
CXXFLAGS += -I $(GSL_PATH)
CFLAGS += -I $(STB_PATH)
CXXFLAGS += -I $(STB_PATH)
CFLAGS += -I $(SEP_PATH)
CXXFLAGS += -I $(SEP_PATH)
CFLAGS   += -I $(ANLIB_PATH)
CXXFLAGS += -I $(ANLIB_PATH)

CFLAGS   += $(EXTRA_CFLAGS)
CXXFLAGS += $(EXTRA_CXXFLAGS)
LDFLAGS  += $(EXTRA_LDFLAGS)

LDLIBS = -lgsl -lgslcblas
ifneq ($(BUILD),shared)
	ifneq ($(STATIC_LIBSTDCPP),1)
		LDLIBS += -lstdc++
	endif
endif

# link statically into lib
# makes it a lot more portable
# increases size by about 50KB
ifeq ($(STATIC_ALL),1)
	LDFLAGS += -static
endif
ifeq ($(STATIC_LIBGCC),1)
	LDFLAGS += -static-libgcc
endif
ifeq ($(STATIC_LIBSTDCPP),1)
	LDFLAGS += -static-libstdc++
endif

ifeq ($(UNAME),Darwin)
	CFLAGS += -stdlib=libc++
	CXXFLAGS += -stdlib=libc++
	LDFLAGS += -stdlib=libc++
endif

ifneq (Windows,$(UNAME))
	ifneq (FreeBSD,$(UNAME))
		ifneq (OpenBSD,$(UNAME))
			LDFLAGS += -ldl
			LDLIBS += -ldl
		endif
	endif
endif

ifneq ($(BUILD),shared)
	BUILD := static
endif
ifeq ($(DEBUG),1)
	BUILD := debug-$(BUILD)
endif

ifndef TRAVIS_BUILD_DIR
	ifeq ($(OS),SunOS)
		PREFIX ?= /opt/local
	else
		PREFIX ?= /usr/local
	endif
else
	PREFIX ?= $(TRAVIS_BUILD_DIR)
endif

RESOURCES =
STATICLIB = lib/astrometrylib.a
SHAREDLIB = lib/astrometrylib.so
LIB_STATIC = $(ANLIB_PATH)/lib/astrometrylib.a
LIB_SHARED = $(ANLIB_PATH)/lib/astrometrylib.so
ifeq ($(UNAME),Darwin)
	SHAREDLIB = lib/astrometrylib.dylib
	LIB_SHARED = $(ANLIB_PATH)/lib/astrometrylib.dylib
endif
ifeq (Windows,$(UNAME))
	RESOURCES += res/resource.rc
	SHAREDLIB  = lib/astrometrylib.dll
	ifeq (shared,$(BUILD))
		CFLAGS    += -D ADD_EXPORTS
		CXXFLAGS  += -D ADD_EXPORTS
		LIB_SHARED  = $(ANLIB_PATH)/lib/astrometrylib.dll
	endif
else
ifneq (Cygwin,$(UNAME))
	CFLAGS   += -fPIC
	CXXFLAGS += -fPIC
	LDFLAGS  += -fPIC
endif
endif

include Makefile.conf
OBJECTS = $(addprefix ./,$(SOURCES:.cpp=.o))
COBJECTS = $(addprefix ./,$(CSOURCES:.c=.o))
HEADOBJS = $(addprefix ./,$(HPPFILES:.hpp=.hpp.gch))
RCOBJECTS = $(RESOURCES:.rc=.o)

DEBUG_LVL ?= NONE

CLEANUPS ?=
CLEANUPS += $(RCOBJECTS)
CLEANUPS += $(COBJECTS)
CLEANUPS += $(OBJECTS)
CLEANUPS += $(HEADOBJS)
CLEANUPS += $(ANLIB_LIB)

demog.exe: $(BUILD)
	$(CXX) $(OBJECTS) $(COBJECTS) $(LDFLAGS) $(LDLIBS) -o demo/demo.exe

all: demo.exe

debug: $(BUILD)

debug-static: LDFLAGS := -g $(filter-out -O2,$(LDFLAGS))
debug-static: CFLAGS := -g -DDEBUG -DDEBUG_LVL="$(DEBUG_LVL)" $(filter-out -O2,$(CFLAGS))
debug-static: CXXFLAGS := -g -DDEBUG -DDEBUG_LVL="$(DEBUG_LVL)" $(filter-out -O2,$(CXXFLAGS))
debug-static: static

debug-shared: LDFLAGS := -g $(filter-out -O2,$(LDFLAGS))
debug-shared: CFLAGS := -g -DDEBUG -DDEBUG_LVL="$(DEBUG_LVL)" $(filter-out -O2,$(CFLAGS))
debug-shared: CXXFLAGS := -g -DDEBUG -DDEBUG_LVL="$(DEBUG_LVL)" $(filter-out -O2,$(CXXFLAGS))
debug-shared: shared

lib:
	$(MKDIR) lib

lib/astrometrylib.a: $(COBJECTS) $(OBJECTS) | lib
	$(AR) rcvs $@ $(COBJECTS) $(OBJECTS)

lib/astrometrylib.so: $(COBJECTS) $(OBJECTS) | lib
	$(CXX) -shared $(LDFLAGS) -o $@ $(COBJECTS) $(OBJECTS) $(LDLIBS)

lib/astrometrylib.dylib: $(COBJECTS) $(OBJECTS) | lib
	$(CXX) -shared $(LDFLAGS) -o $@ $(COBJECTS) $(OBJECTS) $(LDLIBS) \
	-install_name @rpath/astrometrylib.dylib

lib/astrometrylib.dll: $(COBJECTS) $(OBJECTS) $(RCOBJECTS) | lib
	$(CXX) -shared $(LDFLAGS) -o $@ $(COBJECTS) $(OBJECTS) $(RCOBJECTS) $(LDLIBS) \
	-s -Wl,--subsystem,windows,--out-implib,lib/astrometrylib.a

$(RCOBJECTS): %.o: %.rc
	$(WINDRES) -i $< -o $@

$(OBJECTS): %.o: %.cpp
	$(CXX) $(CXXFLAGS) -c -o $@ $<

$(COBJECTS): %.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(HEADOBJS): %.hpp.gch: %.hpp
	$(CXX) $(CXXFLAGS) -x c++-header -c -o $@ $<

%: %.o static
	$(CXX) $(CXXFLAGS) -o $@ $+ $(LDFLAGS) $(LDLIBS)

static: $(STATICLIB)
shared: $(SHAREDLIB)

$(DESTDIR)$(PREFIX):
	$(MKDIR) $(DESTDIR)$(PREFIX)

$(DESTDIR)$(PREFIX)/lib: | $(DESTDIR)$(PREFIX)
	$(MKDIR) $(DESTDIR)$(PREFIX)/lib

$(DESTDIR)$(PREFIX)/include: | $(DESTDIR)$(PREFIX)
	$(MKDIR) $(DESTDIR)$(PREFIX)/include

$(DESTDIR)$(PREFIX)/lib/%.a: lib/%.a \
                             | $(DESTDIR)$(PREFIX)/lib
	@$(INSTALL) -v -m0755 "$<" "$@"

$(DESTDIR)$(PREFIX)/lib/%.so: lib/%.so \
                             | $(DESTDIR)$(PREFIX)/lib
	@$(INSTALL) -v -m0755 "$<" "$@"

$(DESTDIR)$(PREFIX)/lib/%.dll: lib/%.dll \
                               | $(DESTDIR)$(PREFIX)/lib
	@$(INSTALL) -v -m0755 "$<" "$@"

$(DESTDIR)$(PREFIX)/lib/%.dylib: lib/%.dylib \
                               | $(DESTDIR)$(PREFIX)/lib
	@$(INSTALL) -v -m0755 "$<" "$@"

test: test_build

clean-objects: | lib
	-$(RM) lib/*.a lib/*.so lib/*.dll lib/*.dylib lib/*.la
	-$(RMDIR) lib
clean: clean-objects
	$(RM) $(CLEANUPS)

.PHONY: all static shared version \
        clean clean-objects
.DELETE_ON_ERROR:
