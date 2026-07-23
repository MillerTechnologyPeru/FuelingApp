#---------------------------------------------------------------------------------
# NDS/ -- Nintendo DS port of the Fueling app, built with Embedded Swift.
#
# Build system copied from ClassicUI's ports/NDS (branch feature/nds), itself
# modeled on MillerTechnologyPeru/swift-embedded-nds: everything is compiled
# whole-module for armv5te-none-none-eabi (an exact match for the DS's
# ARM946E-S), linked against calico-based libnds, and packaged with ndstool
# using calico's prebuilt ARM7.
#
# The port reuses the real model stack as Embedded Swift modules, compiled in
# dependency order: FoundationEmbedded (PureSwift/swift-embedded-foundation)
# -> CoreModel (in-memory store + FetchRequest evaluation engine)
# -> CoreFueling (the shared domain entities and search predicates from this
# repository) -> the port sources in source/.
#
# Screen layout (the inverse of ClassicUI's port): the *top* screen hosts the
# UI through the software rasterizer in source/Renderer.swift, drawn into a
# double-buffered 16bpp bitmap background on the main engine; the *bottom*
# (touch) screen hosts libnds' on-screen keyboard on the sub engine, used to
# type into the locations search filter.
#
# Prerequisites:
#   - devkitPro with devkitARM, libnds, calico, ndstool
#     (export DEVKITPRO=/opt/devkitpro, DEVKITARM=$DEVKITPRO/devkitARM)
#   - A Swift toolchain whose Embedded stdlib ships an armv5te-none-none-eabi
#     slice. Release toolchains only ship armv4t; a recent `main` development
#     snapshot is needed. Override with `make SWIFTC=/path/to/swiftc`.
#   - python3 with Pillow (tools/gen_font.py rasterizes the UI font from the
#     host's Helvetica at build time)
#---------------------------------------------------------------------------------
.SUFFIXES:

ifeq ($(strip $(DEVKITPRO)),)
$(error "Please set DEVKITPRO in your environment. export DEVKITPRO=<path to>devkitpro")
endif
ifeq ($(strip $(DEVKITARM)),)
$(error "Please set DEVKITARM in your environment. export DEVKITARM=$$DEVKITPRO/devkitARM")
endif

SWIFTC		?=	swiftc

# Dependency source checkouts (Embedded modules built from source; override
# for a different layout). CoreModel needs the embedded-no-concurrency
# support (PureSwift/CoreModel PR #29).
FOUNDATION_EMBEDDED_DIR	?=	$(HOME)/Developer/swift-embedded-foundation
COREMODEL_DIR		?=	$(HOME)/Developer/CoreModel
COREFUELING_DIR		:=	../Sources/CoreFueling

TARGET		:=	Fueling
NDS_TITLE	:=	Fueling
NDS_SUBTITLE	:=	Fueling locations
BUILD		:=	build
COMMON		:=	common/

LIBNDS		:=	$(DEVKITPRO)/libnds
CALICO		:=	$(DEVKITPRO)/calico

PREFIX		:=	$(DEVKITARM)/bin/arm-none-eabi-
CC		:=	$(PREFIX)gcc
LD		:=	$(PREFIX)gcc

#---------------------------------------------------------------------------------
# code generation -- ARM946E-S / armv5te, soft float, no FPU.
#---------------------------------------------------------------------------------
ARCH		:=	-march=armv5te -mtune=arm946e-s -mthumb

NDSDEFS		:=	-DARM9 -D__NDS__ -I$(COMMON) \
			-I$(LIBNDS)/include -I$(CALICO)/include

CFLAGS		:=	-g -Wall -O2 -ffunction-sections -fdata-sections $(ARCH) \
			$(NDSDEFS)

LDFLAGS		:=	-specs=$(CALICO)/share/ds9.specs -g $(ARCH) \
			-Wl,-Map,$(TARGET).map -Wl,--gc-sections \
			-L$(LIBNDS)/lib -L$(CALICO)/lib

# dswifi must precede libnds.
LIBS		:=	-ldswifi9 -lnds9 -lcalico_ds9 -lm

#---------------------------------------------------------------------------------
# Embedded Swift flags, targeting armv5te-none-none-eabi.
#---------------------------------------------------------------------------------
SWIFTFLAGS	:=	-target armv5te-none-none-eabi \
			-enable-experimental-feature Embedded \
			-wmo -Osize \
			-module-name Fueling \
			-Xcc -DARM9 -Xcc -D__NDS__ \
			-Xcc -march=armv5te -Xcc -mfloat-abi=soft \
			-Xcc -isystem -Xcc $(DEVKITARM)/arm-none-eabi/include \
			-Xcc -I$(COMMON) \
			-Xcc -I$(LIBNDS)/include \
			-Xcc -I$(CALICO)/include \
			-Xcc -fmodule-map-file=$(COMMON)module.modulemap

