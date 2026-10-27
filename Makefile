# GR-DOS Linux build (decisions 11 and 19).
#
#   make          build the boot sector, IO.SYS, MSDOS.SYS, COMMAND.COM and
#                 the utilities, and the bootable floppy images
#                 build/linux/gr-dos-{1440,1200,720,360}k.img (3.5" 1.44 MB,
#                 5.25" 1.2 MB, 3.5" 720 KB, 5.25" 360 KB), which all hold the
#                 same files (build/linux/manifest.txt)
#   make check    build without the branding patches, in build/linux/reference,
#                 and compare the binaries and generated message files with
#                 the M1 reference build (docs/m1/reference-build.sha256)
#   make test     boot a copy of each image with a test AUTOEXEC.BAT and
#                 program in QEMU and check its serial output (tests/smoke),
#                 and test the utilities (tests/utils); make test-1440 (or
#                 test-1200, test-720, test-360) boots just one image, and
#                 make test-utils runs just the utility tests
#   make dist     write the release assets to build/linux/release: the four
#                 images, a ZIP of the binaries, README, build details and
#                 logs, and SHA256SUMS; the ZIP's tree is build/linux/dist
#   make clean    remove build/linux (fetched tools in build/tools are kept)
#
# Needs Perl 5.42 as `perl` on PATH, a C compiler and make (to build JWasm),
# git, curl and xz; mtools for the image and qemu-system-i386 for the test.
# JWasm, Open Watcom and TICO.EXE (tico16) are fetched into build/tools,
# and the C runtime for ATTRIB and MEM, the pinned libc16 release, into
# build/libc16 (scripts/fetch-libc16). make LIBC16_ROOT=../libc16 builds
# against a libc16 checkout built with its own make instead.
#
# The source tree is v4.0/src with the patches in PATCHES applied (the
# GR-DOS branding, decision 7). It is prepared in build/linux/SRC (CRLF
# text, case aliases) and built in place, like the original DOS build: each
# object is next to its source and every output is at the path the DOS
# makefiles give it.

BUILD := build/linux
SRC   := $(BUILD)/SRC
MSG   := $(SRC)/MESSAGES/USA-MS.MSG
TOOLS := $(BUILD)/tools.env

