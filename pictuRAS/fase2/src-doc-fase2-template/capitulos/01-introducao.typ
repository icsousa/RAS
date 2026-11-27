#import "../template.typ": *

= Introdução

#orientacao[
  Uma a duas páginas, no máximo. O leitor deve perceber, sem ler o resto, o que é este documento e em que se baseia.
  Respondam a:
  - *Propósito da fase*: que requisitos não funcionais do PictuRAS se pretende melhorar, por _refactoring_ e sem novas
    funcionalidades, e porquê.
  - *_Baseline_*: em que versão do sistema se basearam (_commit_ de partida), a mesma em todos os exercícios. Este
    relatório *estende* os documentos de base; não os reescreve.
  - *Âmbito do que é apresentado*: este relatório reúne os contributos dos Exercícios 6 (Blocos 1 e 2) e 7. Reutiliza
    os respetivos _templates_: copiem o conteúdo já preenchido, *mantendo os IDs* (`EV`, `H`, `ALT`, `QS`, `CAND`,
    `TAT`, `DA`), porque é através deles que os capítulos se encadeiam.
  - *Organização do documento*: Partes II (diagnóstico), III (qualidade), IV (táticas, decisões, medição e resultados)
    e V (síntese).
]

== Propósito e âmbito
Na Fase 1 o PictuRAS passou a suportar vídeo numa lógica de MVP. Nesta fase escolhemos dois requisitos não funcionais da *extensão de vídeo*, ambos da característica *eficiência de desempenho* da ISO/IEC 25010, e melhorámo-los por _refactoring_, sem novas funcionalidades e preservando o comportamento de imagens e vídeos:

- *CAND-1 — carregamento de ficheiros grandes* (utilização de recursos e comportamento temporal): na base, cada serviço do caminho de carregamento guardava o vídeo inteiro em memória e um vídeo de 1 GB, que o perfil Premium permite, esgotava a memória do anfitrião. Depois do _refactoring_, 1 GB carrega com ≈ 190 MB de memória dos processos e 4 carregamentos de 1 GB em paralelo terminam.
- *CAND-2 — elasticidade do processamento de vídeo* (capacidade): na base, um único _worker_ processava todos os vídeos e as pré-visualizações em série. Depois, há 1 a 4 réplicas automáticas e uma fila própria para pré-visualizações; a expansão e a contração cumprem o alvo, mas o débito (1,87 × a base, mínimo 2 ×) e a espera da pré-visualização (p95 de 30,4 s, alvo 5 s) ficam abaixo do mínimo, por saturação de CPU.

Ambos partem de fragilidades da solução de base (PL1-G4) com evidência, analisadas no quadro do padrão global da solução (microserviços com filas RabbitMQ). Este relatório estende os documentos de base; não os reescreve.

== _Baseline_ e repositório
#tab([Artefactos de partida],
  tabela(
    colunas: (5cm, 1fr),
    [Artefacto], [Versão / referência],
    [Documento de requisitos de base], [doc-ext-requisitos-2627.pdf],
    [Documento de solução arquitetural de base], [doc-sol-arquitetural.pdf],
    [Repositório de partida], [#link("https://github.com/picturas-um/picturas-27")[`picturas-um/picturas-27`], _commit_ `052310226c51fa57a17101c7bd1ad795674aac95` (cópia sem alterações em `icsousa/RAS`, _commit_ `406c8e0`)],
    [Repositório entregue], [#link("https://github.com/icsousa/RAS")[`icsousa/RAS`], ramo `main`; código e medições no _commit_ `aba322d` (PR \#1 e \#2); _commit_ da entrega: #preencher[hash do _commit_ de entrega]],
    [Diretrizes da Fase 2], [Versão 1 (`fase-2-guidelines.pdf`)],
  ),
)

== Exercícios e versões usadas

#orientacao[
  Indiquem, para cada exercício, a versão do enunciado e do _template_ que usaram, e a versão do vosso documento que
  serviu de entrada ao exercício seguinte (Bloco 1 → Bloco 2 → Exercício 7). Isto garante que quem avalia consegue
  perceber a que regras o trabalho respondeu, caso os enunciados tenham sido atualizados durante a fase.
]

#tab([Exercícios que alimentam este relatório],
  tabela(
    colunas: (3.6cm, 2.2cm, 2cm, 2cm, 1fr),
    [Exercício], [Capítulos], [Enunciado], [Template], [Versão do documento da equipa],
    [Exercício 6, Bloco 1: padrões arquiteturais], [2, 3 e 4], [1.1], [1.1], [v1.0],
    [Exercício 6, Bloco 2: trade-offs, cenários e candidatos a RNF], [5 e 6], [#preencher[1.2]], [#preencher[1.2]], [v1.0],
    [Exercício 7: táticas arquiteturais], [7 a 10], [3.0], [3.0], [v1.1],
  ),
)

== Organização do documento
A *Parte II* (capítulos 2 a 4) descreve como a solução foi lançada, a arquitetura e a sequência de um pedido, os padrões global e do vídeo e as alternativas, com evidências (`EV-nn`) e hipóteses (`H-nn`). A *Parte III* (capítulos 5 e 6) transforma as fragilidades encontradas em cenários de qualidade (`QS-nn`), prioriza-os e escolhe os dois candidatos (`CAND-n`) com a sua quantificação. A *Parte IV* (capítulos 7 a 10) identifica as táticas (`TAT-nn`), regista as decisões (`DA-n`), mostra as vistas antes e depois e apresenta os _trade-offs_, as medições e a preservação funcional. A *Parte V* (capítulos 11 e 12) faz a síntese e documenta a utilização de IA. Os IDs encadeiam os capítulos: `EV`/`H` → `ALT` → `QS`/`CAND` → `TAT` → `DA`.
