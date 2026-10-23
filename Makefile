# GR-DOS Linux build (decisions 11 and 19).
#
#   make          build the boot sector, IO.SYS, MSDOS.SYS and COMMAND.COM
#   make check    compare them, and the generated message files, with the
#                 M1 reference build (docs/m1/reference-build.sha256)
#   make dist     collect the binaries, checksums and build details in
#                 build/linux/dist (the CI artifacts)
#   make clean    remove build/linux (fetched tools in build/tools are kept)
#
# Needs Perl 5.42 as `perl` on PATH, a C compiler and make (to build JWasm),
# git, curl and xz. JWasm and Open Watcom are fetched into build/tools.
#
# The source tree is prepared in build/linux/SRC (CRLF text, case aliases)
# and built in place, like the original DOS build: each object is next to
# its source and every output is at the path the DOS makefiles give it.

BUILD := build/linux
SRC   := $(BUILD)/SRC
MSG   := $(SRC)/MESSAGES/USA-MS.MSG

JWFLAGS := -q -Zj -Zm -Zg -Cx -I. -I$(CURDIR)/$(SRC)/INC -I$(CURDIR)/$(SRC)/DOS

BOOT_OBJS    := $(SRC)/BOOT/MSBOOT.OBJ
MSLOAD_OBJS  := $(SRC)/BIOS/MSLOAD.OBJ
MSBIO_OBJS   := $(addprefix $(SRC)/,$(shell scripts/lnk-objects v4.0/src BIOS/MSBIO.LNK))
MSDOS_OBJS   := $(addprefix $(SRC)/,$(shell scripts/lnk-objects v4.0/src DOS/MSDOS.LNK))
COMMAND_OBJS := $(addprefix $(SRC)/,$(shell scripts/lnk-objects v4.0/src CMD/COMMAND/COMMAND.LNK))

OUTPUTS := BOOT/MSBOOT.BIN INC/BOOT.INC BIOS/IO.SYS DOS/MSDOS.SYS CMD/COMMAND/COMMAND.COM

# Generated message files compared by `make check`.
MESSAGES := BOOT/BOOT.CL1 \
	$(foreach c,1 2 3 4 5,BIOS/MSBIO.CL$(c)) \
	DOS/MSDOS.CL1 DOS/MSDOS.CL3 \
	$(foreach c,1 2 3 4 A B C D E F,CMD/COMMAND/COMMAND.CL$(c)) CMD/COMMAND/COMMAND.CTL

REFERENCE := $(MESSAGES) BOOT/MSBOOT.BIN BIOS/MSLOAD.COM BIOS/IO.SYS DOS/MSDOS.SYS \
	CMD/COMMAND/COMMAND.COM

all: $(addprefix $(SRC)/,$(OUTPUTS))

check: all
	printf '%s\n' $(REFERENCE) \
	  | awk 'NR == FNR { want[$$0]; next } $$2 in want' - docs/m1/reference-build.sha256 \
	  > $(BUILD)/reference.sha256
	test $$(wc -l < $(BUILD)/reference.sha256) -eq $(words $(REFERENCE))
	cd $(SRC) && sha256sum -c ../reference.sha256

DIST := $(BUILD)/dist

dist: all
	rm -rf $(DIST)
	mkdir -p $(DIST)
	cp $(addprefix $(SRC)/,BOOT/MSBOOT.BIN BIOS/IO.SYS DOS/MSDOS.SYS CMD/COMMAND/COMMAND.COM) $(DIST)/
	cd $(DIST) && sha256sum * > SHA256SUMS
	. ./$(BUILD)/tools.env && { \
	  echo "GR-DOS $$(cat VERSION)"; \
	  echo "commit $$(git describe --always --dirty --abbrev=40)"; \
	  perl -e 'print "perl $$^V\n"'; \
	  echo "jwasm $$(basename $$(dirname $$(dirname $$(dirname $$JWASM))))"; \
	  echo "watcom $$(basename $$WATCOM)"; \
	} > $(DIST)/BUILDINFO

clean:
	rm -rf $(BUILD)

.PHONY: all check dist clean
.DELETE_ON_ERROR:

