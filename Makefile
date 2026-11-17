# GR-DOS Linux build (decisions 11 and 19). `make help` lists the targets
# and variables (HELP, below; issue #43).
#
# Needs Perl 5.42 as `perl` on PATH, a C compiler and make (to build JWasm),
# git, curl and xz; mtools for the image and qemu-system-i386 for the test,
# and fsck.fat (dosfstools) for test-deploy-cf.
# JWasm, Open Watcom and the *16 programs dist16/lock pins (TICO.EXE among
# them; scripts/dist16, issue #36) are fetched into build/tools,
# and the C runtime for ATTRIB, MEM, FDISK and FC, the pinned libc16 release,
# into build/libc16 (scripts/fetch-libc16). make LIBC16_ROOT=../libc16 builds
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
CF    := $(BUILD)/cf

# Patches to v4.0/src, applied in order with patch -p1 (no fuzz): the
# branding (decision 7), then the kernel's GR-DOS identification call
# (patches/kernel, issue #46).
PATCHES := $(sort $(wildcard patches/branding/*.patch)) $(sort $(wildcard patches/kernel/*.patch))

JWFLAGS := -q -Zj -Zm -Zg -Cx -I. -I$(CURDIR)/$(SRC)/INC -I$(CURDIR)/$(SRC)/DOS

# ATTRIB, MEM, FDISK and FC are C, compiled with Open Watcom C for Microsoft C
# 5.1's small model and packed structures, with libc16 as their C runtime
# (its docs/ABI.md): its headers only, as -x ignores INCLUDE, -zl leaves out
# the references to Open Watcom's libraries, and the default register
# convention, with the assembly modules' interfaces declared __cdecl in the
# sources. libc16's headers come first, so that FDISK's own copy of
# Microsoft C's dos.h, which a quoted #include finds, can include libc16's.
LIBC16_ROOT ?= build/libc16
# A release tree, or a checkout, whose make stages the same layout in
# build/stage.
LIBC16_DIR  := $(if $(wildcard $(LIBC16_ROOT)/build/stage/VERSION),$(LIBC16_ROOT)/build/stage,$(LIBC16_ROOT))
LIBC16      := $(LIBC16_DIR)/lib/LIBC16.LIB
WCFLAGS := -q -w0 -zld -zl -x -ms -0 -os -zp1 -s -j -ei -bt=dos \
	-I$(abspath $(LIBC16_DIR))/include -I. -I$(CURDIR)/$(SRC)/H

BOOT_OBJS    := $(SRC)/BOOT/MSBOOT.OBJ
MSLOAD_OBJS  := $(SRC)/BIOS/MSLOAD.OBJ
MSBIO_OBJS   := $(addprefix $(SRC)/,$(shell scripts/lnk-objects v4.0/src BIOS/MSBIO.LNK))
MSDOS_OBJS   := $(addprefix $(SRC)/,$(shell scripts/lnk-objects v4.0/src DOS/MSDOS.LNK))
COMMAND_OBJS := $(addprefix $(SRC)/,$(shell scripts/lnk-objects v4.0/src CMD/COMMAND/COMMAND.LNK))

# The utilities on the system disk (issue #4), in the order they are copied
# to it; each CMD/X directory but MEM's has its X.LNK, and each but FC's its
# X.SKL.
UTILITIES := CMD/FORMAT/FORMAT.COM CMD/SYS/SYS.COM CMD/CHKDSK/CHKDSK.COM \
	CMD/DISKCOPY/DISKCOPY.COM CMD/FDISK/FDISK.EXE CMD/ATTRIB/ATTRIB.EXE CMD/MORE/MORE.COM CMD/FIND/FIND.EXE \
	CMD/FC/FC.EXE CMD/DEBUG/DEBUG.COM CMD/MEM/MEM.EXE CMD/MODE/MODE.COM
UTILITY_DIRS := $(patsubst CMD/%/,%,$(dir $(UTILITIES)))
$(foreach u,$(filter-out MEM FDISK FC,$(UTILITY_DIRS)),\
  $(eval $(u)_OBJS := $(addprefix $(SRC)/,$(shell scripts/lnk-objects v4.0/src CMD/$(u)/$(u).LNK))))
# MEM's makefile links mem+_msgret+_parse.
MEM_OBJS := $(addprefix $(SRC)/CMD/MEM/,MEM.OBJ _MSGRET.OBJ _PARSE.OBJ)

# FDISK (issue #10), C like ATTRIB and MEM. FDBOOT.OBJ, the master boot
# record, is only assembled for BOOTREC to include (FDBOOT.INC): LINK put
# its 2 KB in the program too, but nothing refers to it. The five MAPPER
# routines FDISK calls take the place of MAPPER.LIB.
FDISK_OBJS := $(addprefix $(SRC)/,$(filter-out %/FDBOOT.OBJ,\
	$(shell scripts/lnk-objects v4.0/src CMD/FDISK/FDISK.LNK))) \
	$(addprefix $(SRC)/MAPPER/,BEEP.OBJ EXIT.OBJ SCROLLUP.OBJ SCURPOS.OBJ WCHSTRA.OBJ)
FDISK_C_OBJS := $(filter-out %/REBOOT.OBJ %/BOOTREC.OBJ %/_PARSE.OBJ %/_MSGRET.OBJ,\
	$(filter $(SRC)/CMD/FDISK/%,$(FDISK_OBJS)))

# FC, C too, with INC/KSTRING.C. Its messages are in MESSAGES.ASM.
FC_OBJS   := $(addprefix $(SRC)/,$(shell scripts/lnk-objects v4.0/src CMD/FC/FC.LNK))
FC_C_OBJS := $(addprefix $(SRC)/,$(addsuffix .OBJ,CMD/FC/FC CMD/FC/ERROR CMD/FC/FGETL CMD/FC/NTOI \
	CMD/FC/UPDATE INC/KSTRING))

# The rest of MS-DOS 4.00's assembly utilities (issue #17, docs/m5-utilities.md),
# in CMD's order. Each CMD/X directory has its X.SKL but LABEL (LABL.SKL),
# and its X.LNK but APPEND, ASSIGN and NLSFUNC, whose makefiles name the
# objects. SHARE and IFSFUNC link the kernel's objects from INC and DOS.
EXTRA_UTILITIES := CMD/APPEND/APPEND.EXE CMD/ASSIGN/ASSIGN.COM CMD/COMP/COMP.COM \
	CMD/DISKCOMP/DISKCOMP.COM CMD/EDLIN/EDLIN.COM CMD/EXE2BIN/EXE2BIN.EXE CMD/FASTOPEN/FASTOPEN.EXE \
	CMD/GRAFTABL/GRAFTABL.COM CMD/GRAPHICS/GRAPHICS.COM CMD/IFSFUNC/IFSFUNC.EXE CMD/KEYB/KEYB.COM \
	CMD/LABEL/LABEL.COM CMD/NLSFUNC/NLSFUNC.EXE CMD/PRINT/PRINT.COM CMD/RECOVER/RECOVER.COM \
	CMD/SHARE/SHARE.EXE CMD/SORT/SORT.EXE CMD/TREE/TREE.COM CMD/XCOPY/XCOPY.EXE
EXTRA_DIRS := $(patsubst CMD/%/,%,$(dir $(EXTRA_UTILITIES)))
$(foreach u,$(filter-out APPEND ASSIGN NLSFUNC,$(EXTRA_DIRS)),\
  $(eval $(u)_OBJS := $(addprefix $(SRC)/,$(shell scripts/lnk-objects v4.0/src CMD/$(u)/$(u).LNK))))
APPEND_OBJS  := $(SRC)/CMD/APPEND/APPEND.OBJ
ASSIGN_OBJS  := $(addprefix $(SRC)/CMD/ASSIGN/,ASSGMAIN.OBJ ASSGPARM.OBJ)
NLSFUNC_OBJS := $(addprefix $(SRC)/CMD/NLSFUNC/,NLSFUNC.OBJ NLSPARM.OBJ)

# The country and keyboard data (issue #23, docs/country-keyboard.md):
# COUNTRY.SYS, which CONFIG.SYS's COUNTRY= and NLSFUNC read, and
# KEYBOARD.SYS, KEYB's layouts. DEV/KEYBOARD's tables are linked and
# converted with EXE2BIN; MKCNTRY.EXE holds COUNTRY.SYS and writes it when
# run, which scripts/mkcntry does instead.
KEYBOARD_OBJS := $(addprefix $(SRC)/,$(shell scripts/lnk-objects v4.0/src DEV/KEYBOARD/KEYBOARD.LNK))
MKCNTRY_OBJS  := $(SRC)/DEV/COUNTRY/MKCNTRY.OBJ
NLS_FILES     := DEV/COUNTRY/COUNTRY.SYS DEV/KEYBOARD/KEYBOARD.SYS

OUTPUTS := BOOT/MSBOOT.BIN INC/BOOT.INC BIOS/IO.SYS DOS/MSDOS.SYS CMD/COMMAND/COMMAND.COM \
	$(UTILITIES) $(EXTRA_UTILITIES) $(NLS_FILES)

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
	$(call utility_messages,SYS,1 2 A B C D) \
	$(call utility_messages,FDISK,1 2 A B) CMD/FDISK/FDISK5.CL1 CMD/FDISK/FDISKM.C \
	$(call utility_messages,APPEND,1 2 A B) $(call utility_messages,ASSIGN,1 2 A) \
	$(call utility_messages,COMP,1 2 A) $(call utility_messages,DISKCOMP,1 2 A) \
	$(call utility_messages,EDLIN,1 2 A B C) $(call utility_messages,EXE2BIN,1 2 A B) \
	$(call utility_messages,FASTOPEN,1 2 A) $(call utility_messages,GRAFTABL,1 2 A) \
	$(call utility_messages,GRAPHICS,1 2 A B C) $(call utility_messages,IFSFUNC,1 2 A) \
	$(call utility_messages,KEYB,1 2 A) $(foreach c,1 2 A,CMD/LABEL/LABL.CL$(c)) CMD/LABEL/LABL.CTL \
	$(call utility_messages,NLSFUNC,1 2 A) $(call utility_messages,PRINT,1 2 A B C D) \
	$(call utility_messages,RECOVER,1 2 A) $(call utility_messages,SHARE,1 2 A) \
	$(call utility_messages,SORT,1 2 A) $(call utility_messages,TREE,1 2 A) \
	$(call utility_messages,XCOPY,1 2 A)

# ATTRIB.EXE, MEM.EXE, FDISK.EXE and FC.EXE are built with Open Watcom C,
# not Microsoft C 5.1, so they are not compared. CONVERT makes CHKDSK.EXE
# into CHKDSK.COM, and RECOVER.EXE into RECOVER.COM.
REFERENCE := $(MESSAGES) BOOT/MSBOOT.BIN BIOS/MSLOAD.COM BIOS/IO.SYS DOS/MSDOS.SYS \
	CMD/COMMAND/COMMAND.COM $(filter-out %/ATTRIB.EXE %/MEM.EXE %/FDISK.EXE %/FC.EXE,$(UTILITIES)) \
	CMD/CHKDSK/CHKDSK.EXE CMD/FDISK/FDBOOT.BIN CMD/FDISK/FDBOOT.INC \
	$(EXTRA_UTILITIES) CMD/RECOVER/RECOVER.EXE DEV/COUNTRY/MKCNTRY.EXE $(NLS_FILES)

# Floppy formats, by size in KB (scripts/mkimage --format); 1440 is the
# default.
FORMATS := 1440 1200 720 360
IMAGES  := $(foreach f,$(FORMATS),$(BUILD)/gr-dos-$(f)k.img)
MANIFESTS := $(foreach f,$(FORMATS),$(BUILD)/manifest-$(f)k.txt)
TESTS   := $(BUILD)/tests

# The *16 programs (issue #36, docs/dist16.md): the releases dist16/lock
# pins, which scripts/dist16 fetches and verifies into $(DIST16), with their
# licenses in $(DIST16)/licenses. TICO.EXE (tico16) is one, and is on every
# floppy; the others are on C:\DOS and in the ZIP only, after the rest. If
# any is under a source license, such as the GPL (issue #56), its source is
# in $(DIST16)/source, for the ZIP's SOURCE, and SOURCES.TXT, last in the
# list, says where it is, for C:\DOS and the ZIP's BIN; never on a floppy.
DIST16       := $(BUILD)/dist16
DIST16_FILES := $(addprefix $(DIST16)/,$(shell scripts/dist16 list))
TICO         := $(DIST16)/TICO.EXE
DIST16_EXTRA := $(filter-out $(TICO),$(DIST16_FILES))
$(if $(filter $(TICO),$(DIST16_FILES)),,$(error dist16/lock has no TICO.EXE))

# The programs LINK packed (/EXEPACK) are linked again without it for the
# distribution, in $(BUILD)/image: LINK's EXEPACK loader fails ("Packed file
# is corrupt") when DOS loads the program in the first 64 KB of memory, as
# GR-DOS does. dist maps the build's outputs to the distributed files.
UNPACKED := FIND EXE2BIN IFSFUNC
dist = $(foreach p,$(1),$(if $(filter $(foreach u,$(UNPACKED),$(SRC)/CMD/$(u)/$(u).EXE),$(p)),\
	$(BUILD)/image/$(notdir $(p)),$(p)))

# The programs after IO.SYS, MSDOS.SYS and COMMAND.COM on every image, and
# the files of the 360 KB image, which issue #17 freezes
# (image/files-360k.txt).
PROGRAMS := $(call dist,$(addprefix $(SRC)/,$(UTILITIES))) $(TICO)
FILES    := $(PROGRAMS) $(BUILD)/image/AUTOEXEC.BAT

# The utilities of issue #17 that each larger floppy adds, before
# AUTOEXEC.BAT, for a two-drive machine with the boot disk in A: and data
# in B: (docs/m5-utilities.md, image/files-*k.txt). The 720 KB disk gets
# the everyday file and disk commands, and KEYB with KEYBOARD.SYS and
# COUNTRY.SYS (issue #23); 1.2 MB and 1.44 MB add the rest that work from
# a floppy. FASTOPEN works on hard disks only and IFSFUNC only with an
# installable file system, so they are on C: alone.
extra = $(call dist,$(foreach u,$(1),$(filter $(SRC)/CMD/$(u)/%,$(addprefix $(SRC)/,$(EXTRA_UTILITIES)))))
FLOPPY_720  := XCOPY COMP DISKCOMP LABEL TREE SORT EDLIN PRINT ASSIGN RECOVER KEYB
FLOPPY_1200 := $(FLOPPY_720) APPEND SHARE EXE2BIN GRAFTABL GRAPHICS NLSFUNC
FLOPPY_1440 := $(FLOPPY_1200)
# GRAPHICS reads its printer profile, GRAPHICS.PRO, from its own directory.
# A floppy with KEYB has the data files, in its root, where KEYB and
# COUNTRY= look for them by default.
GRAPHICS_PRO := $(SRC)/CMD/GRAPHICS/GRAPHICS.PRO
NLS_DATA     := $(addprefix $(SRC)/,$(NLS_FILES))
extra_files = $(call extra,$(1)) $(if $(filter GRAPHICS,$(1)),$(GRAPHICS_PRO)) \
	$(if $(filter KEYB,$(1)),$(NLS_DATA))
FILES_360  := $(FILES)
FILES_720  := $(PROGRAMS) $(call extra_files,$(FLOPPY_720)) $(BUILD)/image/AUTOEXEC.BAT
FILES_1200 := $(PROGRAMS) $(call extra_files,$(FLOPPY_1200)) $(BUILD)/image/AUTOEXEC.BAT
FILES_1440 := $(PROGRAMS) $(call extra_files,$(FLOPPY_1440)) $(BUILD)/image/AUTOEXEC.BAT

# GRVER (issue #46, docs/grver.md): GR-DOS's own program, in grver/, which
# reports the release version from the kernel's identification call.
GRVER := $(BUILD)/grver/GRVER.EXE

# Everything, for C:\DOS (scripts/deploy-cf) and the release ZIP: the base
# programs, then all of issue #17's in CMD's order, GRAPHICS.PRO,
# COUNTRY.SYS and KEYBOARD.SYS, GRVER, and the other *16 programs.
ALL_FILES := $(PROGRAMS) $(call dist,$(addprefix $(SRC)/,$(EXTRA_UTILITIES))) $(GRAPHICS_PRO) \
	$(NLS_DATA) $(GRVER) $(DIST16_EXTRA) $(BUILD)/image/AUTOEXEC.BAT

# GR-DOS's own file names, which no *16 program may have, even with
# another extension (COMMAND.COM would run only one of them).
RESERVED = $(sort $(notdir $(CORE) $(filter-out $(DIST16_FILES),$(ALL_FILES)) $(SRC)/CMD/FDISK/FDBOOT.BIN) \
	CONFIG.SYS GRDOS.ID VERSION)

all: $(addprefix $(SRC)/,$(OUTPUTS)) $(IMAGES) $(MANIFESTS) $(CF)/manifest.txt

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
TEST_FLOPPY  := $(addprefix test-floppy-,$(FORMATS))

test: test-help test-dist16 $(TEST_FORMATS) test-utils test-extras $(TEST_FLOPPY) $(TEST_SYS) test-fc test-country \
	test-keyb test-grver test-fdisk test-install test-deploy-cf test-config-include

# scripts/dist16 against a fake GitHub (tests/dist16): offline, no QEMU.
test-dist16: scripts/dist16 tests/dist16/run
	tests/dist16/run $(TESTS)/dist16

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

# issue #17's utilities, with a blank 1.44 MB disk in B: (tests/extras).
test-extras: $(TESTS)/extras.img
	rm -f $(TESTS)/extras-b.img
	mformat -C -i $(TESTS)/extras-b.img -f 1440 -v GRDATA ::
	scripts/smoke-test --timeout 300 --drive-b $(TESTS)/extras-b.img $< tests/extras/expect $(TESTS)/extras

# Each format's files, booted with a blank data disk in B: (tests/floppy).
$(TEST_FLOPPY): test-floppy-%: $(TESTS)/floppy-%k.img
	rm -f $(TESTS)/floppy-$*k-b.img
	mformat -C -i $(TESTS)/floppy-$*k-b.img -f 1440 -v GRDATA ::
	scripts/smoke-test --timeout 120 --drive-b $(TESTS)/floppy-$*k-b.img $< tests/floppy/expect-$*k \
	  $(TESTS)/floppy-$*k

$(TEST_SYS): test-sys-%: $(TESTS)/sys-%k.img
	rm -f $(TESTS)/sys-$*k-b.img
	truncate -s $$(($* * 1024)) $(TESTS)/sys-$*k-b.img
	$(if $(filter 720,$*),mformat -i $(TESTS)/sys-$*k-b.img -f $* -v GRSYS ::)
	scripts/smoke-test --timeout 300 --drive-b $(TESTS)/sys-$*k-b.img --expect tests/utils/expect-sys-$*k \
	  $< tests/utils/expect-sys $(TESTS)/sys-$*k
	scripts/smoke-test $(TESTS)/sys-$*k-b.img tests/utils/expect-boot $(TESTS)/sys-$*k-boot

# The FC tests (tests/fc): FC's output and errorlevels for each command of
# fc.bat up to GRDOS-AB-END, which must be exactly, CRs too, Microsoft's
# (expect.log), written by make fc-expect with the M1 reference build's
# FC.EXE (FC_REFERENCE) in place of the image's; then what Microsoft's
# could not do (tests/fc/expect).
FC_REFERENCE ?= build/m1/SRC/CMD/FC/FC.EXE
fc_output = sed -n '/^GRDOS-TEST-BEGIN\r$$/,/^GRDOS-AB-END\r$$/p' $(1)/serial.log

test-fc: $(TESTS)/fc.img
	scripts/smoke-test $< tests/fc/expect $(TESTS)/fc
	$(call fc_output,$(TESTS)/fc) | cmp - tests/fc/expect.log \
	  || { $(call fc_output,$(TESTS)/fc) | diff -u tests/fc/expect.log - | tr -d '\r'; exit 1; }

fc-expect: $(TESTS)/fc-reference.img
	scripts/smoke-test $< tests/fc/expect-reference $(TESTS)/fc-reference
	$(call fc_output,$(TESTS)/fc-reference) > tests/fc/expect.log

# The country tests (tests/country, issue #23): each boots a 1.44 MB image
# whose CONFIG.SYS is tests/country/NAME/config.sys, with COUNTRY.SYS and
# NLSFUNC, and checks what DOS then reports (tests/country/nlsinfo.asm),
# DATE, TIME and DIR, and CHCP after NLSFUNC.
COUNTRY_TESTS := $(sort $(patsubst tests/country/%/config.sys,%,$(wildcard tests/country/*/config.sys)))
TEST_COUNTRY  := $(addprefix test-country-,$(COUNTRY_TESTS))

