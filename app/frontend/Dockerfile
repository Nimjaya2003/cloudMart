FROM nginxinc/nginx-unprivileged:1.27-alpine
ARG GIT_SHA=dev
COPY index.html config.js /usr/share/nginx/html/
USER root
RUN echo "window.APP_VERSION = '${GIT_SHA}';" > /usr/share/nginx/html/version.js
USER 101
EXPOSE 8080