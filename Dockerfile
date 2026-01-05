FROM n8nio/n8n:latest

USER root

# --- STEP 1: Auto-Detect and Install APK ---
RUN wget -qO- https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/x86_64/ \
    | grep -o 'href="apk-tools-static-[^"]*"' \
    | sed 's/href="//;s/"//' \
    | head -n 1 \
    | xargs -I {} wget -q "https://dl-cdn.alpinelinux.org/alpine/latest-stable/main/x86_64/{}" \
    && tar -xzf apk-tools-static-*.apk -C / \
    && rm apk-tools-static-*.apk \
    && mv /sbin/apk.static /sbin/apk

# --- STEP 2: Install System Dependencies ---
RUN /sbin/apk add --no-cache --initdb --repository=http://dl-cdn.alpinelinux.org/alpine/latest-stable/main \
    bash \
    ffmpeg \
    fontconfig \
    python3 \
    py3-pip \
    font-noto \
    shadow \
    wget \
    imagemagick

# --- STEP 3: Final Permissions ---
RUN mkdir -p /tmp_media && \
    chown -R node:node /tmp_media && \
    chmod 777 /tmp_media

# Switch back to n8n user
USER node
