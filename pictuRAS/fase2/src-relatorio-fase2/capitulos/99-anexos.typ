#import "../template.typ": *

#set heading(numbering: "A.1.")
#counter(heading).update(0)

= Instruções de execução

*Pré-requisitos.* Docker com Compose, Python 3, `curl` e `ffmpeg`. Os comandos correm em `pictuRAS/fase2/picturas-27`.

*Lançar a solução e repetir as medições.*

```sh
docker compose down -v --remove-orphans
docker compose up -d --build          # esperar ~2 min
python3 ../medicoes/medir.py videos   # gera os vídeos de teste
python3 ../medicoes/medir.py upload       --etiqueta <base|final>
python3 ../medicoes/medir.py elasticidade --etiqueta <base|final>
docker compose -f docker-compose.yaml -f ../medicoes/docker-compose.medicoes.yaml up -d
python3 ../medicoes/medir.py concorrencia --etiqueta <base|final>
```

Para a base, fazer _checkout_ de `406c8e0`; para a final, de `aba322d`. A M5 é manual: carregar um vídeo de 500 MB no browser e anotar se aparece progresso. Projeto de teste para os testes manuais: vídeos em `picturas-27/samples/` (por exemplo `speech_mandela_177s_1080p.webm`, `too_long_90s.mp4`, `corrupted.mp4`).

*Testes de regressão.*

```sh
docker compose exec projects node --test
python3 -m unittest discover -s Tools/autoscaler/tests -v
cd Tools/video && python3 -m venv .venv \
  && .venv/bin/pip install -r requirements-dev.txt \
  && .venv/bin/python -m pytest -q tests
```

*Diagramas.* `cd pictuRAS/fase2/src-relatorio-fase2/diagramas && for f in *.dot; do dot -Tpng -Gdpi=200 $f -o ../images/${f%.dot}.png; done`

#tab([Commits de referência],
  tabela(
    colunas: (3.6cm, 4.4cm, 1fr),
    [Papel], [Commit], [Notas],
    [Ponto de partida oficial], [`052310226c51fa57a17101c7bd1ad795674aac95`], [`picturas-um/picturas-27` (solução PL1-G4 integrada)],
    [Medição de base], [`406c8e0`], [Código original e scripts de medição],
    [Refatoração], [`5b2af25` (DA-1), `3b8a8bd` (DA-2), `aba322d`], [`aba322d`: barra de progresso também na criação de projeto],
    [Medição final], [`aba322d`], [Resultados em `17a8fae` e `83c7dae`],
    [Correções aos scripts], [`45e4c87`, `78843bd`, `6e553e9`], [Secção 10.4; aplicam-se por igual à base e à final],
  ),
)

#tab([Ficheiros de resultados],
  tabela(
    colunas: (6.5cm, 1fr),
    [Ficheiro (em `medicoes/`)], [Conteúdo],
    [`resultados/base/ambiente.txt`], [Hardware, SO e versões do Docker],
    [`resultados/*/rnf01_upload.json`], [M1, M2 e M4],
    [`resultados/*/rnf01_concorrencia.json`], [M3],
    [`resultados/*/rnf01_m5.json`], [M5 (manual)],
    [`resultados/final/rnf01_m1_anon.json`], [M1 separada em memória dos processos e cache de página],
    [`resultados/*/rnf02_elasticidade.json`, `rnf02_linha_tempo.csv`], [E1 a E5 e linha temporal das filas],
    [`resultados/base/rnf02_e3_recalculado.json`], [E3 da base sem pré-visualizações],
    [`resultados/final/rnf02_autoscaler.log`, `rnf02_replicas_video_tool.txt`], [Decisões do _autoscaler_ e réplicas ao longo do ensaio],
  ),
)

= Glossário

#tabela(
  colunas: (4.2cm, 1fr),
  [Termo], [Definição],
  [Cenário de qualidade (QS)], [Descrição verificável de um requisito de qualidade com seis elementos: fonte do estímulo, estímulo, artefacto, ambiente, resposta e medida da resposta.],
  [Evidência (EV)], [Referência verificável (código, configuração, mensagem, medição ou documento) que sustenta uma afirmação sobre o sistema atual.],
  [Hipótese (H)], [Afirmação sem evidência, com indicação de como a confirmar ou refutar.],
  [Tática (TAT)], [Decisão de desenho que influencia a resposta a um estímulo de um atributo de qualidade (Bass, Clements e Kazman).],
  [Decisão arquitetural (DA)], [Registo ao estilo ADR da tática escolhida, alternativas, consequências e implementação.],
  [Baseline], [Medição da solução de partida, feita antes da refatoração com o mesmo método da medição final.],
  [Elasticidade], [Capacidade de ajustar automaticamente os recursos à carga, para cima e para baixo.],
  [_Autoscaler_], [Serviço que lê a profundidade de uma fila e cria ou remove réplicas de um worker.],
  [Bloqueio na cabeça da fila], [Situação em que um pedido curto espera por pedidos longos que estão à sua frente na mesma fila.],
  [Consumidores concorrentes], [Padrão em que vários workers consomem a mesma fila e dividem o trabalho.],
  [_Streaming_], [Transferir um ficheiro em blocos à medida que chega, sem o guardar inteiro em memória.],
  [Cache de página], [Memória usada pelo kernel para guardar dados de ficheiros lidos ou escritos; é contabilizada no cgroup mas pode ser libertada.],
  [OOM], [_Out of memory_: o kernel termina processos quando a memória se esgota.],
  [p95], [Percentil 95: valor abaixo do qual ficam 95 % das observações.],
  [Pré-visualização], [Processamento dos primeiros 3 s de um vídeo para mostrar o efeito antes do processamento completo.],
)
