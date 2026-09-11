FROM debian:12-slim

ENV DEBIAN_FRONTEND=noninteractive \
    DISPLAY=:99 \
    HOME=/home/browser

RUN apt-get update && apt-get install -y --no-install-recommends \
      chromium \
      xvfb \
      x11vnc \
      novnc \
      websockify \
      supervisor \
      socat \
      ca-certificates \
      fonts-liberation \
      fonts-noto-color-emoji \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --home-dir /home/browser --shell /usr/sbin/nologin browser \
    && mkdir -p /home/browser/profile /var/log/supervisor \
    && chown -R browser:browser /home/browser

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

USER browser
WORKDIR /home/browser
EXPOSE 5900 6080 9222
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf", "-n"]
