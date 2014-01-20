TARGET = blink

#### Setup ####
#CMSIS         = /YOUR/PATH/TO/CMSIS
CMSIS = ../CMSIS/
SRC           = $(wildcard src/*.c)
TOOLCHAIN     = arm-none-eabi
UC            = XMC4500
UC_ID         = 4503
CPU           = cortex-m4
FPU           = fpv4-sp-d16
FABI          = softfp
ifeq ($(FABI),softfp)
	MATHLIB = arm_cortexM4l_math
else
	MATHLIB = arm_cortexM4lf_math
endif
LIBS          = -l$(MATHLIB)
GDB_ARGS      = -ex "target remote :2331" -ex "monitor reset" -ex "load" -ex "set *0xe000ed08 = 0x10000000" -ex "monitor go"
#GDB_ARGS      = -ex "target remote :2331" -ex "monitor reset" -ex "load" -ex "monitor reset" -ex "monitor go"
TGDB_ARGS      = -ex "set mem inaccessible-by-default off" -ex "target remote :2331" \
	-ex "monitor flash device = XMC4500" \
	-ex "monitor flash download = 1" \
	-ex "monitor flash breakpoints = 1" \
	-ex "monitor speed auto" \
	-ex "monitor endian little" \
	-ex "monitor reset" \
	-ex "load" \
	-ex "break main" -ex "continue"
	#ex "monitor reg r13 = (0x00000000)" -ex "monitor reg pc = (0x00000004)" -ex "monitor reset" -ex "continue"

JLINKARGS = -Device XMC4500-1024 -if SWD

#LINKER_FILE = ./src/xmc4500.ld
LINKER_FILE = $(CMSIS)/Device/Infineon/$(UC)_series/Source/GCC/$(UC).ld

CC   = $(TOOLCHAIN)-gcc
CP   = $(TOOLCHAIN)-objcopy
OD   = $(TOOLCHAIN)-objdump
GDB  = $(TOOLCHAIN)-gdb
SIZE = $(TOOLCHAIN)-size

CFLAGS = -mthumb -mcpu=$(CPU) -mfpu=$(FPU) -mfloat-abi=$(FABI)
CFLAGS+= -O0 -ffunction-sections -fdata-sections
CFLAGS+= -MD -std=c99 -Wall -fms-extensions
CFLAGS+= -DUC_ID=$(UC_ID) -DARM_MATH_CM4
CFLAGS+= -g3 -fmessage-length=0 -I$(CMSIS)/Include
CFLAGS+= -I$(CMSIS)/Device/Infineon/Include
CFLAGS+= -I$(CMSIS)/Device/Infineon/$(UC)_series/Include
LFLAGS = -nostartfiles -L$(CMSIS)/Device/Infineon/Lib -L$(CMSIS)/Lib/GCC -Wl,--gc-sections
CPFLAGS = -Obinary
ODFLAGS = -S

STARTUP = $(CMSIS)/Device/Infineon/$(UC)_series/Source/GCC/startup_$(UC).s
CMSIS_SRC = $(CMSIS)/Device/Infineon/$(UC)_series/Source/System_$(UC).c
# linker script includes xmclibcstubs.a, soure:$(CMSIS)/Device/Infineon/Source/GCC/System_LibcStubs.c

OBJS  = $(SRC:.c=.o)
OBJS += src/startup_$(UC).o
OBJS += src/System_$(UC).o

#### Rules ####
all: $(OBJS) $(TARGET).axf $(TARGET)

src/startup_$(UC).o: $(STARTUP)
	$(CC) -x assembler-with-cpp -c $(CFLAGS) -DDAVE_CE -Wa,-adhlns="$@.lst" -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@:%.o=%.d) $@" -gdwarf-2 -o "$@" $<

src/System_$(UC).o: $(CMSIS_SRC)
	$(CC) -c $(CFLAGS) $< -o $@

%.o: %.c
	$(CC) -c $(CFLAGS) $< -o $@

$(TARGET).axf: $(OBJS)
	mkdir -p bin/
	$(CC) -T $(LINKER_FILE) $(LFLAGS) $(CFLAGS) -o bin/$(TARGET).axf $(OBJS) $(LIBS)

$(TARGET): $(TARGET).axf
	$(CP) $(CPFLAGS) bin/$(TARGET).axf bin/$(TARGET).bin
	$(OD) $(ODFLAGS) bin/$(TARGET).axf > bin/$(TARGET).lst
	$(SIZE) bin/$(TARGET).axf

install: $(TARGET)
	$(GDB) bin/$(TARGET).axf $(GDB_ARGS)

clean:
	rm -f src/*.o src/*.d src/*.lst bin/*
