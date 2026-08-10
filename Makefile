#
# Makefile for IEEE PILOT interpreter/compiler
#

# Configuration
#
# Set up your compiler with CC.  It must be ANSI-compliant.
#
# You will need Bison and Flex.
#
# If you have termcap, you can try -DTERMCAP for terminal-independent I/O
# (otherwise the code will assume VT100 compatibility).
#
# PILOTDIR is the directory PILOT will look for its compilation skeleton in.
# You will preobably want to change it.
#
# SPDX-FileCopyrightText: (C) Eric S. Raymond <esr@thyrsus.com>
# SPDX-License-Identifier: BSD-2-Clause

PREFIX      ?= /usr/local
BINDIR      ?= $(PREFIX)/bin
DATADIR     ?= $(PREFIX)/share
MANDIR      ?= $(DATADIR)/man

CC       = gcc
SYSTYPE	 =
PILOTDIR = .

VERSION=$(shell sed -n <NEWS.adoc '/^[0-9]/s/:.*//p' | head -1)

YACC = bison
LEX = flex

# Optimization and debugging flags
OPTFLAGS += -O
WFLAGS = -Wall -Werror -Werror -Wextra -Wno-unused-result -Wno-unused-function -Wno-unused-parameter
LDFLAGS  = -s
YFLAGS   = -vt
LFLAGS   = -i

CFLAGS  = $(SYSTYPE) $(OPTFLAGS) $(WFLAGS) -DPILOTDIR=\"$(PILOTDIR)\" -Wno-format-truncation

SOURCES = pilot.h pilot_y.y pilot_l.l gencode.[ch] \
	rpilot.c nonstd.c match.c plib.c numconv.c pilotconv.l
DOCS    = local.dic README.adoc COPYING NEWS.adoc pilot.1 pilotconv.1 comments.adoc tour.adoc
SAMPLES = story.p tea.p speaknum.p goldilocks.p tutor.p
META    = control ieee-pilot.jpg
PILOT   = $(DOCS) Makefile $(SOURCES) $(SAMPLES)

# Rules

# Note: to suppress the footers with timestamps being generated in HTML,
# we use "-a nofooter".
# To debug asciidoc problems, you may need to run "xmllint --nonet --noout --valid"
# on the intermediate XML that throws an error.
.SUFFIXES: .html .adoc .1

.adoc.1:
	asciidoctor -D. -a nofooter -b manpage $<
.adoc.html:
	asciidoctor -D. -a nofooter -a webfonts! $<

.PHONY: all man html clean uclean check reflow
.PHONY: install uninstall version dist release refresh

# Build

all: pilot pilotconv

pilot: grammar.o lexer.o gencode.o nonstd.o libpilot.a
	$(CC) $(CFLAGS) grammar.o lexer.o gencode.o nonstd.o $(LDFLAGS) libpilot.a $(LEXLIB) -lncurses -o pilot

libpilot.a: rpilot.o plib.o match.o numconv.o
	ar cr libpilot.a rpilot.o plib.o match.o numconv.o
	-ranlib libpilot.a

grammar.o: grammar.c pilot.h grammar.h gencode.h
lexer.o: lexer.c pilot.h grammar.h gencode.h
gencode.o: gencode.c pilot.h grammar.h gencode.h
nonstd.o: nonstd.c pilot.h grammar.h gencode.h
rpilot.o: rpilot.c pilot.h gencode.h
plib.o: plib.c pilot.h
match.o: match.c pilot.h
numconv.o: numconv.c

lexer.c: pilot_l.l
	$(LEX) $(LFLAGS) -o lexer.c pilot_l.l

grammar.c grammar.h grammar.output: pilot_y.y
	$(YACC) $(YFLAGS) -o grammar.c -d pilot_y.y

pilotconv: pilotconv.l
	$(LEX) $(LFLAGS) -o pilotconv.c pilotconv.l
	$(CC) pilotconv.c -o pilotconv

man: pilot.1 pilotconv.1

html: pilot.html pilotconv.html tour.html comments.html

clean:
	rm -f libpilot.a *.o pilot lexer.c pilotconv grammar.[hc] yacc.*
	rm -f grammar.output pilotconv.c pilotconv *~ \#* *.tar.gz *.md5 TAGS *.html *.1

uclean: clean
	rm -f $(GENERATED) $(GRAMMAR)

# Validate

check: cppcheck pilot
	@$(MAKE) -C tests --quiet

CPPCHECK = --suppress=missingIncludeSystem --suppress=redundantContinue --suppress=checkersReport --suppress=unusedFunction
cppcheck:
	@cppcheck --quiet --template=gcc --enable=all $(CPPCHECK) -DRELEASE=\"$(VERSION)\" gencode.c match.c nonstd.c numconv.c plib.c #pilotconv.l pilot_l.l pilot_y.y


spellcheck:
	@spellcheck local.dic comments.adoc pilot.adoc pilotconv.adoc README.adoc tour.adoc

reflow:
	@clang-format --style="{IndentWidth: 8, UseTab: ForIndentation}" -i $$(find . -name "*.[ch]")

# Install/uninstall

install:
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 pilot $(DESTDIR)$(BINDIR)/pilot
	install -m 755 pilotconv $(DESTDIR)$(BINDIR)/pilotxonv
	install -d $(DESTDIR)$(MANDIR)
	install -d $(DESTDIR)$(MANDIR)/man1
	install pilot.1 $(DESTDIR)$(MANDIR)/man1/pilot.1
	install pilot.1 $(DESTDIR)$(MANDIR)/man1/pilotconv.1

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/pilot
	rm -f $(DESTDIR)$(BINDIR)/pilotconv
	rm -f $(DESTDIR)$(MANDIR)/man1/pilot.1
	rm -f $(DESTDIR)$(MANDIR)/man1/pilotconv.1

# Export

DOCS = local.dic comments.adoc pilot.adoc pilotconv.adoc tour.adoc
META = README.adoc NEWS.adoc control Makefile COPYING ieee-pilot.jpg
CODE = gencode.h numconv.c pilot_l.l match.c pilot_y.y plib.c pilotconv.l gencode.c nonstd.c pilot.h rpilot.c
SOURCES = $(CODE) $(META) $(DOCS) examples tests

version:
	@echo $(VERSION)

ieee-pilot-$(VERSION).tar.gz: $(SOURCES)
	mkdir ieee-pilot-$(VERSION)
	cp -r $(SOURCES) ieee-pilot-$(VERSION)
	tar -czf ieee-pilot-$(VERSION).tar.gz ieee-pilot-$(VERSION)
	rm -fr ieee-pilot-$(VERSION)
	ls -l ieee-pilot-$(VERSION).tar.gz

dist: ieee-pilot-$(VERSION).tar.gz

release: ieee-pilot-$(VERSION).tar.gz pilot.html pilotconv.html
	shipper version=$(VERSION) | sh -e -x

refresh: html
	shipper -N -w version=$(VERSION) | sh -e -x

# end
