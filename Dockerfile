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

# Importar una vez dentro de la imagen: sin .godot/ el registro de class_name
# queda vacío y los scripts no compilan (el servidor no llegaba a abrir el
# puerto y Fly avisaba "not listening on the expected address").
RUN godot --headless --path /app --import     && test -f /app/.godot/global_script_class_cache.cfg

# El maestro escucha en PORT y levanta una sala (proceso Godot) por cada SALAS.
# Necesita SUPABASE_SERVICE_KEY para que las salas se anuncien en el lobby.
ENV PORT=9080
ENV SALAS=2
EXPOSE 9080

CMD ["sh", "-c", "exec godot --headless --path /app -- --maestro --puerto=${PORT:-9080} --salas=${SALAS:-2}"]