test-country: $(TEST_COUNTRY)

$(TEST_COUNTRY): test-country-%: $(TESTS)/country-%.img
	scripts/smoke-test $< tests/country/$*/expect $(TESTS)/country-$*

# GRVER's tests (tests/grver, issue #46): its output and exit status, and
# FAKEID's imitations of the identification call's answer, on GR-DOS; and
# on MS-DOS 4.00, the reference build's kernel (make check's, without
# PATCHES), which must not be taken for GR-DOS.
test-grver: test-grver-grdos test-grver-msdos

test-grver-grdos test-grver-msdos: test-grver-%: $(TESTS)/grver-%.img
	scripts/smoke-test $(if $(filter grdos,$*),--expect $(TESTS)/grver-version.expect) \
	  $< tests/grver/expect-$* $(TESTS)/grver-$*

test-grver-grdos: $(TESTS)/grver-version.expect

# On GR-DOS, GRVER's line is VERSION's, exactly.
$(TESTS)/grver-version.expect: VERSION
	mkdir -p $(@D)
	printf '^GR-DOS %s$$\n' "$$(tr -d ' \r\n' < VERSION | sed 's/[.]/\\./')" > $@

# The KEYB test (tests/keyb, issue #23): keys typed at the 1.44 MB release
# image's prompt, through each layout, read back from the screen.
test-keyb: $(BUILD)/gr-dos-1440k.img scripts/disk-test
	scripts/disk-test $< tests/keyb $(TESTS)/keyb

