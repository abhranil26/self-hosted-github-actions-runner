FROM ghcr.io/actions/actions-runner:latest

# Place scripts OUTSIDE /home/runner because that directory is mounted as a
# CapRover persistent volume — files COPY'd into it are overlaid by the volume
# on subsequent boots, so image updates to entrypoint.sh / watchdog.sh would
# never propagate to a running container otherwise.
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY watchdog.sh /usr/local/bin/watchdog.sh
USER root
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/watchdog.sh
USER runner

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
