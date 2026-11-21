FROM python:3.12-alpine

RUN apk add --no-cache font-dejavu \
 && pip install --no-cache-dir Pillow

WORKDIR /app
COPY renderer.py config.json ./

CMD ["python3", "/app/renderer.py"]
