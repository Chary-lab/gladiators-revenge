FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates wget unzip \
        libfontconfig1 libfreetype6 libx11-6 libxcursor1 libxinerama1 \
        libxi6 libxrandr2 libgl1 libasound2t64 libpulse0 \
    && rm -rf /var/lib/apt/lists/*

ARG GODOT_VERSION=4.7.2
RUN wget -q \
        "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
        -O /tmp/godot.zip \
    && unzip -q /tmp/godot.zip -d /tmp \
    && mv "/tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm -f /tmp/godot.zip

WORKDIR /app
COPY . .

ENV PORT=9080
EXPOSE 9080

CMD ["sh", "-c", "exec godot --headless --path /app -- --servidor --puerto=${PORT:-9080}"]
