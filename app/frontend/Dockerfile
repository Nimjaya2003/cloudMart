FROM nginxinc/nginx-unprivileged:1.27-alpine
ARG GIT_SHA=dev
COPY index.html /usr/share/nginx/html/
USER root
RUN echo "window.APP_VERSION = '${GIT_SHA}';" > /usr/share/nginx/html/version.js
COPY chat-widget.js chat-widget.css /usr/share/nginx/html/

COPY chat-proxy.conf /etc/nginx/conf.d/default.conf
USER 101
EXPOSE 8080