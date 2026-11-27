#import "../template.typ": *

= Utilização de IA

== Ferramentas, modelos e configuração

#tabela(
  colunas: (4.2cm, 1fr),
  [Ferramenta / modelo], [Configuração e utilização (skills, instruções de projeto, MCP, …)],
  [Claude Code (Claude Opus 5.5, Anthropic)], [Num terminal com acesso ao repositório e ao Docker local do portátil de medição, e em sessões na cloud ligadas ao repositório `icsousa/RAS`. Instruções de projeto em `pictuRAS/fase2/CLAUDE.md` (ordem de trabalho, regras de refatoração, fins de linha, marcação do código) e o `AGENTS.md` da base. Sem _skills_ nem servidores MCP próprios.],
  [Marcação no código e nos commits], [O código escrito com IA tem o comentário «Written with AI assistance (Claude) and reviewed by the group (PL3-G7)»; os commits gerados têm a linha `Co-Authored-By: Claude`.],
)

== Tarefas apoiadas e validação

#tab([Tarefas apoiadas por IA e validação],
  tabela(
    colunas: (2.4cm, 2.4cm, 1fr, 1fr, 1fr),
    tamanho: 8.5pt,
    [Ferramenta / modelo / skill], [Tarefa apoiada (capítulo)], [O que foi aceite], [O que foi rejeitado e porquê], [Como foi validado pela equipa],
    [Claude Code], [Diagnóstico e escolha dos RNF (cap. 2 a 6)], [Referências ao código, medições exploratórias (EV-18, EV-19), proposta de métricas e alternativas (`analise-rnf.typ`)], [A recomendação de prioridade numa fila única (`x-max-priority`) foi preterida pela fila separada (TAT-09), mais simples de medir], [O grupo escolheu os dois RNF, os alvos e os mínimos e as alternativas; as referências ao código foram conferidas no repositório],
    [Claude Code], [Scripts de medição (cap. 10)], [`medir.py`, override do M3], [Versões iniciais dos scripts, com os problemas corrigidos em `45e4c87`, `78843bd` e `6e553e9`], [Execução acompanhada por um membro do grupo; resultados incoerentes analisados; correções aplicadas por igual à base e à final],
    [Claude Code], [Refatoração DA-1 e DA-2 (cap. 8)], [Patches `5b2af25` e `3b8a8bd` com os testes novos], [—], [Leitura dos _diffs_ antes de aplicar; testes automáticos nos contentores; testes manuais TM-01 a TM-08; confirmação de que mensagens de erro e códigos HTTP não mudaram],
    [Claude Code], [Correção do progresso na criação de projeto (cap. 8)], [Commit `aba322d`], [O patch inicial, que só cobria o diálogo Import], [Defeito detetado pelo grupo no TM-02; reteste no browser],
    [Claude Code], [Investigação de anomalias (cap. 10)], [Identificação do OOM no `journalctl`, dos 504 nos logs do nginx, da cache de pré-visualizações e da cache de página na M1], [—], [Evidência descrita no capítulo 10; a separação `anon`/`file` na M1 foi proposta pelo agente e não foi revista pelo grupo em detalhe],
    [Claude Code], [Relatório (todos os capítulos) e diagramas (cap. 2 e 9)], [Rascunho, passagem para o template oficial da Fase 2, diagramas em Graphviz e Typst], [Afirmações sem evidência foram marcadas como hipóteses (H-01 a H-03) em vez de factos], [Números conferidos com os JSON de `medicoes/resultados/`; diagramas conferidos com o `docker-compose.yaml`; texto revisto pelo grupo],
  ),
)

== Análise crítica

A IA foi mais útil nas tarefas com verificação objetiva (testes, medições repetíveis, leitura de código), e menos fiável onde a verificação dependia de observação manual. Erros detetados durante o trabalho:

- *Barra de progresso incompleta.* O patch inicial do RNF-01 não ligava a barra de progresso à criação de projeto. Detetado pelo grupo no teste manual TM-02.
- *Scripts de medição.* Os scripts iniciais tinham problemas (nginx com IP antigo, resultados perdidos no OOM, logs de réplicas apagadas, pré-visualizações em cache). Detetados ao analisar resultados incoerentes; a primeira medição final da elasticidade foi descartada.
- *Desvio na configuração.* A análise previa réplicas com limite de CPU, mas o `docker-compose.yaml` gerado não o define (desvio da DA-2). Só foi identificado ao explicar o E3; o agente propôs três caminhos (justificar pelo hardware, limitar o CPU com `cpus: 1`, rever os alvos) e o grupo optou por não alterar nem o código nem os alvos depois de medir.

Práticas adotadas: rever todos os _diffs_ antes de aplicar, exigir testes para cada alteração, conferir os números do relatório com os ficheiros de resultados e decidir em grupo tudo o que envolvesse escolhas (que RNF, que alvos, que alternativas). O grupo é responsável por todo o conteúdo entregue.