# Paths of the fetched tools, as shell assignments.
$(BUILD)/tools.env: scripts/fetch-jwasm scripts/fetch-watcom $(wildcard patches/jwasm/*.patch)
	mkdir -p $(BUILD)
	jwasm=$$(scripts/fetch-jwasm) && watcom=$$(scripts/fetch-watcom) \
	  && printf 'JWASM=%s\nWATCOM=%s\nexport WATCOM\n' "$$jwasm" "$$watcom" > $@

$(BUILD)/tree.stamp: $(shell find v4.0/src -type f) scripts/prepare-dos-tree
	rm -rf $(SRC)
	mkdir -p $(BUILD)
	scripts/prepare-dos-tree v4.0/src $(SRC) > /dev/null
	touch $@

# Message files (BUILDMSG/NOSRVBLD); the case aliases cover their references too.
$(BUILD)/messages.stamp: $(BUILD)/tree.stamp scripts/buildmsg scripts/case-alias
	scripts/buildmsg --nosrvbld $(MSG) $(SRC)/BOOT/BOOT.SKL
	scripts/buildmsg --nosrvbld $(MSG) $(SRC)/BIOS/MSBIO.SKL
	scripts/buildmsg --nosrvbld $(MSG) $(SRC)/DOS/MSDOS.SKL
	scripts/buildmsg $(MSG) $(SRC)/CMD/COMMAND/COMMAND.SKL
	scripts/case-alias $(SRC) > /dev/null
	touch $@

$(SRC)/%.OBJ: $(BUILD)/messages.stamp $(BUILD)/tools.env
	. ./$(BUILD)/tools.env && cd $(@D) && "$$JWASM" $(JWFLAGS) -Fo$(@F) $(notdir $*).ASM

$(SRC)/BOOT/MSBOOT.EXE:         $(BOOT_OBJS)
$(SRC)/BIOS/MSLOAD.EXE:         $(MSLOAD_OBJS)
$(SRC)/BIOS/MSBIO.EXE:          $(MSBIO_OBJS)
$(SRC)/DOS/MSDOS.EXE:           $(MSDOS_OBJS)
$(SRC)/CMD/COMMAND/COMMAND.EXE: $(COMMAND_OBJS)

EXES := $(addprefix $(SRC)/,BOOT/MSBOOT.EXE BIOS/MSLOAD.EXE BIOS/MSBIO.EXE DOS/MSDOS.EXE \
	CMD/COMMAND/COMMAND.EXE)

$(EXES): %.EXE: $(BUILD)/tools.env scripts/mslink scripts/mslink-layout
	. ./$(BUILD)/tools.env && scripts/mslink $@ $(filter %.OBJ,$^)

# EXE2BIN; the image is padded to the size Microsoft LINK gives it.
size = $$(scripts/mslink-layout --size $(filter %.OBJ,$^))

$(addprefix $(SRC)/,BOOT/MSBOOT.BIN BIOS/MSLOAD.COM BIOS/MSBIO.BIN DOS/MSDOS.SYS \
	CMD/COMMAND/COMMAND.COM): scripts/exe2bin scripts/mslink-layout

$(SRC)/BOOT/MSBOOT.BIN: $(SRC)/BOOT/MSBOOT.EXE $(BOOT_OBJS)
	scripts/exe2bin --size $(size) $< $@

$(SRC)/BIOS/MSLOAD.COM: $(SRC)/BIOS/MSLOAD.EXE $(MSLOAD_OBJS)
	scripts/exe2bin --size $(size) $< $@

# The base segment typed at EXE2BIN's prompt comes from BIOS/LOCSCR.
$(SRC)/BIOS/MSBIO.BIN: $(SRC)/BIOS/MSBIO.EXE $(MSBIO_OBJS)
	scripts/exe2bin --base $$(tr -dc 0-9A-Fa-f < $(SRC)/BIOS/LOCSCR) --size $(size) $< $@

$(SRC)/BIOS/IO.SYS: $(SRC)/BIOS/MSLOAD.COM $(SRC)/BIOS/MSBIO.BIN
	cat $^ > $@

$(SRC)/DOS/MSDOS.SYS: $(SRC)/DOS/MSDOS.EXE $(MSDOS_OBJS)
	scripts/exe2bin --size $(size) $< $@

$(SRC)/CMD/COMMAND/COMMAND.COM: $(SRC)/CMD/COMMAND/COMMAND.EXE $(COMMAND_OBJS)
	scripts/exe2bin --size $(size) $< $@

# DBOF: the boot sector for FORMAT and SYS.
$(SRC)/INC/BOOT.INC: $(SRC)/BOOT/MSBOOT.BIN scripts/dbof
	scripts/dbof $< $@ 7c00 200
