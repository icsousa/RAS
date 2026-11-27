# CLAUDE.md — RAS 2026/27, Fase 2 (grupo PL3-G7)

Este repositório (`icsousa/RAS`) tem o projeto PictuRAS de Requisitos e Arquitetura de Software. Estamos na **Fase 2: refatoração para dois requisitos não funcionais (RNF)**. Entrega a **20 de novembro de 2026**; defesas de 23 a 27 de novembro.

Responde em português de Portugal. Código, comentários e mensagens de commit em inglês (convenção do `AGENTS.md` da base).

## Onde está o quê

| Caminho | Conteúdo |
| --- | --- |
| `pictuRAS/fase2/picturas-27/` | Código base (solução PL1-G4). Lê o `AGENTS.md` desta pasta antes de mexer no código |
| `pictuRAS/fase2/fase-2-guidelines.pdf` | Diretrizes da Fase 2 |
| `pictuRAS/fase2/src-relatorio-fase2/` | Relatório da Fase 2 (template oficial). Compilar nesta pasta com `typst compile --font-path fonts main.typ relatorio-fase2.pdf` |
| `pictuRAS/fase2/medicoes/` | `medir.py` (medições oficiais em Docker), `README.md`, override para o M3, scripts exploratórios |
| `pictuRAS/fase2/medicoes/resultados/<etiqueta>/` | Resultados JSON/CSV (`base` e `final`) |

Commit oficial de partida (para o relatório): `052310226c51fa57a17101c7bd1ad795674aac95`.

## Os dois RNF (ISO/IEC 25010, eficiência de desempenho)

- **RNF-01 Carregamento de ficheiros grandes.** Antes, um vídeo até 1 GB ficava inteiro em memória no apiGateway, no projects e no imageStorageService. A refatoração faz streaming em todos os saltos:
  - nginx com `proxy_request_buffering off`;
  - o gateway faz pipe do pedido;
  - o projects grava num ficheiro temporário com o multer `diskStorage` e valida o limite antes e durante a leitura;
  - o S3 recebe em multipart;
  - o frontend mostra o progresso.
  - Métricas: M1 (pico de RAM), M2 (tempo), M3 (uploads de 1 GB em simultâneo), M4 (bytes lidos antes de recusar), M5 (progresso visível).
- **RNF-02 Elasticidade do processamento de vídeo.** Antes, um único `video_tool` processava um vídeo de cada vez e as pré-visualizações esperavam na mesma fila. A refatoração:
  - cria a fila `video_preview_queue` com o worker `video_preview_tool`;
  - acrescenta o serviço `video_autoscaler` (`Tools/autoscaler`), que mantém 1 a 4 réplicas consoante a fila;
  - põe o worker a processar numa thread com heartbeat e a sair limpo com SIGTERM.
  - Métricas: E1 (tempo de expansão), E2 (tempo de contração), E3 (vídeos/min), E4 (espera da pré-visualização, p95), E5 (recursos em repouso).

## Ordem de trabalho (não trocar)

A medição de base tem de ser feita no código original, **antes** de aplicar os patches 0002 e 0003. Nunca alteres código em `picturas-27/` antes de a base estar medida e guardada.

1. **Branch e scripts**
   ```sh
   git checkout main && git pull
   git checkout -b fase2/refatoracao
   git am --keep-cr <pasta-do-zip>/0001-*.patch
   ```
2. **Registar o ambiente** (vai para o relatório): portátil, CPU/núcleos, RAM, SO, `docker version`, CPUs e memória do Docker Desktop. A base e a final são no mesmo portátil com a mesma configuração.
3. **Medição de base** (cerca de 1 h)
   ```sh
   cd pictuRAS/fase2/picturas-27
   git log -1 --format=%H
   docker compose down -v --remove-orphans
   docker compose up -d --build      # esperar ~2 min
   python3 ../medicoes/medir.py videos
   python3 ../medicoes/medir.py upload       --etiqueta base
   python3 ../medicoes/medir.py elasticidade --etiqueta base
   docker compose -f docker-compose.yaml -f ../medicoes/docker-compose.medicoes.yaml up -d
   python3 ../medicoes/medir.py concorrencia --etiqueta base
   ```
   - M5 é manual: carregar um vídeo de 500 MB no browser e anotar se aparece progresso.
   - Fazer commit de `pictuRAS/fase2/medicoes/resultados/base/`.
4. **Aplicar a refatoração**
   ```sh
   cd <raiz do repo>
   git am --keep-cr <pasta-do-zip>/0002-*.patch <pasta-do-zip>/0003-*.patch
   ```
5. **Reconstruir e correr os testes de regressão**
   ```sh
   cd pictuRAS/fase2/picturas-27
   docker compose down -v --remove-orphans && docker compose up -d --build
   docker compose exec projects node --test                     # esperado: 20 pass
   python3 -m unittest discover -s Tools/autoscaler/tests -v     # esperado: 8 OK
   cd Tools/video && python3 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt \
     && .venv/bin/python -m pytest -q tests                     # todos a passar
   ```
   Teste manual no browser:
   - carregar um vídeo (deve aparecer a barra de progresso);
   - aplicar brilho, pré-visualizar e processar;
   - confirmar que o resultado aparece.
6. **Medição final**: os mesmos comandos do passo 3 com `--etiqueta final`, depois de `down -v` e `up -d --build`. Durante a elasticidade, observar `docker compose logs -f video_autoscaler` e `docker compose ps video_tool`.
7. **Commit e push** de `resultados/final/`; abrir PR de `fase2/refatoracao` para `main`.
8. **Relatório**:
   - tabelas base vs. final por métrica, comparadas com o alvo e o mínimo definidos nos capítulos do relatório (`src-relatorio-fase2/capitulos/`);
   - efeitos colaterais: segurança (`docker.sock`), disco temporário e mais serviços para manter;
   - utilização de IA;
   - commit de partida.

## Regras

- Refatoração apenas: nenhuma funcionalidade nova. Mensagens de erro e códigos HTTP do upload mantêm-se.
- Mantém os fins de linha de cada ficheiro (`rabbitMQ/definitions.json` é CRLF); `git am` com `--keep-cr`.
- Nunca fazer commit de `.env`, `node_modules`, vídeos gerados (`medicoes/videos/` está no `.gitignore`), `__pycache__` ou `backups/`.
- Commits pequenos, assunto com menos de 72 caracteres.
- Código escrito com IA fica marcado em comentário ("Written with AI assistance (Claude) and reviewed by the group (PL3-G7)") e é referido no relatório.

## Se algo falhar

- **`medir.py` dá 401/404 no registo:** a stack ainda está a arrancar. Esperar e repetir; confirmar `https://localhost:8080` no browser.
- **`memory.peak` não existe:** o script usa o `docker stats` e indica-o no JSON (campo `fonte`). Referir isso no relatório.
- **O autoscaler não cria réplicas:**
  - ver `docker compose logs video_autoscaler`;
  - no Docker Desktop, confirmar que `/var/run/docker.sock` existe (Settings → Advanced → "Allow the default Docker socket to be used").
- **Uploads falham depois da refatoração:** ver `docker compose logs api_gateway projects img_storage`. Confirmar que o nginx foi reconstruído com `proxy_request_buffering off`.
- **A stack da Fase 1 interfere:** `docker compose down -v --remove-orphans` na pasta antiga.
- **Mudanças nos números ou alvos:** atualizar também os capítulos do relatório em `src-relatorio-fase2/capitulos/` e recompilar nessa pasta com `typst compile --font-path fonts main.typ relatorio-fase2.pdf`.