# The FDISK tests (tests/fdisk, issue #10). Each scenario boots the 1.44 MB
# image, types commands at its prompt and reads the screen, with a new,
# disposable hard disk image (scripts/disk-test). The expected screens and
# disks are what Microsoft's FDISK does, written by make fdisk-expect from
# the M1 reference build's FDISK.EXE (FDISK_REFERENCE) in place of the
# image's, with the GR-DOS branding of the main menu's first line (message
# 1001, the same length); the scenarios that start from another's disk (a
# sectors line) are run after the others.
DISK_TEST   := $(BUILD)/gr-dos-1440k.img scripts/disk-test scripts/disk-sectors scripts/partition-table
FDISK_TESTS := $(sort $(patsubst tests/fdisk/%/script,%,$(wildcard tests/fdisk/*/script)))
TEST_FDISK  := $(addprefix test-fdisk-,$(FDISK_TESTS))
FDISK_REFERENCE ?= build/m1/SRC/CMD/FDISK/FDISK.EXE

test-fdisk: $(TEST_FDISK)

$(TEST_FDISK): test-fdisk-%: $(DISK_TEST)
	scripts/disk-test $< tests/fdisk/$* $(TESTS)/fdisk-$*

# The installation tests (tests/install): GR-DOS installed from the 1.44 MB
# image on a blank hard disk of each size with FDISK, FORMAT and SYS, then
# booted from it. Their expected partition tables are GR-DOS's own.
INSTALL_TESTS := $(sort $(patsubst tests/install/%/script,%,$(wildcard tests/install/*/script)))
TEST_INSTALL  := $(addprefix test-install-,$(INSTALL_TESTS))

