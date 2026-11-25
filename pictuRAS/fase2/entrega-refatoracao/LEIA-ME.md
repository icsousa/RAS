# Refatoração da Fase 2 — como aplicar

Três commits, por esta ordem. A medição de base tem de ser feita entre o 1 e o 2.

| Patch | O que traz |
| --- | --- |
| 0001 | Scripts de medição em `fase2/medicoes/` e duas correções na análise |
| 0002 | RNF-01: upload em streaming e progresso no frontend |
| 0003 | RNF-02: fila de pré-visualizações, autoscaler e worker com heartbeat |

```sh
cd RAS                                  # o vosso clone, em main atualizado
git checkout -b fase2/refatoracao
git am --keep-cr 0001-*.patch
# --> medição de BASE: seguir fase2/medicoes/README.md, passo 1
git add pictuRAS/fase2/medicoes/resultados && git commit -m "Medição de base"
git am --keep-cr 0002-*.patch 0003-*.patch
# --> reconstruir e correr os testes (abaixo), depois a medição FINAL (passo 2)
git push -u origin fase2/refatoracao
```

## Testes de regressão

```sh
cd pictuRAS/fase2/picturas-27
docker compose down -v --remove-orphans && docker compose up -d --build
docker compose exec projects node --test                     # 20 testes
python3 -m unittest discover -s Tools/autoscaler/tests -v     # 8 testes
cd Tools/video && python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt \
  && .venv/bin/python -m pytest -q tests                     # inclui os 5 novos do worker
```

E à mão no browser: carregar um vídeo (aparece a barra de progresso), aplicar um efeito, pré-visualizar e processar.

Para ver o autoscaler: `docker compose logs -f video_autoscaler` e `docker compose ps video_tool` durante a medição de elasticidade.