PORT_SWIFT	:=	$(wildcard source/*.swift)
GEN_SWIFT	:=	$(BUILD)/FontAssets.swift $(BUILD)/ServerConfig.swift

FOUNDATION_EMBEDDED_SRC	:=	$(wildcard $(FOUNDATION_EMBEDDED_DIR)/Sources/FoundationEmbedded/*.swift)
COREMODEL_SRC	:=	$(shell find $(COREMODEL_DIR)/Sources/CoreModel -name '*.swift')
COREFUELING_SRC	:=	$(wildcard $(COREFUELING_DIR)/*.swift)

# Swift string operations (search predicates, sorting) need the Embedded
# stdlib's Unicode data tables at link time.
TOOLCHAIN_LIB	:=	$(dir $(shell which $(SWIFTC)))../lib/swift/embedded/armv5te-none-none-eabi
LDFLAGS		+=	-L$(TOOLCHAIN_LIB)
LIBS		+=	-lswiftUnicodeDataTables

OFILES		:=	$(BUILD)/fueling.swift.o $(BUILD)/CoreFueling.o $(BUILD)/CoreModel.o \
			$(BUILD)/FoundationEmbedded.o $(BUILD)/shim.o

ARM7_ELF	:=	$(CALICO)/bin/ds7_maine.elf

#---------------------------------------------------------------------------------
.PHONY: all clean

all: $(TARGET).nds

$(BUILD):
	@mkdir -p $@

# Font conversion: the host's Helvetica at 13 px -> antialiased
# 8-bit-coverage glyph table (same face and size ClassicUI resolves).
$(BUILD)/FontAssets.swift: tools/gen_font.py | $(BUILD)
	@echo generating font assets
	python3 tools/gen_font.py $(BUILD)

# Injected server URL (FUELING_SERVER_URL, default http://10.0.2.2:8080).
# Re-evaluated every build; the file is only rewritten when the URL changes.
$(BUILD)/ServerConfig.swift: tools/gen_server.py FORCE | $(BUILD)
	@python3 tools/gen_server.py $(BUILD)

FORCE:

# Model-layer modules, compiled in dependency order (each emits its
# .swiftmodule into $(BUILD) for the next stage's -I $(BUILD)).
$(BUILD)/FoundationEmbedded.o: $(FOUNDATION_EMBEDDED_SRC) | $(BUILD)
	@echo compiling FoundationEmbedded
	$(SWIFTC) $(SWIFTFLAGS) -module-name FoundationEmbedded -parse-as-library \
		-emit-module -emit-module-path $(BUILD)/FoundationEmbedded.swiftmodule \
		-c $(FOUNDATION_EMBEDDED_SRC) -o $@

$(BUILD)/CoreModel.o: $(COREMODEL_SRC) $(BUILD)/FoundationEmbedded.o | $(BUILD)
	@echo compiling CoreModel
	$(SWIFTC) $(SWIFTFLAGS) -module-name CoreModel -parse-as-library -I $(BUILD) \
		-emit-module -emit-module-path $(BUILD)/CoreModel.swiftmodule \
		-c $(COREMODEL_SRC) -o $@

$(BUILD)/CoreFueling.o: $(COREFUELING_SRC) $(BUILD)/CoreModel.o | $(BUILD)
	@echo compiling CoreFueling
	$(SWIFTC) $(SWIFTFLAGS) -module-name CoreFueling -parse-as-library -I $(BUILD) \
		-emit-module -emit-module-path $(BUILD)/CoreFueling.swiftmodule \
		-c $(COREFUELING_SRC) -o $@

# All port Swift (+ generated font) -> one object, whole-module.
$(BUILD)/fueling.swift.o: $(PORT_SWIFT) $(GEN_SWIFT) $(BUILD)/CoreFueling.o \
		$(COMMON)module.modulemap $(COMMON)nds_umbrella.h $(COMMON)shim.h | $(BUILD)
	@echo compiling Swift
	$(SWIFTC) $(SWIFTFLAGS) -I $(BUILD) -c $(PORT_SWIFT) $(GEN_SWIFT) -o $@

$(BUILD)/shim.o: $(COMMON)shim.c $(COMMON)shim.h | $(BUILD)
	@echo $(notdir $<)
	$(CC) $(CFLAGS) -c $< -o $@

$(TARGET).elf: $(OFILES)
	@echo linking $(notdir $@)
	$(LD) $(LDFLAGS) $(OFILES) $(LIBS) -o $@

$(TARGET).nds: $(TARGET).elf
	@echo packaging $(notdir $@)
	ndstool -c $@ -9 $(TARGET).elf -7 $(ARM7_ELF) \
		-b $(CALICO)/share/nds-icon.bmp "$(NDS_TITLE);$(NDS_SUBTITLE);swift-nds"

clean:
	@echo clean ...
	@rm -fr $(BUILD) $(TARGET).elf $(TARGET).nds $(TARGET).map
