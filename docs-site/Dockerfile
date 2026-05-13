# Two-stage: build the static site with mkdocs-material, then serve with
# alpine nginx. Final image is ~25 MB; builder stage is discarded.
FROM python:3.12-alpine AS builder
WORKDIR /work
RUN pip install --no-cache-dir \
        mkdocs==1.6.1 \
        mkdocs-material==9.5.49

COPY mkdocs.yml ./
COPY docs ./docs
RUN mkdocs build --site-dir /site --strict

FROM nginx:alpine-slim
COPY --from=builder /site /usr/share/nginx/html
# Default nginx.conf serves /usr/share/nginx/html on :80 — no override needed.
EXPOSE 80