test-install: $(TEST_INSTALL)

$(TEST_INSTALL): test-install-%: $(DISK_TEST)
	scripts/disk-test $< tests/install/$* $(TESTS)/install-$*

# The CF card installer's tests (scripts/deploy-cf-test, issue #14): GR-DOS
# provisioned with scripts/deploy-cf on disposable, sparse disk images of
# 512 MB, 2 GB, 4 GB and 8 GB, booted from C:, updated three times with
# every sector outside C: hashed, and booted again; and its refusals and
# recoveries (failures).
DEPLOY_CF_TESTS := 512m 2g 4g 8g failures
TEST_DEPLOY_CF  := $(addprefix test-deploy-cf-,$(DEPLOY_CF_TESTS))

test-deploy-cf: $(TEST_DEPLOY_CF)

$(TEST_DEPLOY_CF): test-deploy-cf-%: $(CF)/manifest.txt scripts/deploy-cf scripts/deploy-cf-test \
	scripts/hd-boot-test scripts/partition-table dist16/lock
	scripts/deploy-cf-test $* $(TESTS)/deploy-cf-$*

# CONFIG.SYS's INCLUDEFILE= (scripts/config-include-test, issue #49): a
# 512 MB CF install, booted with each scenario's C:\CONFIG.SYS and files on
# D:. LOWMEM.COM is the low memory scenario's master boot record.
test-config-include: $(CF)/manifest.txt $(TESTS)/NLSINFO.COM $(TESTS)/LOWMEM.COM \
	scripts/config-include-test scripts/deploy-cf scripts/hd-boot-test
	scripts/config-include-test $(TESTS)/NLSINFO.COM $(TESTS)/LOWMEM.COM $(TESTS)/config-include

$(TESTS)/LOWMEM.COM: tests/config-include/lowmem.asm $(TOOLS)
	mkdir -p $(@D)
	. ./$(TOOLS) && PATH=$$WATCOM/binl64:$$PATH \
	  && wasm -q -fo=$(@D)/LOWMEM.OBJ $< \
	  && wlink option quiet format dos com name $@ file $(@D)/LOWMEM.OBJ

