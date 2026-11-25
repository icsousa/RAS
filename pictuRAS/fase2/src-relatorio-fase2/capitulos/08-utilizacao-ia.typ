#import "../template.typ": *

= Utilização de IA

== Ferramentas e configuração

#tab([Ferramentas de IA],
  tabela-campos(
    [Ferramenta / modelo], [Claude Code (Claude Opus 5.5, Anthropic), num terminal com acesso ao repositório e ao Docker local.],
    [Configuração], [Instruções de projeto em `fase2/CLAUDE.md` (ordem de trabalho, regras de refatoração, fins de linha, marcação do código) e o `AGENTS.md` da base. Sem _skills_ nem servidores MCP próprios.],
    [Marcação no código], [O código escrito com IA tem o comentário "Written with AI assistance (Claude) and reviewed by the group (PL3-G7)"; os commits gerados têm a linha `Co-Authored-By: Claude`.],
  ),
)

== Tarefas apoiadas e validação

#tab([Tarefas apoiadas pela IA e validação feita pelo grupo],
  tabela(
    colunas: (3.2cm, 1fr, 1fr),
    [Tarefa], [Apoio da IA], [Validação pelo grupo],
    [Escolha e análise dos RNF], [Diagnóstico no código, medições exploratórias, proposta de métricas e alternativas (`analise-rnf.typ`).], [O grupo escolheu os dois RNF entre as ideias das diretrizes, decidiu os alvos e os mínimos e escolheu as alternativas A1 e B2 + B4; as referências ao código foram conferidas no repositório.],
    [Scripts de medição], [`medir.py` e o override do M3.], [As medições automáticas foram executadas pelo agente no portátil do grupo, acompanhadas por um membro do grupo; a M5 e os testes no browser foram feitos pelo grupo. Os resultados incoerentes levaram às três correções do Capítulo 7, que se aplicam por igual à base e à final.],
    [Refatoração RNF-01 e RNF-02], [Patches `5b2af25` e `3b8a8bd` com os testes novos.], [Leitura dos _diffs_ por membros do grupo antes de aplicar; testes automáticos corridos nos contentores (Capítulo 6); confirmação de que mensagens de erro e códigos HTTP não mudaram.],
    [Correção do progresso na criação de projeto], [Commit `aba322d`.], [Defeito detetado pelo grupo no teste manual TM-02; reteste no browser depois da correção.],
    [Investigação de anomalias], [OOM na base, 502 do nginx, cache de pré-visualizações, cache de página na M1.], [O agente identificou o OOM no `journalctl` e os 504 nos logs do nginx; essa evidência está descrita nas Secções 3.6 e 4.6. A separação `anon`/`file` na M1 foi proposta pelo agente e não foi revista pelo grupo em detalhe.],
    [Relatório], [Rascunho e passagem para o template.], [Números conferidos com os JSON de `medicoes/resultados/`; texto revisto pelo grupo.],
  ),
)

== Análise crítica

Erros da IA detetados durante o trabalho:

- *Barra de progresso incompleta.* O patch inicial do RNF-01 não ligava a barra de progresso à criação de projeto. Detetado pelo grupo no teste manual.
- *Scripts de medição.* Os scripts iniciais tinham os problemas do Capítulo 7 (nginx com IP antigo, resultados perdidos no OOM, logs de réplicas apagadas, pré-visualizações em cache). Detetados ao analisar resultados incoerentes.
- *Desvio na configuração.* A análise previa réplicas com limite de CPU, mas o `docker-compose.yaml` gerado não o define (Secção 4.4). O desvio só foi identificado depois da medição final, ao explicar o E3; o agente propôs três caminhos (justificar pelo hardware, limitar o CPU com `cpus: 1`, rever os alvos) e o grupo optou por não alterar nem o código nem os alvos depois de medir.

A IA foi mais útil nas tarefas com verificação objetiva (testes, medições repetíveis). As decisões (que RNF, que alvos, que alternativas, não alterar o método depois de medir) foram do grupo, que é responsável por todo o conteúdo entregue.
