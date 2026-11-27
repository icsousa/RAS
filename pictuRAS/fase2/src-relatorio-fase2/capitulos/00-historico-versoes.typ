#import "../template.typ": *

#heading(numbering: none, outlined: false)[Histórico de versões]

#orientacao[
  Secção opcional. Registem as versões relevantes do documento, uma linha por versão, com a data, um resumo do que mudou e
  as iniciais de quem fez a alteração. Sugere-se acompanhar os marcos do trabalho: entrega do Bloco 1 do Exercício 6,
  do Bloco 2, do Exercício 7 e a versão entregue da Fase 2.

  Este histórico serve a equipa e quem avalia: mostra a evolução do documento e facilita perceber que versão foi
  entregue. Se a equipa usar o controlo de versões (_git_), podem remeter também para os _commits_ correspondentes.
]

#tabela(
  colunas: (1.5cm, 2.3cm, 1fr, 3.5cm),
  [Versão], [Data], [Alterações], [Autores],
  [v1.0], [2026-11-11], [Diagnóstico arquitetural, cenários de qualidade e candidatos a RNF, com medições exploratórias (Exercício 6, Blocos 1 e 2)], [PL3-G7],
  [v1.1], [2026-11-18], [Táticas e decisões arquiteturais (Exercício 7); medição de base, _refactoring_ e medição final (PR \#1)], [PL3-G7],
  [v1.2], [2026-11-25], [Testes manuais de regressão e análise dos resultados (PR \#2)], [PL3-G7],
  [v2.0], [2026-11-27], [Versão entregue da Fase 2, no _template_ do relatório da Fase 2], [PL3-G7],
)
