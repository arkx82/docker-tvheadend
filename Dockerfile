FROM lsiobase/alpine:3.6
MAINTAINER saarg

# package version
ARG ARGTABLE_VER="2.13"
ARG TVH_VER="v4.2.2"
ARG TZ="Asia/Seoul"
ARG XMLTV_VER="0.5.69"
ARG EPG2XML_VER="1.1.9"

# set version label
ARG BUILD_DATE
ARG VERSION
LABEL build_version="Build-date:- ${BUILD_DATE}"

# Environment settings
ENV HOME="/config"

# copy patches
COPY patches/ /tmp/patches/

# install build packages
RUN \
 apk add --no-cache --virtual=build-dependencies \
	autoconf \
	automake \
	cmake \
	coreutils \
	ffmpeg-dev \
	file \
	findutils \
	g++ \
	gcc \
	gettext-dev \
	git \
	libgcrypt-dev \
	libhdhomerun-dev \
	libressl-dev \
	libtool \
	libxml2-dev \
	libxslt-dev \
	libdvbcsa-dev \
#	libva-dev \
	make \
	mercurial \
	patch \
	pcre2-dev \
	perl-dev \
	pkgconf \
	sdl-dev \
	uriparser-dev \
	wget \
	zlib-dev && \
 apk add --no-cache --virtual=build-dependencies \
	--repository http://nl.alpinelinux.org/alpine/edge/testing \
	gnu-libiconv-dev && \

# add runtime dependencies required in build stage
 apk add --no-cache \
	bsd-compat-headers \
	bzip2 \
	curl \
	gzip \
	libcrypto1.0 \
	libcurl	\
	libressl \
	libssl1.0 \
	linux-headers \
	pcre2 \
	perl \
	perl-archive-zip \
	perl-boolean \
	perl-capture-tiny \
	perl-cgi \
	perl-compress-raw-zlib \
	perl-data-dumper \
	perl-date-manip \
	perl-datetime \
	perl-datetime-format-strptime \
	perl-datetime-timezone \
	perl-dbd-sqlite \
	perl-dbi \
	perl-digest-sha1 \
	perl-doc \
	perl-file-slurp \
	perl-file-temp \
	perl-file-which \
	perl-getopt-long \
	perl-html-parser \
	perl-html-tree \
	perl-http-cookies \
	perl-io \
	perl-io-compress \
	perl-io-html \
	perl-io-socket-ssl \
	perl-io-stringy \
	perl-json \
	perl-libwww \
	perl-lingua-en-numbers-ordinate \
	perl-lingua-preferred \
	perl-list-moreutils \
	perl-module-build \
	perl-module-pluggable \
	perl-net-ssleay \
	perl-parse-recdescent \
	perl-path-class \
	perl-scalar-list-utils \
	perl-term-progressbar \
	perl-term-readkey \
	perl-test-exception \
	perl-test-requires \
	perl-timedate \
	perl-try-tiny \
	perl-unicode-string \
	perl-xml-libxml \
	perl-xml-libxslt \
	perl-xml-parser \
	perl-xml-sax \
	perl-xml-treepp \
	perl-xml-twig \
	perl-xml-writer \
	python \
	tar \
	uriparser \
	wget \
	zlib && \

# install perl modules for xmltv
 curl -L http://cpanmin.us | perl - App::cpanminus && \
 cpanm --installdeps /tmp/patches && \

# build dvb-apps
 hg clone http://linuxtv.org/hg/dvb-apps /tmp/dvb-apps && \
 cd /tmp/dvb-apps && \
 make -C lib && \
 make -C lib install && \

# build tvheadend
 git clone https://github.com/tvheadend/tvheadend.git /tmp/tvheadend && \
 cd /tmp/tvheadend && \
 git checkout "${TVH_VER}" && \
 ./configure \
#	--enable-qsv \
	--enable-dvbcsa \
	--enable-hdhomerun_client \
	--enable-libav \
	--infodir=/usr/share/info \
	--localstatedir=/var \
	--mandir=/usr/share/man \
	--prefix=/usr \
	--sysconfdir=/config && \
 make && \
 make install && \

# build XMLTV
 curl -o /tmp/xmtltv-src.tar.bz2 -L \
	"http://kent.dl.sourceforge.net/project/xmltv/xmltv/${XMLTV_VER}/xmltv-${XMLTV_VER}.tar.bz2" && \
 tar xf /tmp/xmtltv-src.tar.bz2 -C \
	/tmp --strip-components=1 && \
 cd "/tmp/xmltv-${XMLTV_VER}" && \
 /bin/echo -e "yes" | perl Makefile.PL PREFIX=/usr/ INSTALLDIRS=vendor && \
 make && \
 make test && \
 make install && \

# build argtable2
 ARGTABLE_VER1="${ARGTABLE_VER//./-}" && \
 mkdir -p \
	/tmp/argtable && \
 curl -o \
 /tmp/argtable-src.tar.gz -L \
	"https://sourceforge.net/projects/argtable/files/argtable/argtable-${ARGTABLE_VER}/argtable${ARGTABLE_VER1}.tar.gz" && \
 tar xf /tmp/argtable-src.tar.gz -C \
	/tmp/argtable --strip-components=1 && \
 cd /tmp/argtable && \
 ./configure \
	--prefix=/usr && \
 make && \
 make check && \
 make install && \

# build comskip
 git clone git://github.com/erikkaashoek/Comskip /tmp/comskip && \
 cd /tmp/comskip && \
 ./autogen.sh && \
 ./configure \
	--bindir=/usr/bin \
	--sysconfdir=/config/comskip && \
 make && \
 make install && \

# install runtime packages
 apk add --no-cache \
	ffmpeg \
	ffmpeg-libs \
	libhdhomerun-libs \
	libdvbcsa \
#	libva \
#	libva-intel-driver \
	libxml2 \
	libxslt && \
 apk add --no-cache \
	--repository http://nl.alpinelinux.org/alpine/edge/testing \
	gnu-libiconv && \

# cleanup
 apk del --purge \
	build-dependencies && \
 rm -rf \
	/config/.cpanm \
	/tmp/*

# copy local files
COPY root/ /

# install dependencies for epg2xml
RUN apk add --no-cache py-requests py-lxml py-pip && \
	pip install --upgrade pip && \
	pip install beautifulsoup4 && \

# download epg2xml
 mkdir /epg2xml
ADD "https://raw.githubusercontent.com/wonipapa/epg2xml/release-${EPG2XML_VER}/Channel.json" /epg2xml/
ADD "https://raw.githubusercontent.com/wonipapa/epg2xml/release-${EPG2XML_VER}/epg2xml.py" /epg2xml/
ADD "https://raw.githubusercontent.com/wonipapa/epg2xml/release-${EPG2XML_VER}/epg2xml.json" /epg2xml/

# set permissions on tv_grab_files
RUN chmod 555 /usr/bin/tv_grab_kr_*

# add picons
#ADD picons.tar.bz2 /picons

# ports and volumes
EXPOSE 9981 9982
VOLUME /config /recordings
