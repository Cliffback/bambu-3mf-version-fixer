FROM nginx:alpine

LABEL maintainer="bambu-3mf-version-fixer"
LABEL description="Static web server for Bambu 3MF Version Fixer"

COPY src/ /usr/share/nginx/html/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
