FROM debian:stable-slim AS builder

COPY etlegacy*.tar.gz /legacy/server/

RUN mkdir -p /legacy/homepath \
    && cd /legacy/server \
    && tar zxvf etlegacy*.tar.gz --strip-components=1 \
    && rm etlegacy*.tar.gz \
    && arch=$(arch) \
    && rm etl.$arch etl_bot.$arch.sh *.so \
    && mv etlded.$arch etlded \
    && mv etlded_bot.$arch.sh etlded_bot.sh

FROM debian:stable-slim

RUN useradd -Ms /bin/bash legacy \
    && mkdir -p /legacy/homepath \
    && chown -R legacy:legacy /legacy \
    && chmod -R 775 /legacy/homepath

COPY --from=builder --chown=legacy:legacy /legacy /legacy/

WORKDIR /legacy/server

VOLUME /legacy/homepath
VOLUME /legacy/server/etmain

EXPOSE 27960/UDP

USER legacy

ENTRYPOINT ["./etlded", "+set", "fs_homepath", "/legacy/homepath", "+set", "g_protect", "1", "+exec", "etl_server.cfg"]
