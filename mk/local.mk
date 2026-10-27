# mk/local.mk: the consumer hook of this repository (MK-LOCAL).
# sync never touches this file.

# Filesystem configuration
PREFIX		?= /usr/local
BINDIR		?= $(PREFIX)/bin
LIBDIR		?= $(PREFIX)/libdata/perl5/site_perl
MANDIR		?= $(PREFIX)/man
# The installed share tree uses the File::ShareDir layout under the
# perl library path, so Fugu::File->share_path resolves it from @INC.
SHAREDIST	= $(LIBDIR)/auto/share/dist/App-FuguWeb

# Build tools. mandoc renders the cat pages of the man target.
MANDOC		?= mandoc

# The executable joins the module and shebang scan
PERL_SRC_DIRS	= lib bin scripts

# The full test tier set of make test
TEST_GLOBS	= t/fuguweb/*.t t/web/*.t t/scripts/*.t t/ci/*.t

MAN1		= man/fuguweb/fuguweb.1
MAN5		= man/fuguweb/fuguwebrc.5
MAN7		= man/fuguweb/fuguweb-keys.7 man/fuguweb/fuguweb-site.7
CATMAN		= $(MAN1:.1=.cat1) $(MAN5:.5=.cat5) $(MAN7:.7=.cat7)

man: $(CATMAN)

%.cat1: %.1
	$(MANDOC) -Tascii $< > $@

%.cat5: %.5
	$(MANDOC) -Tascii $< > $@

%.cat7: %.7
	$(MANDOC) -Tascii $< > $@

clean: clean-man
	rm -rf build
	rm -f *.tmp

clean-man:
	rm -f $(CATMAN)

install: install-man
	# Install the binary
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 bin/fuguweb $(DESTDIR)$(BINDIR)/fuguweb
	# Install Perl libraries.  App/ is a shared parent: other
	# distributions live there too, so it is created, never removed
	install -d $(DESTDIR)$(LIBDIR)/App
	install -d $(DESTDIR)$(LIBDIR)/App/FuguWeb
	install -m 644 lib/App/FuguWeb.pm lib/App/FuguWeb.pod $(DESTDIR)$(LIBDIR)/App/
	install -m 644 lib/App/FuguWeb/*.pm lib/App/FuguWeb/*.pod $(DESTDIR)$(LIBDIR)/App/FuguWeb/
	# Install the share tree where share_path finds it
	install -d $(DESTDIR)$(SHAREDIST)/fuguweb
	install -m 644 share/fuguweb/style.css $(DESTDIR)$(SHAREDIST)/fuguweb/

install-man:
	# Install man pages
	install -d $(DESTDIR)$(MANDIR)/man1 $(DESTDIR)$(MANDIR)/man5 \
	    $(DESTDIR)$(MANDIR)/man7
	install -m 644 $(MAN1) $(DESTDIR)$(MANDIR)/man1/
	install -m 644 $(MAN5) $(DESTDIR)$(MANDIR)/man5/
	install -m 644 $(MAN7) $(DESTDIR)$(MANDIR)/man7/

uninstall:
	# Remove the binary
	rm -f $(DESTDIR)$(BINDIR)/fuguweb
	# Remove Perl libraries.  App/ is a shared parent: other
	# distributions live beside ours.  Remove what this project
	# owns, then rmdir the parent, which fails harmlessly when it
	# still holds something
	rm -rf $(DESTDIR)$(LIBDIR)/App/FuguWeb
	rm -f $(DESTDIR)$(LIBDIR)/App/FuguWeb.pm
	rm -f $(DESTDIR)$(LIBDIR)/App/FuguWeb.pod
	rm -rf $(DESTDIR)$(SHAREDIST)
	-rmdir $(DESTDIR)$(LIBDIR)/App 2>/dev/null
	# Remove man pages
	rm -f $(DESTDIR)$(MANDIR)/man1/fuguweb.1
	rm -f $(DESTDIR)$(MANDIR)/man5/fuguwebrc.5
	rm -f $(DESTDIR)$(MANDIR)/man7/fuguweb-keys.7
	rm -f $(DESTDIR)$(MANDIR)/man7/fuguweb-site.7

.PHONY: man clean clean-man install install-man uninstall
