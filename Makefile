CA65_BINARY=ca65
CA65_FLAGS=--cpu 65c02 -t none
LD65_BINARY=ld65
LD65_FLAGS=
AR65_BINARY=ar65
AR65_FLAGS= r
MKDIR_BINARY=mkdir
MKDIR_FLAGS=-v -p

FIRMWARE= firmware.cfg

BUILD= build

# COMMON STUFF
COMMON_ROOT= common
COMMON_SOURCES= $(COMMON_ROOT)/source
COMMON_INCLUDES= $(COMMON_ROOT)/include
COMMON_BUILD= $(BUILD)/common
COMMON_SOURCE_FILES= zeropage.s \
			acia.s \
			kbd.s \
			console.s \
			utils.s \
			via.s
COMMON_OBJECTS=$(COMMON_SOURCE_FILES:%.s=$(COMMON_BUILD)/%.o)
COMMON_LIB=$(COMMON_BUILD)/common.lib

# ROM STUFF
ROM_ROOT=rom
ROM_BUILD=$(BUILD)/rom
ROM_SOURCES=$(ROM_ROOT)
ROM_SOURCE_FILES=be6502_rom.s
ROM_OBJECTS=$(ROM_SOURCE_FILES:%.s=$(ROM_BUILD)/%.o)
ROM_BINARIES=$(ROM_SOURCE_FILES:%.s=$(ROM_BUILD)/%.bin)

# LOAD STUFF
LOAD_ROOT=load
LOAD_BUILD=$(BUILD)/load

LOAD_COMMON_SOURCE_FILES=syscalls.s \
				loadlib.s
LOAD_COMMON_OBJECTS=$(LOAD_COMMON_SOURCE_FILES:%.s=$(LOAD_BUILD)/%.load.o)

LOAD_COMMON_LIB=$(LOAD_BUILD)/load.lib

LOAD_SOURCES=$(LOAD_ROOT)
LOAD_SOURCE_FILES=
LOAD_OBJECTS=$(LOAD_SOURCE_FILES:%.s=$(LOAD_BUILD)/%.o)
LOAD_RAW=$(LOAD_SOURCE_FILES:%.s=$(LOAD_BUILD)/%.raw)
LOAD_BINARIES=$(LOAD_SOURCE_FILES:%.s=$(LOAD_BUILD)/%.bin)

SYSTEM_MEMORY_MAP_OBJECT=$(COMMON_BUILD)/zeropage.o

# Don't edit beyond this line.

phony: all
clean:
	rm -frv $(BUILD)/*

all: $(COMMON_LIB) $(ROM_BINARIES) $(LOAD_BINARIES)
	@echo "Building everything."

# all the fancy makefile stuff here.
# Build the common libraries
$(COMMON_BUILD)/%.o: $(COMMON_SOURCES)/%.s
	@$(MKDIR_BINARY) $(MKDIR_FLAGS) $(COMMON_BUILD)
	$(CA65_BINARY) $(CA65_FLAGS) -I $(COMMON_INCLUDES) -l $(@:.o=.lst) -o $(@:.s=.o) $^

# pack up the common library
$(COMMON_BUILD)/common.lib: $(COMMON_OBJECTS)
	$(AR65_BINARY) $(AR65_FLAGS) $(COMMON_LIB) $^

# Build the roms
$(ROM_BUILD)/%.o: $(ROM_SOURCES)/%.s
	@$(MKDIR_BINARY) $(MKDIR_FLAGS) $(ROM_BUILD)
	$(CA65_BINARY) $(CA65_FLAGS) -I $(COMMON_INCLUDES) -l $(@:.o=.lst)  -o $(@:.s=.o) $^

# Link the roms
$(ROM_BUILD)/%.bin: $(SYSTEM_MEMORY_MAP_OBJECT) $(ROM_OBJECTS) $(COMMON_LIB)
	$(LD65_BINARY) $(LD65_FLAGS) -C $(FIRMWARE) -m $(@:.bin=.map)  -o $@ $(@:.bin=.o) $(COMMON_LIB)

# Build the common load library
$(LOAD_BUILD)/%.load.o: $(COMMON_SOURCES)/%.s
	@$(MKDIR_BINARY) $(MKDIR_FLAGS) $(LOAD_BUILD)
	$(CA65_BINARY) $(CA65_FLAGS) -I $(COMMON_INCLUDES) -l $(@:.o=.lst) -o $(@:.s=.load.o) $^

# pack up the common load library
$(LOAD_BUILD)/load.lib: $(LOAD_COMMON_OBJECTS)
	$(AR65_BINARY) $(AR65_FLAGS) $(LOAD_COMMON_LIB) $^

# Build the loadables
$(LOAD_BUILD)/%.o: $(LOAD_SOURCES)/%.s
	@$(MKDIR_BINARY) $(MKDIR_FLAGS) $(LOAD_BUILD)
	$(CA65_BINARY) $(CA65_FLAGS) -I $(COMMON_INCLUDES) -l $(@:.o=.lst)  -o $(@:.s=.o) $^

# Link the loadables
$(LOAD_BUILD)/%.raw: $(SYSTEM_MEMORY_MAP_OBJECT) $(LOAD_OBJECTS) $(LOAD_COMMON_LIB)
	$(LD65_BINARY) $(LD65_FLAGS) -C firmware.load.cfg -m $(@:.raw=.map)  -o $@ $(@:.raw=.o) $(SYSTEM_MEMORY_MAP_OBJECT) $(LOAD_COMMON_LIB)

# prune the loadables
$(LOAD_BUILD)/%.bin: $(LOAD_BUILD)/%.raw
	python3 loadtrim.py $^ $@
