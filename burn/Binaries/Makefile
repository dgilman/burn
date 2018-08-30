
MACPORTS_PREFIX=/opt/local
MACPORTS_LIBDIR=$(MACPORTS_PREFIX)/lib

# dvda-author: currently doesn't build on mac
# movtowav movtoy4m: this is part of Johan Lindstrom's
# movtoy4m package. Unfortunately his homepage is no longer
# online and the Internet Archive did not archive his code.

#all: dvda-author dvdauthor ffmpeg mkisofs movtowav movtoy4m spumux
all: dvdauthor ffmpeg mkisofs

dvda-author: dvda-author-git/cloned
	cd $@-git && MAKE_PATH=/opt/local/bin/gmake ./configure && make
	exit -1

dvda-author-git/cloned:
	git clone https://git.code.sf.net/p/dvd-audio/dev dvda-author-git
	touch $@

dvdauthor: dvdauthor-0.7.2/cloned
	cd dvdauthor-0.7.2 && ./configure --disable-dvdunauthor --with-libiconv-prefix=$(MACPORTS_PREFIX)
	cd dvdauthor-0.7.2/src && make dvdauthor
	cd dvdauthor-0.7.2/src && make spumux
# link it by hand... i coudn't get autoconf to do it
# this is just copied from the makefile's output, but with .a files patched in
	cd dvdauthor-0.7.2/src && /bin/sh ../libtool  --tag=CC   --mode=link gcc -Wall -g -O2 -o dvdauthor dvdauthor.o dvdcompile.o dvdvml.o dvdvmy.o dvdifo.o dvdvob.o dvdpgc.o dvdcli.o readxml.o conffile.o compat.o $(MACPORTS_LIBDIR)/libxml2.a -lz -llzma -lpthread $(MACPORTS_LIBDIR)/libiconv.a -lm
	cp dvdauthor-0.7.2/src/dvdauthor .
	strip dvdauthor
	otool -L dvdauthor
	cd dvdauthor-0.7.2/src && /bin/sh ../libtool  --tag=CC   --mode=link gcc -Wall -g -O2 -o spumux subgen.o subgen-parse-xml.o readxml.o subgen-encode.o subgen-image.o conffile.o compat.o subrender.o subreader.o subfont.o $(MACPORTS_LIBDIR)/libxml2.a -lz -llzma -lpthread $(MACPORTS_LIBDIR)/libiconv.a -lm $(MACPORTS_LIBDIR)/libpng16.a $(MACPORTS_LIBDIR)/libfreetype.a $(MACPORTS_LIBDIR)/libfontconfig.a $(MACPORTS_LIBDIR)/libfreetype.a -lm $(MACPORTS_LIBDIR)/libexpat.a $(MACPORTS_LIBDIR)/libintl.a $(MACPORTS_LIBDIR)/libbz2.a -framework CoreFoundation
	cp dvdauthor-0.7.2/src/spumux .
	strip spumux
	otool -L spumux

dvdauthor-0.7.2/cloned:
	rm tars/dvdauthor-* || true
	rm -rf dvdauthor-* || true
	mkdir -p tars
	cd tars && wget "https://downloads.sourceforge.net/project/dvdauthor/dvdauthor-0.7.2.tar.gz"
	tar xf tars/dvdauthor-*.tar.gz --strip-components=1 --one-top-level=dvdauthor-0.7.2
	touch $@

mkisofs: cdrtools-3.02/cloned
	cd cdrtools-3.02 && make GMAKE_NOWARN=true
	cp cdrtools-3.02/mkisofs/OBJ/i386-darwin-clang/mkisofs .
	otool -L mkisofs

cdrtools-3.02/cloned:
	rm tars/cdrtools-* || true
	rm -rf cdrtools-*
	mkdir -p tars
	cd tars && wget "https://downloads.sourceforge.net/project/cdrtools/alpha/cdrtools-3.02a09.tar.gz"
	tar xf tars/cdrtools-*.tar.gz
	touch $@

ffmpeg:
	rm -rf ffmpeg tars/ffmpeg*
	mkdir -p tars
	# These are daily builds of ffmpeg - this URL will likely need to be replaced often
	cd tars && wget "https://evermeet.cx/pub/ffmpeg/snapshots/ffmpeg-91715-gd71dfc087b.7z"
	cd tars && 7z x ffmpeg*.7z
	mv tars/ffmpeg ffmpeg

clean:
	rm -rf tars
	rm -rf dvda-author-git
	rm -rf dvdauthor-0.7.2
	rm -rf cdrtools-3.02


dvda-author-dev-20180607.tar.xz:
	wget "https://downloads.sourceforge.net/project/dvd-audio/dvda-author/dvda-author-dev/linux%20%2B%20source%20%28Gentoo%20amd64%20build%29/dvda-author-dev-20180607.tar.xz"
