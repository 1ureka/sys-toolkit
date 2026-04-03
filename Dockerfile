FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    p7zip-full \
    ffmpeg \
    imagemagick \
    python3 \
    python3-pip \
    && pip3 install --break-system-packages yt-dlp \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /entrypoint.sh
COPY scripts/ /scripts/
RUN chmod +x /entrypoint.sh /scripts/*.sh

WORKDIR /data
ENTRYPOINT ["/entrypoint.sh"]
