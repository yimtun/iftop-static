FROM scratch
ARG TARGETARCH
COPY --chmod=0755 iftop-linux-${TARGETARCH} /usr/bin/iftop
COPY terminfo /usr/share/terminfo
ENV TERMINFO=/usr/share/terminfo
ENTRYPOINT ["/usr/bin/iftop"]
