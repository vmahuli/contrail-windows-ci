FROM python:3.6.5

EXPOSE 8080

WORKDIR C:/
RUN echo "Hello, Contrail!" > index.html
ENTRYPOINT python -m http.server 8080
