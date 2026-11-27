#import "../template.typ": *

#set heading(numbering: "A.1.")
#counter(heading).update(0)

= Instruções de execução

#orientacao[
  Indiquem os passos mínimos para lançar a solução a partir do repositório (pré-requisitos, comandos, projeto de teste) e
  para repetir as medições (antes e depois do _refactoring_) (_scripts_, dados, ambiente). Quem avalia, ou a equipa na fase seguinte, deve
  conseguir repetir o que descrevem sem ajuda. No glossário, definam os termos específicos do projeto ou da disciplina
  usados no relatório.
]

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

Para a base, fazer _checkout_ de `406c8e0` (código original de `052310226c51fa57a17101c7bd1ad795674aac95` com os _scripts_ de medição); para a final, de `aba322d` (inclui `5b2af25`, DA-1, e `3b8a8bd`, DA-2). Os resultados estão nos _commits_ `17a8fae` e `83c7dae`; as correções aos _scripts_ (`45e4c87`, `78843bd`, `6e553e9`) aplicam-se por igual à base e à final. A M5 é manual: carregar um vídeo de 500 MB no _browser_ e anotar se aparece progresso. Projeto de teste para os testes manuais: vídeos em `picturas-27/samples/` (por exemplo `speech_mandela_177s_1080p.webm`, `too_long_90s.mp4`, `corrupted.mp4`).

*Ficheiros de resultados* (em `medicoes/resultados/`, com `base/` e `final/`):

- `base/ambiente.txt`: _hardware_, SO e versões do Docker.
- `rnf01_upload.json` (M1, M2, M4), `rnf01_concorrencia.json` (M3), `rnf01_m5.json` (M5, manual) e `final/rnf01_m1_anon.json` (M1 separada em memória dos processos e cache de página).
- `rnf02_elasticidade.json` e `rnf02_linha_tempo.csv` (E1 a E5 e linha temporal das filas), `base/rnf02_e3_recalculado.json` (E3 da base sem pré-visualizações), `final/rnf02_autoscaler.log` e `final/rnf02_replicas_video_tool.txt` (decisões do _autoscaler_ e réplicas ao longo do ensaio).

*Testes de regressão.*

```sh
docker compose exec projects node --test
python3 -m unittest discover -s Tools/autoscaler/tests -v
cd Tools/video && python3 -m venv .venv \
  && .venv/bin/pip install -r requirements-dev.txt \
  && .venv/bin/python -m pytest -q tests
```

*Diagramas* (em `pictuRAS/fase2/src-relatorio-fase2/diagramas`): `plantuml -tpng -Sdpi=200 arquitetura_global.puml`; `dot -Tpng -Gdpi=200 vista_antes.dot -o ../images/vista_antes.png` (idem para `vista_depois.dot`); `typst compile --format png --ppi 220 sequencia_pedido.typ ../images/sequencia_pedido.png`. Relatório: `typst compile --font-path fonts main.typ`.

= Glossário

#tabela(
  colunas: (4cm, 1fr),
  [Termo], [Definição],
  [Cenário de qualidade (QS)], [Descrição verificável de um requisito de qualidade com seis elementos: fonte do estímulo, estímulo, artefacto, ambiente, resposta e medida da resposta.],
  [Evidência (EV)], [Referência verificável (código, configuração, mensagem, medição ou documento) que sustenta uma afirmação sobre o sistema atual.],
  [Hipótese (H)], [Afirmação sem evidência, com indicação de como a confirmar ou refutar.],
  [Tática (TAT)], [Decisão de desenho que influencia a resposta a um estímulo de um atributo de qualidade (Bass, Clements e Kazman).],
  [Decisão arquitetural (DA)], [Registo, ao estilo ADR, da tática escolhida, alternativas, consequências e implementação.],
  [_Baseline_], [Medição da solução de partida, feita antes do _refactoring_ com o mesmo método da medição final.],
  [Elasticidade], [Capacidade de ajustar automaticamente os recursos à carga, para cima e para baixo.],
  [_Autoscaler_], [Serviço que lê a profundidade de uma fila e cria ou remove réplicas de um _worker_.],
  [Bloqueio na cabeça da fila], [Situação em que um pedido curto espera por pedidos longos que estão à sua frente na mesma fila.],
  [Consumidores concorrentes], [Padrão em que vários _workers_ consomem a mesma fila e dividem o trabalho.],
  [_Streaming_], [Transferir um ficheiro em blocos à medida que chega, sem o guardar inteiro em memória.],
  [Cache de página], [Memória usada pelo _kernel_ para guardar dados de ficheiros lidos ou escritos; é contabilizada no _cgroup_ mas pode ser libertada.],
  [OOM], [_Out of memory_: o _kernel_ termina processos quando a memória se esgota.],
  [p95], [Percentil 95: valor abaixo do qual ficam 95 % das observações.],
  [Pré-visualização], [Processamento dos primeiros 3 s de um vídeo para mostrar o efeito antes do processamento completo.],
)
