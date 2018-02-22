FROM eugenmayer/unison:unox

# Add community repos.
RUN echo "http://dl-2.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories; \
	echo "http://dl-3.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories; \
	echo "http://dl-4.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories; \
	echo "http://dl-5.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories

# Install packages.
RUN apk add --no-cache \
	tini \
	unison \
	sudo \
	ruby

RUN set -xe \
	&& addgroup -g 82 -S www-data \
	&& addgroup -S sudo \
	&& adduser -u 82 -D -S -G www-data www-data \
	&& echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
	&& adduser www-data sudo \
	&& echo "PS1='\w\$ '" >> /home/www-data/.bashrc;

COPY docker-entrypoint.sh /docker-entrypoint.sh

ENV UNISON_DIR=/unison

USER root
RUN set -xe \
	&& mkdir -p /volume \
	&& mkdir -p /host

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD [ \
	"unison", "/host", "/volume", \
	"-auto", \
	"-batch", \
	"-repeat", "watch", \
	"-copyonconflict", \
	"-prefer", "newer" \
]