fdisk-expect: $(DISK_TEST) $(FDISK_REFERENCE)
	for t in $$(grep -L '^sectors ' $(addsuffix /script,$(addprefix tests/fdisk/,$(FDISK_TESTS)))) \
	         $$(grep -l '^sectors ' $(addsuffix /script,$(addprefix tests/fdisk/,$(FDISK_TESTS)))); do \
	  t=$$(basename $$(dirname $$t)); \
	  scripts/disk-test --update --fdisk $(FDISK_REFERENCE) $< tests/fdisk/$$t $(TESTS)/fdisk-reference-$$t \
	    || exit 1; \
	  sed -i 's/MS-DOS Version 4\.00/GR-DOS Version 4.00/' tests/fdisk/$$t/*.screen; \
	done

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

dist: all release/README.txt LICENSE v4.0/LICENSE scripts/mkzip $(BUILD)/libc16.stamp $(BUILD)/dist16.stamp
	rm -rf $(DIST) $(RELEASE)
	mkdir -p $(DIST)/$(NAME)/BIN $(RELEASE)
	cp $(CORE) $(ALL_FILES) $(DIST)/$(NAME)/BIN/
	if [ -d $(DIST16)/source ]; then cp -R $(DIST16)/source $(DIST)/$(NAME)/SOURCE; fi
	scripts/dist16 bin-list $(notdir $(TICO)) > $(BUILD)/dist16-bin.txt
	scripts/dist16 sources > $(BUILD)/dist16-sources.txt
	{ \
	  sed -e '/^@DIST16@$$/{r $(BUILD)/dist16-bin.txt' -e 'd;}' \
	    -e '/^@DIST16_SOURCES@$$/{r $(BUILD)/dist16-sources.txt' -e 'd;}' \
	    -e 's/@VERSION@/$(VERSION)/g' release/README.txt; \
	  printf '\n\nGR-DOS\n------\n\n'; cat LICENSE; \
	  printf '\n\nMS-DOS 4.00 source (v4.0/LICENSE)\n---------------------------------\n\n'; cat v4.0/LICENSE; echo; \
	  scripts/dist16 notices $(DIST16); \
	  printf '\n\nlibc16 (in ATTRIB.EXE, MEM.EXE, FDISK.EXE, FC.EXE and GRVER.EXE)\n-----------------------------------------------------------------\n\n'; \
	  cat $(LIBC16_DIR)/LICENSE; \
	} | sed 's/$$/\r/' > $(DIST)/$(NAME)/README.txt
	scripts/dist16 check-dist $(DIST)/$(NAME) $(DIST16)
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

# What make help prints (issue #43): every .PHONY target but those in
# HELP_INTERNAL, by name or as a NAME-like placeholder, which test-help
# checks. make help builds, fetches and runs nothing.
define HELP
GR-DOS build. Usage: make [TARGET] [VARIABLE=value ...]

Build
  make, make all           build the boot sector, IO.SYS, MSDOS.SYS,
                           COMMAND.COM, the utilities, the four floppy
                           images (build/linux/gr-dos-*k.img) and the
                           CF/hard disk distribution (build/linux/cf)
  make check               build without the branding patches and compare
                           with Microsoft's MS-DOS 4.00 reference build
  make dist                package the release assets in build/linux/release
  make clean               remove build/linux (build/tools is kept)
  make run-dosbox          try the tools in DOSBox-X, with C:\DOS as a CF
                           install has it (needs dosbox-x; docs/run-dosbox.md)
  make help                this list

Tests (make test runs them all; most boot GR-DOS in QEMU)
  make test                the whole suite
  make test-FORMAT         boot one floppy image (FORMAT: $(FORMATS))
  make test-floppy-FORMAT  boot one format's files, with a data disk in B:
  make test-sys-FORMAT     FORMAT and SYS a blank disk of the format, boot it
  make test-utils          the utilities, DISKCOPY and FORMAT /S to B:
  make test-extras         the utilities of issue #17, APPEND to XCOPY
  make test-fc             FC, against Microsoft's FC's output
  make test-country        CONFIG.SYS's COUNTRY=, with COUNTRY.SYS; or one
  make test-country-COUNTRY  (COUNTRY: $(COUNTRY_TESTS))
  make test-keyb           KEYB's layouts, typed at the 1.44 MB image's prompt
  make test-grver          GRVER and the kernel's identification call, on
  make test-grver-grdos,     GR-DOS and on MS-DOS 4.00; or one of them
  make test-grver-msdos
  make test-fdisk          FDISK on disposable hard disk images, against
  make test-fdisk-NAME       Microsoft's FDISK; or one (a tests/fdisk directory)
  make test-install        install GR-DOS on a blank hard disk and boot it;
  make test-install-SIZE     or one size (a tests/install directory)
  make test-deploy-cf      scripts/deploy-cf on disk images; or one case
  make test-deploy-cf-CASE   (CASE: $(DEPLOY_CF_TESTS))
  make test-config-include  CONFIG.SYS's INCLUDEFILE=, on a CF install's image
  make test-dist16         scripts/dist16 against a fake GitHub (offline)
  make test-help           check this list against the Makefile's targets

Maintenance
  make dist16-resolve      find the *16 programs on GitHub again, and rewrite
                           dist16/lock (docs/dist16.md)
  make dist16-check        show what dist16-resolve would change
  make fc-expect           rewrite tests/fc's expected output with
                           Microsoft's FC.EXE (FC_REFERENCE)
  make fdisk-expect        rewrite tests/fdisk's expected screens and disks
                           with Microsoft's FDISK.EXE (FDISK_REFERENCE)

Variables
  LIBC16_ROOT=../libc16    build against a libc16 checkout, built with its
                           own make, not the pinned release
  DOSBOX=, DOSBOX_ARGS=    run-dosbox's DOSBox-X, and arguments for it
  FC_REFERENCE=, FDISK_REFERENCE=
                           Microsoft's programs for fc-expect and fdisk-expect
                           (default: the M1 reference build, in build/m1)
endef

# .PHONY targets that are not for users.
HELP_INTERNAL := check-tree msdos-core

help:
	$(info $(HELP))
	@:

# Every .PHONY target is in make help, or in HELP_INTERNAL.
test-help: scripts/check-help
	mkdir -p $(TESTS)
	$(MAKE) --no-print-directory -s help > $(TESTS)/help.txt
	scripts/check-help $(TESTS)/help.txt 'FORMAT=$(FORMATS)' 'NAME=$(FDISK_TESTS)' \
	  'SIZE=$(INSTALL_TESTS)' 'CASE=$(DEPLOY_CF_TESTS)' 'COUNTRY=$(COUNTRY_TESTS)' $(HELP_INTERNAL) -- \
	  $$($(MAKE) --no-print-directory -pRrq : 2>/dev/null | sed -n 's/^\.PHONY: //p')

.PHONY: all check check-tree test $(TEST_FORMATS) test-utils test-extras $(TEST_FLOPPY) $(TEST_SYS) test-fc fc-expect test-fdisk \
	$(TEST_FDISK) test-install $(TEST_INSTALL) test-deploy-cf $(TEST_DEPLOY_CF) fdisk-expect dist clean \
	test-dist16 dist16-resolve dist16-check run-dosbox help test-help test-country $(TEST_COUNTRY) test-keyb \
	test-grver test-grver-grdos test-grver-msdos msdos-core test-config-include
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

# GRAPHICS's printer profile is a source file, copied as is into the tree.
$(GRAPHICS_PRO): $(BUILD)/tree.stamp

# Message files (BUILDMSG/NOSRVBLD); the case aliases cover their references too.
# FDISK's menus are C (MENUBLD), and FDISK5.CL1 the messages of its boot record.
$(BUILD)/messages.stamp: $(BUILD)/tree.stamp scripts/buildmsg scripts/menubld scripts/case-alias
	scripts/buildmsg --nosrvbld $(MSG) $(SRC)/BOOT/BOOT.SKL
	scripts/buildmsg --nosrvbld $(MSG) $(SRC)/BIOS/MSBIO.SKL
	scripts/buildmsg --nosrvbld $(MSG) $(SRC)/DOS/MSDOS.SKL
	scripts/buildmsg $(MSG) $(SRC)/CMD/COMMAND/COMMAND.SKL
	for u in $(filter-out FC,$(UTILITY_DIRS)) $(filter-out LABEL,$(EXTRA_DIRS)); do \
	  scripts/buildmsg $(MSG) $(SRC)/CMD/$$u/$$u.SKL || exit 1; \
	done
	scripts/buildmsg $(MSG) $(SRC)/CMD/LABEL/LABL.SKL
	for u in SHARE IFSFUNC; do \
	  cp $(SRC)/DOS/MSDOS.SKL $(SRC)/CMD/$$u/ && scripts/buildmsg --nosrvbld $(MSG) $(SRC)/CMD/$$u/MSDOS.SKL || exit 1; \
	done
	cp $(SRC)/BOOT/BOOT.CL1 $(SRC)/CMD/FORMAT/
	scripts/buildmsg --nosrvbld $(MSG) $(SRC)/CMD/FDISK/FDISK5.SKL
	scripts/menubld $(SRC)/CMD/FDISK/FDISK.MSG $(MSG) $(SRC)/CMD/FDISK/FDISKM.C
	scripts/case-alias $(SRC) > /dev/null
	touch $@

$(SRC)/%.OBJ: $(BUILD)/messages.stamp $(TOOLS)
	. ./$(TOOLS) && cd $(@D) && "$$JWASM" $(JWFLAGS) -Fo$(@F) $(notdir $*).ASM

# FORMAT and SYS include the boot sector.
$(SRC)/CMD/FORMAT/MSFOR.OBJ $(SRC)/CMD/SYS/SYS1.OBJ: $(SRC)/INC/BOOT.INC

# The kernel's dispatcher (DISP.ASM, in MSDISP.ASM) includes the GR-DOS
# release version for its identification call (patches/kernel, issue #46):
# VERSION, n.nn, as GRDOS_MAJOR and GRDOS_MINOR (0 to 99).
$(SRC)/DOS/GRDOSVER.INC: VERSION $(BUILD)/tree.stamp
	v=$$(tr -d ' \r\n' < VERSION); \
	  echo "$$v" | grep -Eq '^[0-9]{1,3}\.[0-9]{2}$$' \
	  && echo "$$v" | awk -F. '{ exit !($$1 + 0 <= 255) }' \
	  || { echo "VERSION is not n.nn (major 0 to 255): $$v" >&2; exit 1; }; \
	  echo "$$v" | awk -F. '{ printf "; GR-DOS release %s, from VERSION (Makefile)\r\nGRDOS_MAJOR\tEQU\t%d\r\nGRDOS_MINOR\tEQU\t%d\r\n", $$0, $$1 + 0, $$2 + 0 }' > $@

$(SRC)/DOS/MSDISP.OBJ: $(SRC)/DOS/GRDOSVER.INC

# FDISK includes the master boot record.
$(SRC)/CMD/FDISK/BOOTREC.OBJ: $(SRC)/CMD/FDISK/FDBOOT.INC

C_OBJS := $(SRC)/CMD/ATTRIB/ATTRIB.OBJ $(SRC)/CMD/MEM/MEM.OBJ $(FDISK_C_OBJS) $(FC_C_OBJS)

$(C_OBJS): %.OBJ: $(BUILD)/messages.stamp $(TOOLS) $(BUILD)/libc16.stamp
	. ./$(TOOLS) && cd $(@D) && PATH=$$WATCOM/binl64:$$PATH \
	  wcc $(WCFLAGS) -fo=$(@F) $(notdir $*).C

$(SRC)/BOOT/MSBOOT.EXE:         $(BOOT_OBJS)
$(SRC)/BIOS/MSLOAD.EXE:         $(MSLOAD_OBJS)
$(SRC)/BIOS/MSBIO.EXE:          $(MSBIO_OBJS)
$(SRC)/DOS/MSDOS.EXE:           $(MSDOS_OBJS)
$(SRC)/CMD/COMMAND/COMMAND.EXE: $(COMMAND_OBJS)
$(foreach u,$(filter-out ATTRIB MEM FDISK FC,$(UTILITY_DIRS)) $(EXTRA_DIRS),\
  $(eval $(SRC)/CMD/$(u)/$(u).EXE: $($(u)_OBJS)))

$(SRC)/CMD/FDISK/FDBOOT.EXE:    $(SRC)/CMD/FDISK/FDBOOT.OBJ
$(SRC)/DEV/KEYBOARD/KEYBOARD.EXE: $(KEYBOARD_OBJS)
$(SRC)/DEV/COUNTRY/MKCNTRY.EXE: $(MKCNTRY_OBJS)

EXES := $(addprefix $(SRC)/,BOOT/MSBOOT.EXE BIOS/MSLOAD.EXE BIOS/MSBIO.EXE DOS/MSDOS.EXE \
	CMD/COMMAND/COMMAND.EXE CMD/FDISK/FDBOOT.EXE DEV/KEYBOARD/KEYBOARD.EXE DEV/COUNTRY/MKCNTRY.EXE) \
	$(foreach u,$(filter-out ATTRIB MEM FDISK FC,$(UTILITY_DIRS)) $(EXTRA_DIRS),$(SRC)/CMD/$(u)/$(u).EXE)

# The programs CONVERT makes into .COM files are linked as Microsoft LINK
# writes them, and FIND as LINK /EXEPACK writes it.
CONVERTED := FORMAT CHKDSK DEBUG EDLIN PRINT RECOVER
$(foreach u,$(CONVERTED),$(SRC)/CMD/$(u)/$(u).EXE): MSLINK := --exe
$(SRC)/CMD/FIND/FIND.EXE: MSLINK := --exepack
# The .EXE utilities of issue #17; EXE2BIN and IFSFUNC are linked /EXEPACK.
EXE_EXTRAS := APPEND FASTOPEN NLSFUNC SHARE SORT XCOPY
$(foreach u,$(EXE_EXTRAS),$(SRC)/CMD/$(u)/$(u).EXE): MSLINK := --exe
$(SRC)/CMD/EXE2BIN/EXE2BIN.EXE $(SRC)/CMD/IFSFUNC/IFSFUNC.EXE: MSLINK := --exepack
$(SRC)/DEV/COUNTRY/MKCNTRY.EXE: MSLINK := --exe

# SORT's makefile then runs EXEFIX, which scripts/exefix replaces.
$(SRC)/CMD/SORT/SORT.EXE: EXEFIX := 1 1

$(EXES): %.EXE: $(TOOLS) scripts/mslink scripts/mslink-layout scripts/msexe scripts/exefix
	. ./$(TOOLS) && scripts/mslink $(MSLINK) $@ $(filter %.OBJ,$^)
	$(if $(EXEFIX),scripts/exefix $@ $(EXEFIX))

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
$(SRC)/CMD/FDISK/FDISK.EXE:   $(FDISK_OBJS)
$(SRC)/CMD/FC/FC.EXE:         $(FC_OBJS)

# No default libraries: the map, X.MAP, must show only the objects and
# LIBC16.LIB (scripts/check-runtime).
$(SRC)/CMD/ATTRIB/ATTRIB.EXE $(SRC)/CMD/MEM/MEM.EXE $(SRC)/CMD/FDISK/FDISK.EXE $(SRC)/CMD/FC/FC.EXE: $(TOOLS) $(BUILD)/libc16.stamp \
	scripts/check-runtime
	. ./$(TOOLS) && PATH=$$WATCOM/binl64:$$PATH && wlink option quiet format dos \
	  option nocaseexact option nodefaultlibs option map=$(@:.EXE=.MAP) \
	  name $@ $(foreach o,$(filter %.OBJ,$^),file $(o)) library $(LIBC16)
	scripts/check-runtime $(@:.EXE=.MAP) $(LIBC16) $(filter %.OBJ,$^)

# GRVER, C with libc16 and its startup, like MEM.
$(BUILD)/grver/GRVER.OBJ: grver/grver.c $(TOOLS) $(BUILD)/libc16.stamp
	mkdir -p $(@D)
	. ./$(TOOLS) && PATH=$$WATCOM/binl64:$$PATH \
	  wcc $(filter-out -w0 -I$(CURDIR)/$(SRC)/H,$(WCFLAGS)) -w4 -we -fo=$@ $<

$(GRVER): $(BUILD)/grver/GRVER.OBJ $(TOOLS) $(BUILD)/libc16.stamp scripts/check-runtime
	. ./$(TOOLS) && PATH=$$WATCOM/binl64:$$PATH && wlink option quiet format dos \
	  option nocaseexact option nodefaultlibs option map=$(@:.EXE=.MAP) \
	  name $@ file $< library $(LIBC16)
	scripts/check-runtime $(@:.EXE=.MAP) $(LIBC16) $<

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

EXE2BIN := SYS MORE DISKCOPY MODE ASSIGN COMP DISKCOMP GRAFTABL GRAPHICS KEYB LABEL TREE
$(foreach u,$(EXE2BIN),$(eval $(SRC)/CMD/$(u)/$(u).COM: $($(u)_OBJS)))

$(foreach u,$(EXE2BIN),$(SRC)/CMD/$(u)/$(u).COM): %.COM: %.EXE scripts/exe2bin scripts/mslink-layout
	scripts/exe2bin --size $(size) $< $@

# KEYBOARD.SYS: the tables, from offset 0 (DEV/KEYBOARD/MAKEFILE).
$(SRC)/DEV/KEYBOARD/KEYBOARD.SYS: $(SRC)/DEV/KEYBOARD/KEYBOARD.EXE $(KEYBOARD_OBJS) scripts/exe2bin \
	scripts/mslink-layout
	scripts/exe2bin --size $(size) $< $@

# COUNTRY.SYS: what MKCNTRY.EXE writes (DEV/COUNTRY/MAKEFILE runs it).
$(SRC)/DEV/COUNTRY/COUNTRY.SYS: $(SRC)/DEV/COUNTRY/MKCNTRY.EXE scripts/mkcntry
	scripts/mkcntry $< $@

# CONVERT: a .COM program that loads the .EXE it holds.
$(foreach u,$(CONVERTED),$(SRC)/CMD/$(u)/$(u).COM): %.COM: %.EXE scripts/convert
	scripts/convert $< $@

# DBOF: the boot sector for FORMAT and SYS.
$(SRC)/INC/BOOT.INC: $(SRC)/BOOT/MSBOOT.BIN scripts/dbof
	scripts/dbof $< $@ 7c00 200

# The master boot record for FDISK, at 0:0600 (FDBOOT.ASM's ORG).
$(SRC)/CMD/FDISK/FDBOOT.BIN: $(SRC)/CMD/FDISK/FDBOOT.EXE $(SRC)/CMD/FDISK/FDBOOT.OBJ scripts/exe2bin \
	scripts/mslink-layout
	scripts/exe2bin --size $(size) $< $@

# BOOTREC includes it as fdboot.inc.
$(SRC)/CMD/FDISK/FDBOOT.INC: $(SRC)/CMD/FDISK/FDBOOT.BIN scripts/dbof
	scripts/dbof $< $@ 600 200
	ln -sf FDBOOT.INC $(@D)/fdboot.inc

# The bootable floppy images (decisions 5 and 12).
CORE := $(addprefix $(SRC)/,BOOT/MSBOOT.BIN BIOS/IO.SYS DOS/MSDOS.SYS CMD/COMMAND/COMMAND.COM)

# Each image holds the files of its format, FILES_360 and so on. The list
# of names each must have, in order, is image/files-FORMATk.txt: make
# checks the image against it, so a change to a format's files is a change
# to that list too (issue #17), and the 360 KB image's stays as it was.
define image_rules
$(BUILD)/gr-dos-$(1)k.img: $(CORE) $(FILES_$(1)) scripts/mkimage scripts/check-image
	scripts/mkimage --format $(1) $$@ $(SRC) $(FILES_$(1))

$(BUILD)/manifest-$(1)k.txt: $(BUILD)/gr-dos-$(1)k.img image/files-$(1)k.txt scripts/image-manifest
	scripts/image-manifest $$< > $$@.tmp
	printf '%s\n' IO.SYS MSDOS.SYS COMMAND.COM $(notdir $(FILES_$(1))) | cmp -s - image/files-$(1)k.txt \
	  || { echo "FILES_$(1) is not image/files-$(1)k.txt" >&2; exit 1; }
	awk '{ print $$$$NF }' $$@.tmp | cmp -s - image/files-$(1)k.txt \
	  || { echo "$$<: not the files of image/files-$(1)k.txt" >&2; exit 1; }
	mv $$@.tmp $$@
endef
$(foreach f,$(FORMATS),$(eval $(call image_rules,$(f))))

# The distribution scripts/deploy-cf installs on a CF card or hard disk
# (issue #14): ALL_FILES but AUTOEXEC.BAT, which deploy-cf writes for C:,
# with their manifest, the boot sector, FDISK's master boot record and
# VERSION. The manifest is that of a 1.44 MB image of them, so that the
# files are stamped as on the floppies.
$(CF)/manifest.txt: $(CORE) $(ALL_FILES) $(SRC)/CMD/FDISK/FDBOOT.BIN VERSION scripts/mkimage \
	scripts/check-image scripts/image-manifest
	rm -rf $(CF)
	mkdir -p $(CF)
	scripts/mkimage --format 1440 $(BUILD)/all-files.img $(SRC) $(ALL_FILES)
	cp $(CORE) $(filter-out %/AUTOEXEC.BAT,$(ALL_FILES)) $(SRC)/CMD/FDISK/FDBOOT.BIN VERSION $(CF)/
	scripts/image-manifest $(BUILD)/all-files.img | grep -v '  AUTOEXEC\.BAT$$' > $@.tmp
	rm $(BUILD)/all-files.img
	scripts/dist16 check-dist $(CF) $(DIST16)
	mv $@.tmp $@

# The *16 programs; a verified copy in build/tools/dist16 is not downloaded
# again.
$(BUILD)/dist16.stamp: dist16/lock scripts/dist16
	scripts/dist16 --reserved "$(RESERVED)" fetch $(DIST16)
	touch $@

$(DIST16_FILES): $(BUILD)/dist16.stamp

# Find the *16 programs on GitHub again and rewrite dist16/lock, with a
# report of what is included and what is not and why (dist16-resolve); or
# only show how the lock differs from that (dist16-check). Neither is part
# of the build.
dist16-resolve dist16-check: dist16-%:
	scripts/dist16 --reserved "$(RESERVED)" $*

# DOSBox-X with C:\DOS as a CF install has it (docs/run-dosbox.md): its own
# DOS kernel and shell, not GR-DOS's. Interactive, and not part of make
# test. C: is copied afresh each time; D:, $(BUILD)/dosbox/D, is kept until
# make clean.
DOSBOX      ?= dosbox-x
DOSBOX_ARGS ?=
run-dosbox: $(CF)/manifest.txt scripts/run-dosbox
	scripts/run-dosbox --dosbox "$(DOSBOX)" $(CF) $(BUILD)/dosbox $(DOSBOX_ARGS)

$(BUILD)/image/AUTOEXEC.BAT: image/autoexec.bat
	mkdir -p $(@D)
	sed 's/$$/\r/' $< > $@

$(foreach u,$(UNPACKED),$(eval $(BUILD)/image/$(u).EXE: $($(u)_OBJS)))
$(foreach u,$(UNPACKED),$(BUILD)/image/$(u).EXE): $(TOOLS) scripts/mslink scripts/mslink-layout scripts/msexe
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

# The FC tests' disks: GR-DOS's FC.EXE, or Microsoft's.
FC_FILES := $(addprefix $(TESTS)/fc-files/,a.txt b.txt case.txt space.txt long.txt many.txt tabs.txt \
	spaces.txt intl.txt intlup.txt wide.txt wide2.txt big.txt big2.txt rep.txt rep2.txt el.bat)

$(TESTS)/fc-files/%: tests/fc/%
	mkdir -p $(@D)
	sed 's/$$/\r/' $< > $@

$(TESTS)/autoexec-fc/AUTOEXEC.BAT: tests/fc/fc.bat
	mkdir -p $(@D)
	sed 's/$$/\r/' $< > $@

# The tests of issue #17's utilities (tests/extras): ALL_FILES, the test
# AUTOEXEC.BAT and input files, and HELLOX.EXE, the smoke test program
# linked as an .EXE for EXE2BIN, with the 512-byte header LINK writes
# (tests/extras/pad-header).
EXTRAS_FILES := $(addprefix $(TESTS)/extras-files/,sort.txt comp.in edlin.in label.in recover.in \
	diskcomp.in print.in same1.txt same2.txt diff.txt) \
	$(addprefix $(TESTS)/files/,lines.txt diskcopy.in) $(TESTS)/HELLOX.EXE

$(TESTS)/extras-files/%: tests/extras/%
	mkdir -p $(@D)
	sed 's/$$/\r/' $< > $@

$(TESTS)/autoexec-extras/AUTOEXEC.BAT: tests/extras/extras.bat
	mkdir -p $(@D)
	sed 's/$$/\r/' $< > $@

$(TESTS)/HELLOX.EXE: $(TESTS)/HELLO.COM tests/extras/pad-header
	. ./$(TOOLS) && PATH=$$WATCOM/binl64:$$PATH \
	  && wlink option quiet format dos name $@.tmp file $(@D)/HELLO.OBJ
	tests/extras/pad-header $@.tmp $@
	rm $@.tmp

$(TESTS)/extras.img: $(CORE) $(ALL_FILES) $(TESTS)/autoexec-extras/AUTOEXEC.BAT $(EXTRAS_FILES) \
	scripts/mkimage scripts/check-image
	scripts/mkimage $@ $(SRC) $(filter-out %/AUTOEXEC.BAT,$(ALL_FILES)) \
	  $(TESTS)/autoexec-extras/AUTOEXEC.BAT $(EXTRAS_FILES)

# The country tests' disks: the system files, the scenario's CONFIG.SYS,
# the test program, COUNTRY.SYS and NLSFUNC.
$(TESTS)/NLSINFO.COM: tests/country/nlsinfo.asm $(TOOLS)
	mkdir -p $(@D)
	. ./$(TOOLS) && PATH=$$WATCOM/binl64:$$PATH \
	  && wasm -q -fo=$(@D)/NLSINFO.OBJ $< \
	  && wlink option quiet format dos com name $@ file $(@D)/NLSINFO.OBJ

$(TESTS)/autoexec-country/AUTOEXEC.BAT: tests/country/country.bat
	mkdir -p $(@D)
	sed 's/$$/\r/' $< > $@

$(TESTS)/autoexec-country/ENTER.IN:
	mkdir -p $(@D)
	printf '\r\n' > $@

$(TESTS)/country-%/CONFIG.SYS: tests/country/%/config.sys
	mkdir -p $(@D)
	sed 's/$$/\r/' $< > $@

country_files = $(TESTS)/country-$(1)/CONFIG.SYS $(TESTS)/NLSINFO.COM $(SRC)/DEV/COUNTRY/COUNTRY.SYS \
	$(SRC)/CMD/NLSFUNC/NLSFUNC.EXE $(TESTS)/autoexec-country/AUTOEXEC.BAT $(TESTS)/autoexec-country/ENTER.IN

define country_test_image
$(TESTS)/country-$(1).img: $(CORE) $(call country_files,$(1)) scripts/mkimage scripts/check-image
	scripts/mkimage $$@ $(SRC) $(call country_files,$(1))
endef
$(foreach t,$(COUNTRY_TESTS),$(eval $(call country_test_image,$(t))))

# GRVER's test disks: GRVER, FAKEID and the batch files, with GR-DOS's
# system files or MS-DOS 4.00's. The reference build is make check's; its
# files are made by the same sub-make, which does nothing when they are up
# to date.
MSDOS_SRC  := $(BUILD)/reference/$(notdir $(SRC))
MSDOS_CORE := $(addprefix $(MSDOS_SRC)/,BOOT/MSBOOT.BIN BIOS/IO.SYS DOS/MSDOS.SYS CMD/COMMAND/COMMAND.COM)

$(TESTS)/FAKEID.COM: tests/grver/fakeid.asm $(TOOLS)
	mkdir -p $(@D)
	. ./$(TOOLS) && PATH=$$WATCOM/binl64:$$PATH \
	  && wasm -q -fo=$(@D)/FAKEID.OBJ $< \
	  && wlink option quiet format dos com name $@ file $(@D)/FAKEID.OBJ

$(TESTS)/grver-files/AUTOEXEC.BAT: tests/grver/grver.bat
	mkdir -p $(@D)
	sed 's/$$/\r/' $< > $@

$(TESTS)/grver-files/RC.BAT: tests/grver/rc.bat
	mkdir -p $(@D)
	sed 's/$$/\r/' $< > $@

$(TESTS)/grver-files/FAKE.BAT: tests/grver/fake.bat
	mkdir -p $(@D)
	sed 's/$$/\r/' $< > $@

GRVER_TEST_FILES := $(GRVER) $(TESTS)/FAKEID.COM \
	$(addprefix $(TESTS)/grver-files/,AUTOEXEC.BAT RC.BAT FAKE.BAT)

$(TESTS)/grver-grdos.img: $(CORE) $(GRVER_TEST_FILES) scripts/mkimage scripts/check-image
	scripts/mkimage $@ $(SRC) $(GRVER_TEST_FILES)

$(TESTS)/grver-msdos.img: msdos-core $(GRVER_TEST_FILES) scripts/mkimage scripts/check-image
	scripts/mkimage $@ $(MSDOS_SRC) $(GRVER_TEST_FILES)

msdos-core: $(TOOLS)
	$(MAKE) BUILD=$(BUILD)/reference TOOLS=$(TOOLS) PATCHES= $(MSDOS_CORE)

# The distribution tests' disks (tests/floppy): the files of one format,
# with the test AUTOEXEC.BAT for the image's, and COMP's answer.
$(TESTS)/autoexec-floppy/AUTOEXEC.BAT: tests/floppy/floppy.bat
	mkdir -p $(@D)
	sed 's/$$/\r/' $< > $@

define floppy_test_image
$(TESTS)/floppy-$(1)k.img: $(CORE) $(FILES_$(1)) $(TESTS)/autoexec-floppy/AUTOEXEC.BAT \
	$(TESTS)/extras-files/comp.in scripts/mkimage scripts/check-image
	scripts/mkimage --format $(1) $$@ $(SRC) $(filter-out %/AUTOEXEC.BAT,$(FILES_$(1))) \
	  $(TESTS)/autoexec-floppy/AUTOEXEC.BAT $(TESTS)/extras-files/comp.in
endef
$(foreach f,$(FORMATS),$(eval $(call floppy_test_image,$(f))))

$(TESTS)/fc.img: $(CORE) $(PROGRAMS) $(TESTS)/autoexec-fc/AUTOEXEC.BAT $(FC_FILES) scripts/mkimage \
	scripts/check-image
	scripts/mkimage $@ $(SRC) $(PROGRAMS) $(TESTS)/autoexec-fc/AUTOEXEC.BAT $(FC_FILES)

$(TESTS)/fc-reference/FC.EXE: $(FC_REFERENCE)
	mkdir -p $(@D)
	cp $< $@

$(TESTS)/fc-reference.img: $(CORE) $(PROGRAMS) $(TESTS)/fc-reference/FC.EXE $(TESTS)/autoexec-fc/AUTOEXEC.BAT \
	$(FC_FILES) scripts/mkimage scripts/check-image
	scripts/mkimage $@ $(SRC) $(filter-out $(SRC)/CMD/FC/FC.EXE,$(PROGRAMS)) $(TESTS)/fc-reference/FC.EXE \
	  $(TESTS)/autoexec-fc/AUTOEXEC.BAT $(FC_FILES)

$(TESTS)/sys-%k.img: $(CORE) $(PROGRAMS) $(TESTS)/autoexec-sys-%k/AUTOEXEC.BAT $(SYS_FILES) scripts/mkimage \
	scripts/check-image
	scripts/mkimage $@ $(SRC) $(PROGRAMS) $(TESTS)/autoexec-sys-$*k/AUTOEXEC.BAT $(SYS_FILES)
