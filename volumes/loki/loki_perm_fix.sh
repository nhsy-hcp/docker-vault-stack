#!/bin/sh
chown -R loki:loki /loki/data
/usr/bin/loki -config.file=/etc/loki/loki.yml
