#import "../template.typ": *

= Introdução

== Propósito e âmbito

Na Fase 1 o PictuRAS passou a suportar vídeo numa lógica de MVP, com foco na validação funcional. A Fase 2 escolhe dois requisitos não funcionais (RNF) da extensão de vídeo e melhora-os *por refactoring*, sem novas funcionalidades e preservando o comportamento funcional de imagens e vídeos. O trabalho segue o ciclo das diretrizes: diagnóstico → cenário de qualidade → quantificação → medição de base → refatoração → medição final e análise.

Os dois RNF escolhidos pertencem à característica *eficiência de desempenho* da ISO/IEC 25010 e partem de fragilidades observadas na solução de base (PL1-G4):

- *CAND-1 / RNF-01 — carregamento de ficheiros grandes* (utilização de recursos e comportamento temporal): um vídeo de 1 GB, que o perfil Premium permite, esgotava a memória do anfitrião e derrubava o `api_gateway`. Depois da refatoração carrega com ≈ 190 MB de memória dos processos e 4 carregamentos de 1 GB em paralelo terminam com sucesso.
- *CAND-2 / RNF-02 — elasticidade do processamento de vídeo* (capacidade): um único worker processava todos os vídeos e as pré-visualizações em série. Depois da refatoração há 1 a 4 réplicas automáticas e uma fila própria para pré-visualizações; a expansão e a contração cumprem o alvo, mas o débito (1,87 × a base, mínimo 2 ×) e a espera da pré-visualização (p95 30,4 s, alvo 5 s) ficam abaixo do mínimo por saturação de CPU.

O âmbito é a extensão de vídeo, analisada no quadro do padrão global da solução (microserviços com comunicação assíncrona por RabbitMQ).

== Baseline e repositório

#tab([Artefactos de partida],
  tabela(
    colunas: (5.2cm, 1fr),
    [Artefacto], [Versão / referência],
    [Documento de requisitos de base], [`doc-ext-requisitos-2627.pdf` (Fase 1, Grupo 4; gerado a 2026-10-23), cópia em `pictuRAS/fase2/`],
    [Documento de solução arquitetural de base], [`doc-sol-arquitetural.pdf` da base anterior, na versão disponibilizada pela equipa docente (não faz parte desta entrega)],
    [Repositório de partida], [#link("https://github.com/picturas-um/picturas-27")[`picturas-um/picturas-27`], commit `052310226c51fa57a17101c7bd1ad795674aac95` (solução PL1-G4 integrada). Cópia sem alterações no repositório do grupo no commit `406c8e0`],
    [Repositório entregue], [#link("https://github.com/icsousa/RAS")[`icsousa/RAS`], ramo `main`. Código refatorado e medições: commit `aba322d` (PR \#1 e \#2). Commit da entrega: #preencher[hash do commit de entrega (`git rev-parse HEAD` no `main` após integrar este relatório)]],
    [Diretrizes da Fase 2], [`fase-2-guidelines.pdf`, versão 1],
  ),
)

== Exercícios e versões usadas

#tab([Exercícios que alimentam este relatório],
  tabela(
    colunas: (4.2cm, 2.2cm, 2cm, 2cm, 1fr),
    [Exercício], [Capítulos], [Enunciado], [Template], [Versão do documento da equipa],
    [Exercício 6, Bloco 1: padrões arquiteturais], [2, 3 e 4], [#preencher[1.1]], [#preencher[1.1]], [v1.0 (diagnóstico)],
    [Exercício 6, Bloco 2: trade-offs, cenários e candidatos a RNF], [5 e 6], [#preencher[1.2]], [#preencher[1.2]], [v1.0 (quantificação)],
    [Exercício 7: táticas arquiteturais], [7 a 10], [#preencher[3.0]], [#preencher[3.0]], [v1.1 (refatoração e medições)],
  ),
)

== Organização do documento

- *Parte II — Diagnóstico* (Capítulos 2 a 4): como a solução foi lançada, fontes, vista da arquitetura e sequência de um pedido (evidências *EV-nn* e hipóteses *H-nn*); padrão global e padrão do vídeo; alternativas *ALT-n* e matriz de comparação.
- *Parte III — Qualidade* (Capítulos 5 e 6): cenários de qualidade *QS-nn* construídos sobre as fragilidades com evidência, priorização, e os dois candidatos a RNF *CAND-n* com a sua quantificação.
- *Parte IV — Táticas, decisões, medição e resultados* (Capítulos 7 a 10): táticas candidatas *TAT-nn*, decisões arquiteturais *DA-n*, vistas antes e depois, matriz de efeitos, medições e preservação funcional.
- *Parte V — Síntese* (Capítulos 11 e 12): conclusões e utilização de IA.

Os IDs encadeiam os capítulos: EV/H → ALT → QS/CAND → TAT → DA. O Anexo A explica como repetir a solução, as medições e os testes.
