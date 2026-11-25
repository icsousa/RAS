#import "../template.typ": *

#set heading(numbering: "A.1")
#counter(heading).update(0)

= Repetir as medições e os testes

Pré-requisitos: Docker com Compose, Python 3, `curl` e `ffmpeg`. Todos os comandos correm em `pictuRAS/fase2/picturas-27`.

```sh
docker compose down -v --remove-orphans
docker compose up -d --build          # esperar ~2 min
python3 ../medicoes/medir.py videos
python3 ../medicoes/medir.py upload       --etiqueta <base|final>
python3 ../medicoes/medir.py elasticidade --etiqueta <base|final>
docker compose -f docker-compose.yaml -f ../medicoes/docker-compose.medicoes.yaml up -d
python3 ../medicoes/medir.py concorrencia --etiqueta <base|final>
```

Para a base, fazer _checkout_ de `406c8e0`; para a final, de `aba322d`. A M5 é manual: carregar um vídeo de 500 MB no browser e anotar se aparece progresso.

Testes de regressão:

```sh
docker compose exec projects node --test
python3 -m unittest discover -s Tools/autoscaler/tests -v
cd Tools/video && python3 -m venv .venv \
  && .venv/bin/pip install -r requirements-dev.txt \
  && .venv/bin/python -m pytest -q tests
```

= Ficheiros de resultados

#tabela(
  colunas: (6.5cm, 1fr),
  [Ficheiro], [Conteúdo],
  [`resultados/base/ambiente.txt`], [Hardware, SO e versões do Docker],
  [`resultados/*/rnf01_upload.json`], [M1, M2 e M4],
  [`resultados/*/rnf01_concorrencia.json`], [M3],
  [`resultados/*/rnf01_m5.json`], [M5 (manual)],
  [`resultados/final/rnf01_m1_anon.json`], [M1 separada em memória dos processos e cache de página],
  [`resultados/*/rnf02_elasticidade.json`, `rnf02_linha_tempo.csv`], [E1 a E5 e linha temporal das filas],
  [`resultados/base/rnf02_e3_recalculado.json`], [E3 da base sem pré-visualizações],
  [`resultados/final/rnf02_autoscaler.log`, `rnf02_replicas_video_tool.txt`], [Decisões do autoscaler e réplicas ao longo do ensaio],
)
