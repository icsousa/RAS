#import "../template.typ": *

= Introdução

== Objetivo da fase

Na Fase 1 o PictuRAS passou a suportar vídeo numa lógica de MVP, com foco na validação funcional. A Fase 2 dá o passo seguinte: escolher dois requisitos não funcionais (RNF) e melhorá-los por refatoração, sem acrescentar funcionalidades. O relatório segue o ciclo pedido nas diretrizes: requisito → quantificação → medição de base → refatoração → medição final e análise.

Escolhemos dois RNF da característica *eficiência de desempenho* da ISO/IEC 25010. Ambos partem de fragilidades concretas do suporte a vídeo da solução de base (PL1-G4) e ambos constavam das ideias indicativas das diretrizes.

#tab([Os dois RNF e o resultado em uma frase],
  tabela(
    colunas: (3.2cm, 3.2cm, 1fr),
    [RNF], [Subcaracterística ISO/IEC 25010], [Resultado],
    [RNF-01 Carregamento de ficheiros grandes], [Utilização de recursos; comportamento temporal], [Um vídeo de 1 GB passou de *falhar sempre* (falta de memória no anfitrião) a carregar com ≈ 190 MB de memória dos processos; 4 carregamentos de 1 GB em paralelo passam com 2 GB por serviço.],
    [RNF-02 Elasticidade do processamento de vídeo], [Capacidade], [O processamento passou de 1 worker fixo a 1–4 réplicas automáticas (expansão em 16,5 s, contração em 70,4 s). A espera da pré-visualização desceu de 1 258 s para 30,4 s (p95), mas o débito (E3) e esta espera (E4) ficam abaixo do mínimo por saturação de CPU.],
  ),
)

== Ponto de partida e repositório

#tab([Commits de referência],
  tabela(
    colunas: (3.6cm, 4.2cm, 1fr),
    [Papel], [Commit], [Notas],
    [Ponto de partida oficial], [`052310226c51fa57a17101c7bd1ad795674aac95`], [Repositório oficial #link("https://github.com/picturas-um/picturas-27")[`picturas-um/picturas-27`] (solução PL1-G4 integrada).],
    [Medição de base], [`406c8e0`], [Repositório do grupo (#link("https://github.com/icsousa/RAS")[`icsousa/RAS`]), ramo `fase2/refatoracao`: código original e scripts de medição.],
    [Refatoração], [`5b2af25` (RNF-01), `3b8a8bd` (RNF-02)], [Mais `aba322d`: barra de progresso também na criação de projeto.],
    [Medição final], [`aba322d`], [Resultados em `17a8fae` e `83c7dae`.],
    [Correções aos scripts], [`45e4c87`, `78843bd`, `6e553e9`], [Descritas no Capítulo 7; aplicam-se por igual à base e à final.],
  ),
)

O diagnóstico detalhado, as medições exploratórias e a comparação de alternativas estão no documento de análise (`fase2/analise-rnf.pdf`). Este relatório resume-os e acrescenta as medições oficiais, a refatoração e a análise crítica.

== Organização do documento

- *Parte I - Enquadramento* (Capítulos 1 e 2): objetivo, ponto de partida, ambiente e método de medição.
- *Parte II - Os dois RNF* (Capítulos 3 e 4): para cada um, diagnóstico, quantificação, decisões arquiteturais e refatoração, medição de base e final, e análise.
- *Parte III - Avaliação transversal* (Capítulos 5 a 9): efeitos colaterais noutros requisitos, preservação funcional, validade das medições, utilização de IA e conclusão.

O Anexo A explica como repetir as medições e os testes.
