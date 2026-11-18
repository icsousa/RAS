# Medições da Fase 2 (PL3-G7)

Scripts para medir os dois RNF **antes** (base) e **depois** (final) da refatoração, nas mesmas condições.

| Ficheiro | Para quê |
| --- | --- |
| `medir.py` | Medições oficiais contra a stack em Docker: RNF-01 (M1–M4) e RNF-02 (E1–E5) |
| `docker-compose.medicoes.yaml` | Override para M3: limita a 2 GB a memória do api_gateway, do projects e do img_storage |
| `upload_rss.js`, `fila.py` | Medições exploratórias da análise (sem Docker) |
| `resultados/<etiqueta>/` | Resultados em JSON/CSV, criados pelo `medir.py` |

Precisa de: Docker com a stack a correr, `python3` (só biblioteca padrão), `curl` e `ffmpeg`.

## Registar o ambiente

Antes de medir, anotem no relatório: modelo do portátil, CPU e núcleos, RAM, sistema operativo, versão do Docker e recursos dados ao Docker Desktop (CPUs e memória). A base e a final têm de ser feitas **no mesmo portátil, com a mesma configuração**, sem outras aplicações pesadas abertas.

## 1. Medição de base (código original, antes de aplicar a refatoração)

```sh
cd pictuRAS/fase2/picturas-27
git log -1 --format=%H            # anotar o commit
docker compose down -v --remove-orphans
docker compose up -d --build      # esperar ~2 min até tudo arrancar

python3 ../medicoes/medir.py videos                        # 1x: gera os vídeos de teste (~5 min)
python3 ../medicoes/medir.py upload       --etiqueta base  # M1, M2, M4 (~15 min)
python3 ../medicoes/medir.py elasticidade --etiqueta base  # E1–E5 (~20–40 min)

# M3, com a memória dos serviços limitada a 2 GB
docker compose -f docker-compose.yaml -f ../medicoes/docker-compose.medicoes.yaml up -d
python3 ../medicoes/medir.py concorrencia --etiqueta base
```

M5 (progresso visível) é manual: carregar um vídeo de 500 MB no browser e registar se aparece progresso.

## 2. Medição final (depois da refatoração)

Os mesmos comandos, com `--etiqueta final`, depois de reconstruir:

```sh
docker compose down -v --remove-orphans
docker compose up -d --build
# … os mesmos quatro comandos com --etiqueta final
```

## O que cada medição faz

- **M1 (pico de RAM)**: antes de cada carregamento reinicia os três serviços e lê `memory.peak` do cgroup de cada contentor; M1 é a soma dos picos acima do repouso. Se o cgroup não tiver `memory.peak`, usa o máximo do `docker stats` (≈1 amostra/s) e indica-o no JSON.
- **M2 (tempo)**: `time_total` do `curl`, do início do POST até à resposta.
- **M3 (concorrência)**: 1, 2, 4 e 8 carregamentos de 1 GB em paralelo; M3 é o maior nível em que todos terminam com sucesso.
- **M4 (rejeição)**: 300 MB enviados por um utilizador free (limite 100 MB); regista quantos bytes o servidor aceitou antes de recusar (`size_upload` do curl).
- **E1–E5 (elasticidade)**: prepara 20 projetos com um vídeo de 60 s e brilho, injeta os 20 processamentos de uma vez e pede 10 pré-visualizações (uma a cada 5 s). Lê a API de gestão do RabbitMQ a cada segundo (mensagens e consumidores das filas `video*`) e os logs dos workers (`[video] msg=…`).
  - E1: tempo até aparecer mais de um consumidor na fila de processamento.
  - E2: tempo, depois de a fila esvaziar, até voltar ao mínimo.
  - E3: vídeos processados por minuto.
  - E4: espera de cada pré-visualização até um worker a começar (percentil 95).
  - E5: `docker stats` dos contentores de vídeo no fim.

As esperas de E4 emparelham pedidos e inícios pela ordem; com uma fila dedicada às pré-visualizações a ordem é a mesma.

Escrito com apoio de IA (Claude) e revisto pelo grupo.
