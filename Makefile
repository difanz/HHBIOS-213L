# HHBIOS-213L — rebuild DOS .COM modules with JWasm (MASM-compatible)
# Sources are GB2312/GBK: do not convert them to UTF-8.
#
# Requires: jwasm in PATH  (https://github.com/Baron-von-Riedesel/JWasm)
#   jwasm -Zm  = MASM 5.x compatibility (needed by several modules)
#   jwasm -bin = emit raw binary (.COM) for ORG 100H sources

JWASM ?= jwasm
JWFLAGS ?= -q -Zm -bin
BUILD := build

ASMS := $(wildcard *.ASM)
# Modules known to need extra work (missing INC / syntax) — still listed so `make all` reports them
COMS := $(patsubst %.ASM,$(BUILD)/%.COM,$(ASMS))

.PHONY: all clean pilot

all: $(COMS)

pilot: $(BUILD)/CMODE.COM $(BUILD)/KEY.COM $(BUILD)/CM.COM
	@cmp -s CMODE.COM $(BUILD)/CMODE.COM && echo "CMODE: identical to original"
	@cmp -s KEY.COM $(BUILD)/KEY.COM && echo "KEY: identical to original"
	@cmp -s CM.COM $(BUILD)/CM.COM && echo "CM: identical to original"

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/%.COM: %.ASM | $(BUILD)
	$(JWASM) $(JWFLAGS) -Fo=$@ $<

clean:
	rm -rf $(BUILD)