# Patches to v4.0/src, applied in order with patch -p1 (no fuzz).
PATCHES := $(sort $(wildcard patches/branding/*.patch))

JWFLAGS := -q -Zj -Zm -Zg -Cx -I. -I$(CURDIR)/$(SRC)/INC -I$(CURDIR)/$(SRC)/DOS

# ATTRIB and MEM are C, compiled with Open Watcom C for Microsoft C 5.1's
# small model and packed structures, with libc16 as their C runtime (its
# docs/ABI.md): its headers only, as -x ignores INCLUDE, -zl leaves out the
# references to Open Watcom's libraries, and the default register
# convention, with the assembly modules' interfaces declared __cdecl in the
# sources.
LIBC16_ROOT ?= build/libc16
# A release tree, or a checkout, whose make stages the same layout in
# build/stage.
LIBC16_DIR  := $(if $(wildcard $(LIBC16_ROOT)/build/stage/VERSION),$(LIBC16_ROOT)/build/stage,$(LIBC16_ROOT))
LIBC16      := $(LIBC16_DIR)/lib/LIBC16.LIB
WCFLAGS := -q -w0 -zld -zl -x -ms -0 -os -zp1 -s -j -ei -bt=dos \
	-I. -I$(CURDIR)/$(SRC)/H -I$(abspath $(LIBC16_DIR))/include

BOOT_OBJS    := $(SRC)/BOOT/MSBOOT.OBJ
MSLOAD_OBJS  := $(SRC)/BIOS/MSLOAD.OBJ
MSBIO_OBJS   := $(addprefix $(SRC)/,$(shell scripts/lnk-objects v4.0/src BIOS/MSBIO.LNK))
MSDOS_OBJS   := $(addprefix $(SRC)/,$(shell scripts/lnk-objects v4.0/src DOS/MSDOS.LNK))
COMMAND_OBJS := $(addprefix $(SRC)/,$(shell scripts/lnk-objects v4.0/src CMD/COMMAND/COMMAND.LNK))

# The utilities on the system disk (issue #4), in the order they are copied
# to it; each CMD/X directory but MEM's has its X.LNK.
UTILITIES := CMD/FORMAT/FORMAT.COM CMD/SYS/SYS.COM CMD/CHKDSK/CHKDSK.COM \
	CMD/DISKCOPY/DISKCOPY.COM CMD/ATTRIB/ATTRIB.EXE CMD/MORE/MORE.COM CMD/FIND/FIND.EXE \
	CMD/DEBUG/DEBUG.COM CMD/MEM/MEM.EXE CMD/MODE/MODE.COM
UTILITY_DIRS := $(patsubst CMD/%/,%,$(dir $(UTILITIES)))
$(foreach u,$(filter-out MEM,$(UTILITY_DIRS)),\
  $(eval $(u)_OBJS := $(addprefix $(SRC)/,$(shell scripts/lnk-objects v4.0/src CMD/$(u)/$(u).LNK))))
# MEM's makefile links mem+_msgret+_parse.
MEM_OBJS := $(addprefix $(SRC)/CMD/MEM/,MEM.OBJ _MSGRET.OBJ _PARSE.OBJ)

OUTPUTS := BOOT/MSBOOT.BIN INC/BOOT.INC BIOS/IO.SYS DOS/MSDOS.SYS CMD/COMMAND/COMMAND.COM \
	$(UTILITIES)

# The message files of utility $(1): X.CL$(c) for each c of $(2), and X.CTL.
utility_messages = $(foreach c,$(2),CMD/$(1)/$(1).CL$(c)) CMD/$(1)/$(1).CTL

# Generated message files compared by `make check`.
MESSAGES := BOOT/BOOT.CL1 \
	$(foreach c,1 2 3 4 5,BIOS/MSBIO.CL$(c)) \
	DOS/MSDOS.CL1 DOS/MSDOS.CL3 \
	$(foreach c,1 2 3 4 A B C D E F,CMD/COMMAND/COMMAND.CL$(c)) CMD/COMMAND/COMMAND.CTL \
	$(call utility_messages,ATTRIB,1 2 A B) $(call utility_messages,CHKDSK,1 2 A B C D) \
	$(call utility_messages,DEBUG,1 2 A B C D) $(call utility_messages,DISKCOPY,1 2 A) \
	$(call utility_messages,FIND,1 2 A) $(call utility_messages,FORMAT,1 2 A B C) \
	CMD/FORMAT/BOOT.CL1 $(call utility_messages,MEM,1 2 A B) \
	$(call utility_messages,MODE,1 2 A B) $(call utility_messages,MORE,1 2 A) \
	$(call utility_messages,SYS,1 2 A B C D)

# ATTRIB.EXE and MEM.EXE are built with Open Watcom C, not Microsoft C 5.1,
# so they are not compared. CONVERT makes CHKDSK.EXE into CHKDSK.COM.
REFERENCE := $(MESSAGES) BOOT/MSBOOT.BIN BIOS/MSLOAD.COM BIOS/IO.SYS DOS/MSDOS.SYS \
	CMD/COMMAND/COMMAND.COM $(filter-out %/ATTRIB.EXE %/MEM.EXE,$(UTILITIES)) \
	CMD/CHKDSK/CHKDSK.EXE

# Floppy formats, by size in KB (scripts/mkimage --format); 1440 is the
# default.
FORMATS := 1440 1200 720 360
IMAGES  := $(foreach f,$(FORMATS),$(BUILD)/gr-dos-$(f)k.img)
TESTS   := $(BUILD)/tests

# TICO.EXE, from the pinned tico16 release, and its license.
TICO := $(BUILD)/tico/TICO.EXE

# The programs after IO.SYS, MSDOS.SYS and COMMAND.COM on every image, and
# all the files. FIND.EXE is linked again without EXEPACK for the images:
# LINK's EXEPACK loader fails ("Packed file is corrupt") when DOS loads the
# program in the first 64 KB of memory, as GR-DOS does.
PROGRAMS := $(patsubst $(SRC)/CMD/FIND/FIND.EXE,$(BUILD)/image/FIND.EXE,\
	$(addprefix $(SRC)/,$(UTILITIES))) $(TICO)
FILES    := $(PROGRAMS) $(BUILD)/image/AUTOEXEC.BAT

all: $(addprefix $(SRC)/,$(OUTPUTS)) $(IMAGES) $(BUILD)/manifest.txt

# The reference build shares the fetched tools.
check: $(TOOLS)
	$(MAKE) BUILD=$(BUILD)/reference TOOLS=$(TOOLS) PATCHES= check-tree

# Used by check, in a tree built without PATCHES.
check-tree: $(addprefix $(SRC)/,$(OUTPUTS))
	printf '%s\n' $(REFERENCE) \
	  | awk 'NR == FNR { want[$$0]; next } $$2 in want' - docs/m1/reference-build.sha256 \
	  > $(BUILD)/reference.sha256
	test $$(wc -l < $(BUILD)/reference.sha256) -eq $(words $(REFERENCE))
	cd $(SRC) && sha256sum -c ../reference.sha256

TEST_FORMATS := $(addprefix test-,$(FORMATS))
TEST_SYS     := $(addprefix test-sys-,$(FORMATS))

test: $(TEST_FORMATS) test-utils $(TEST_SYS)

$(TEST_FORMATS): test-%: $(TESTS)/smoke-%k.img
	scripts/smoke-test --expect tests/smoke/expect-$*k $< tests/smoke/expect $(TESTS)/smoke-$*k

# The utility tests (tests/utils): the programs, then DISKCOPY and FORMAT /S
# to a blank 1.44 MB disk in drive B:, which is then booted; and FORMAT and
# SYS to a blank disk of each format, booted in turn. The B: disks are
# disposable images in $(TESTS).
#
# QEMU's drives are high density, and its BIOS has no INT 13h AH=18h, which
# FORMAT needs to format a 720 KB disk in a 1.44 MB drive ("Parameters not
# supported"). The 720 KB disk is formatted by mformat instead, and only SYS
# is tested on it. A 360 KB disk in a 1.2 MB drive needs /F:360.
SYS_FORMAT_1440 := FORMAT B: /V:GRSYS <FORMAT.IN
SYS_FORMAT_1200 := FORMAT B: /V:GRSYS <FORMAT.IN
SYS_FORMAT_720  := REM B: is formatted by mformat
SYS_FORMAT_360  := FORMAT B: /V:GRSYS /F:360 <FORMAT.IN

test-utils: $(TESTS)/utils.img
	rm -f $(TESTS)/utils-b.img
	truncate -s $$((1440 * 1024)) $(TESTS)/utils-b.img
	scripts/smoke-test --timeout 300 --drive-b $(TESTS)/utils-b.img $< tests/utils/expect $(TESTS)/utils
	scripts/smoke-test $(TESTS)/utils-b.img tests/utils/expect-boot $(TESTS)/utils-boot

$(TEST_SYS): test-sys-%: $(TESTS)/sys-%k.img
	rm -f $(TESTS)/sys-$*k-b.img
	truncate -s $$(($* * 1024)) $(TESTS)/sys-$*k-b.img
	$(if $(filter 720,$*),mformat -i $(TESTS)/sys-$*k-b.img -f $* -v GRSYS ::)
	scripts/smoke-test --timeout 300 --drive-b $(TESTS)/sys-$*k-b.img --expect tests/utils/expect-sys-$*k \
	  $< tests/utils/expect-sys $(TESTS)/sys-$*k
	scripts/smoke-test $(TESTS)/sys-$*k-b.img tests/utils/expect-boot $(TESTS)/sys-$*k-boot

# Release assets (decision 17): the images, a reproducible ZIP of everything
# else and SHA256SUMS of the images and the ZIP, in $(RELEASE). The ZIP's
# unpacked tree is kept in $(DIST).
VERSION := $(shell cat VERSION)
NAME    := gr-dos-$(VERSION)
DIST    := $(BUILD)/dist
RELEASE := $(BUILD)/release

# Logs for the ZIP's LOGS directory (CI gives make.log and test.log), and a
# file of further BUILDINFO lines (CI gives the runner details).
DIST_LOGS ?= $(wildcard build/make.log build/test.log)
DIST_INFO ?=

dist: all release/README.txt LICENSE v4.0/LICENSE scripts/mkzip $(BUILD)/libc16.stamp
	rm -rf $(DIST) $(RELEASE)
	mkdir -p $(DIST)/$(NAME)/BIN $(RELEASE)
	cp $(CORE) $(FILES) $(DIST)/$(NAME)/BIN/
	{ \
	  sed 's/@VERSION@/$(VERSION)/g' release/README.txt; \
	  printf '\n\nGR-DOS\n------\n\n'; cat LICENSE; \
	  printf '\n\nMS-DOS 4.00 source (v4.0/LICENSE)\n---------------------------------\n\n'; cat v4.0/LICENSE; echo; \
	  printf '\ntico16 (TICO.EXE)\n-----------------\n\n'; cat $(dir $(TICO))LICENSE; \
	  printf '\n\nlibc16 (in ATTRIB.EXE and MEM.EXE)\n----------------------------------\n\n'; \
	  cat $(LIBC16_DIR)/LICENSE; \
	} | sed 's/$$/\r/' > $(DIST)/$(NAME)/README.txt
	. ./$(TOOLS) && { \
	  echo "GR-DOS $(VERSION)"; \
	  echo "commit $$(git describe --always --dirty --abbrev=40)"; \
	  perl -e 'print "perl $$^V\n"'; \
	  echo "jwasm $$(basename $$(dirname $$(dirname $$(dirname $$JWASM))))"; \
	  echo "watcom $$(basename $$WATCOM)"; \
	  cat $(BUILD)/libc16.stamp; \
	  mformat --version | head -1; \
	  perl -MCompress::Raw::Zlib -e 'print "zlib ", Compress::Raw::Zlib::zlib_version(), "\n"'; \
	  $(if $(DIST_INFO),cat $(DIST_INFO);) \
	} > $(DIST)/$(NAME)/BUILDINFO
	$(if $(DIST_LOGS),mkdir -p $(DIST)/$(NAME)/LOGS && cp $(DIST_LOGS) $(DIST)/$(NAME)/LOGS/)
	cd $(DIST)/$(NAME) && find . -type f | sed 's|^\./||' | LC_ALL=C sort | xargs sha256sum > ../SHA256SUMS \
	  && mv ../SHA256SUMS SHA256SUMS
	scripts/mkzip $(RELEASE)/$(NAME).zip $(DIST)/$(NAME)
	$(foreach f,$(FORMATS),cp $(BUILD)/gr-dos-$(f)k.img $(RELEASE)/$(NAME)-$(f)k.img;)
	cd $(RELEASE) && sha256sum $(foreach f,$(FORMATS),$(NAME)-$(f)k.img) $(NAME).zip > SHA256SUMS
	ls -l $(RELEASE)

clean:
	rm -rf $(BUILD)

.PHONY: all check check-tree test $(TEST_FORMATS) test-utils $(TEST_SYS) dist clean
.DELETE_ON_ERROR:

# Paths of the fetched tools, as shell assignments.
$(TOOLS): scripts/fetch-jwasm scripts/fetch-watcom $(wildcard patches/jwasm/*.patch)
	mkdir -p $(@D)
	jwasm=$$(scripts/fetch-jwasm) && watcom=$$(scripts/fetch-watcom) \
	  && printf 'JWASM=%s\nWATCOM=%s\nexport WATCOM\n' "$$jwasm" "$$watcom" > $@

# The patches are applied to an LF copy of v4.0/src: GNU patch will not apply
# LF hunks to CRLF files.
$(BUILD)/tree.stamp: $(shell find v4.0/src -type f) $(PATCHES) scripts/prepare-dos-tree
	rm -rf $(SRC) $(BUILD)/upstream
	mkdir -p $(BUILD)
	cp -R v4.0/src $(BUILD)/upstream
	for p in $(PATCHES); do \
	  patch -s -p1 -F0 --no-backup-if-mismatch -d $(BUILD)/upstream < $$p || exit 1; \
	done
	scripts/prepare-dos-tree $(BUILD)/upstream $(SRC) > /dev/null
	rm -rf $(BUILD)/upstream
	touch $@

# Message files (BUILDMSG/NOSRVBLD); the case aliases cover their references too.
$(BUILD)/messages.stamp: $(BUILD)/tree.stamp scripts/buildmsg scripts/case-alias
	scripts/buildmsg --nosrvbld $(MSG) $(SRC)/BOOT/BOOT.SKL
	scripts/buildmsg --nosrvbld $(MSG) $(SRC)/BIOS/MSBIO.SKL
	scripts/buildmsg --nosrvbld $(MSG) $(SRC)/DOS/MSDOS.SKL
	scripts/buildmsg $(MSG) $(SRC)/CMD/COMMAND/COMMAND.SKL
	for u in $(UTILITY_DIRS); do scripts/buildmsg $(MSG) $(SRC)/CMD/$$u/$$u.SKL || exit 1; done
	cp $(SRC)/BOOT/BOOT.CL1 $(SRC)/CMD/FORMAT/
	scripts/case-alias $(SRC) > /dev/null
	touch $@

$(SRC)/%.OBJ: $(BUILD)/messages.stamp $(TOOLS)
	. ./$(TOOLS) && cd $(@D) && "$$JWASM" $(JWFLAGS) -Fo$(@F) $(notdir $*).ASM

# FORMAT and SYS include the boot sector.
$(SRC)/CMD/FORMAT/MSFOR.OBJ $(SRC)/CMD/SYS/SYS1.OBJ: $(SRC)/INC/BOOT.INC

C_OBJS := $(SRC)/CMD/ATTRIB/ATTRIB.OBJ $(SRC)/CMD/MEM/MEM.OBJ

$(C_OBJS): %.OBJ: $(BUILD)/messages.stamp $(TOOLS) $(BUILD)/libc16.stamp
	. ./$(TOOLS) && cd $(@D) && PATH=$$WATCOM/binl64:$$PATH \
	  wcc $(WCFLAGS) -fo=$(@F) $(notdir $*).C

$(SRC)/BOOT/MSBOOT.EXE:         $(BOOT_OBJS)
$(SRC)/BIOS/MSLOAD.EXE:         $(MSLOAD_OBJS)
$(SRC)/BIOS/MSBIO.EXE:          $(MSBIO_OBJS)
$(SRC)/DOS/MSDOS.EXE:           $(MSDOS_OBJS)
$(SRC)/CMD/COMMAND/COMMAND.EXE: $(COMMAND_OBJS)
$(foreach u,$(filter-out ATTRIB MEM,$(UTILITY_DIRS)),$(eval $(SRC)/CMD/$(u)/$(u).EXE: $($(u)_OBJS)))

EXES := $(addprefix $(SRC)/,BOOT/MSBOOT.EXE BIOS/MSLOAD.EXE BIOS/MSBIO.EXE DOS/MSDOS.EXE \
	CMD/COMMAND/COMMAND.EXE) \
	$(foreach u,$(filter-out ATTRIB MEM,$(UTILITY_DIRS)),$(SRC)/CMD/$(u)/$(u).EXE)

# The programs CONVERT makes into .COM files are linked as Microsoft LINK
# writes them, and FIND as LINK /EXEPACK writes it.
CONVERTED := FORMAT CHKDSK DEBUG
$(foreach u,$(CONVERTED),$(SRC)/CMD/$(u)/$(u).EXE): MSLINK := --exe
$(SRC)/CMD/FIND/FIND.EXE: MSLINK := --exepack

$(EXES): %.EXE: $(TOOLS) scripts/mslink scripts/mslink-layout scripts/msexe
	. ./$(TOOLS) && scripts/mslink $(MSLINK) $@ $(filter %.OBJ,$^)

# The pinned libc16 release (scripts/fetch-libc16). A LIBC16_ROOT given on
# the command line must already be built.
ifeq ($(LIBC16_ROOT),build/libc16)
$(LIBC16): scripts/fetch-libc16
	scripts/fetch-libc16 $(LIBC16_ROOT)
endif

# libc16 is built with the Open Watcom GR-DOS pins (its decision 1); the
# pins must agree.
$(BUILD)/libc16.stamp: $(LIBC16) scripts/fetch-watcom
	mkdir -p $(@D)
	test "$$(sed -n 's/^sha256=//p' scripts/fetch-watcom)" \
	  = "$$(sed -n 's/^sha256=//p' $(LIBC16_DIR)/tools/fetch-watcom)"
	echo "libc16 $$(cat $(LIBC16_DIR)/VERSION)" > $@

# ATTRIB has its own startup code, ATTRIBA, so it links no libc16 startup
# (libc16's docs/spec/startup.md, "Programs without the startup"); MEM's
# is libc16's.
$(SRC)/CMD/ATTRIB/ATTRIB.EXE: $(ATTRIB_OBJS)
$(SRC)/CMD/MEM/MEM.EXE:       $(MEM_OBJS)

# No default libraries: the map, X.MAP, must show only the objects and
# LIBC16.LIB (scripts/check-runtime).
$(SRC)/CMD/ATTRIB/ATTRIB.EXE $(SRC)/CMD/MEM/MEM.EXE: $(TOOLS) $(BUILD)/libc16.stamp scripts/check-runtime
	. ./$(TOOLS) && PATH=$$WATCOM/binl64:$$PATH && wlink option quiet format dos \
	  option nocaseexact option nodefaultlibs option map=$(@:.EXE=.MAP) \
	  name $@ $(foreach o,$(filter %.OBJ,$^),file $(o)) library $(LIBC16)
	scripts/check-runtime $(@:.EXE=.MAP) $(LIBC16) $(filter %.OBJ,$^)

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

EXE2BIN := SYS MORE DISKCOPY MODE
$(foreach u,$(EXE2BIN),$(eval $(SRC)/CMD/$(u)/$(u).COM: $($(u)_OBJS)))

$(foreach u,$(EXE2BIN),$(SRC)/CMD/$(u)/$(u).COM): %.COM: %.EXE scripts/exe2bin scripts/mslink-layout
	scripts/exe2bin --size $(size) $< $@

# CONVERT: a .COM program that loads the .EXE it holds.
$(foreach u,$(CONVERTED),$(SRC)/CMD/$(u)/$(u).COM): %.COM: %.EXE scripts/convert
	scripts/convert $< $@

# DBOF: the boot sector for FORMAT and SYS.
$(SRC)/INC/BOOT.INC: $(SRC)/BOOT/MSBOOT.BIN scripts/dbof
	scripts/dbof $< $@ 7c00 200

# The bootable floppy images (decisions 5 and 12).
CORE := $(addprefix $(SRC)/,BOOT/MSBOOT.BIN BIOS/IO.SYS DOS/MSDOS.SYS CMD/COMMAND/COMMAND.COM)

$(BUILD)/gr-dos-%k.img: $(CORE) $(FILES) scripts/mkimage scripts/check-image
	scripts/mkimage --format $* $@ $(SRC) $(FILES)

# Every image must hold the same files, with the same contents (issue #4):
# exactly IO.SYS, MSDOS.SYS, COMMAND.COM and FILES.
$(BUILD)/manifest.txt: $(IMAGES) scripts/image-manifest
	scripts/image-manifest $< > $@.tmp
	for i in $(IMAGES); do \
	  scripts/image-manifest $$i | cmp -s - $@.tmp || { echo "$$i: files differ from $<" >&2; exit 1; }; \
	done
	printf '%s\n' IO.SYS MSDOS.SYS COMMAND.COM $(notdir $(FILES)) > $@.names
	awk '{ print $$NF }' $@.tmp | cmp -s - $@.names || { echo "$<: not the files of FILES" >&2; exit 1; }
	rm $@.names
	mv $@.tmp $@

$(TICO): scripts/fetch-tico
	mkdir -p $(@D)
	tico=$$(scripts/fetch-tico) && cp $$tico/TICO.EXE $$tico/LICENSE $(@D)/

$(BUILD)/image/AUTOEXEC.BAT: image/autoexec.bat
	mkdir -p $(@D)
	sed 's/$$/\r/' $< > $@

$(BUILD)/image/FIND.EXE: $(FIND_OBJS) $(TOOLS) scripts/mslink scripts/mslink-layout scripts/msexe
	mkdir -p $(@D)
	. ./$(TOOLS) && scripts/mslink --exe $@ $(filter %.OBJ,$^)

# Smoke test: the image plus AUTOEXEC.BAT and a program built with Open
# Watcom, independently of the DOS tree (decisions 13 and 14).
$(TESTS)/HELLO.COM: tests/hello/hello.asm $(TOOLS)
	mkdir -p $(@D)
	. ./$(TOOLS) && PATH=$$WATCOM/binl64:$$PATH \
	  && wasm -q -fo=$(@D)/HELLO.OBJ $< \
	  && wlink option quiet format dos com name $@ file $(@D)/HELLO.OBJ

$(TESTS)/AUTOEXEC.BAT: tests/smoke/autoexec.bat
	mkdir -p $(@D)
	sed 's/$$/\r/' $< > $@

$(TESTS)/smoke-%k.img: $(CORE) $(PROGRAMS) $(TESTS)/AUTOEXEC.BAT $(TESTS)/HELLO.COM scripts/mkimage \
	scripts/check-image
	scripts/mkimage --format $* $@ $(SRC) $(PROGRAMS) $(TESTS)/AUTOEXEC.BAT $(TESTS)/HELLO.COM

# The utility tests' disks: the system files, with their AUTOEXEC.BAT and
# input files (CRLF text, named in capitals by mkimage).
UTILS_FILES := $(addprefix $(TESTS)/files/,lines.txt debug.in debugu.in diskcopy.in format.in bootb.bat)
SYS_FILES   := $(addprefix $(TESTS)/files/,format.in bootb.bat)

$(TESTS)/files/%: tests/utils/%
	mkdir -p $(@D)
	sed 's/$$/\r/' $< > $@

$(TESTS)/autoexec-utils/AUTOEXEC.BAT: tests/utils/utils.bat
	mkdir -p $(@D)
	sed 's/$$/\r/' $< > $@

$(TESTS)/autoexec-sys-%k/AUTOEXEC.BAT: tests/utils/sys.bat
	mkdir -p $(@D)
	sed 's|@SIZE@|$*|g; s|@FORMAT@|$(SYS_FORMAT_$*)|; s/$$/\r/' $< > $@

$(TESTS)/utils.img: $(CORE) $(PROGRAMS) $(TESTS)/autoexec-utils/AUTOEXEC.BAT $(UTILS_FILES) scripts/mkimage \
	scripts/check-image
	scripts/mkimage $@ $(SRC) $(PROGRAMS) $(TESTS)/autoexec-utils/AUTOEXEC.BAT $(UTILS_FILES)

$(TESTS)/sys-%k.img: $(CORE) $(PROGRAMS) $(TESTS)/autoexec-sys-%k/AUTOEXEC.BAT $(SYS_FILES) scripts/mkimage \
	scripts/check-image
	scripts/mkimage $@ $(SRC) $(PROGRAMS) $(TESTS)/autoexec-sys-$*k/AUTOEXEC.BAT $(SYS_FILES)
