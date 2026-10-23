FROM python:3.11-slim

# FFmpeg (com libass e libx264) e fontes Unicode para a fonte de recurso das legendas
# (REQ-VID-TXT-005): Noto cobre latim, grego, cirílico; Noto CJK cobre chinês/japonês/coreano.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg fontconfig fonts-noto-core fonts-noto-cjk fonts-dejavu-core fonts-liberation \
    && rm -rf /var/lib/apt/lists/* \
    && fc-cache -f

WORKDIR /app

COPY ./video/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY ./video .

CMD ["python", "-u", "video.py"]
