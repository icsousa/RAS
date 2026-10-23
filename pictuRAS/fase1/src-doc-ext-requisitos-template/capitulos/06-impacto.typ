#import "../template.typ": *

= Impacto no Sistema Existente

A tabela seguinte identifica os elementos do PictuRAS e do documento de requisitos de base afetados pelo suporte a vídeo. *Manter* significa que o elemento fica igual (e se indica explicitamente que não se aplica a vídeo quando é o caso), *Estender* que passa a fazer mais sem mudar o que já fazia e *Alterar* que o comportamento atual muda.

#tab([Impacto no sistema existente],
  tabela(
    colunas: (3.4cm, 1.7cm, 1fr, 2.1cm, 3cm),
    tamanho: 8.5pt,
    [Elemento existente afetado], [Impacto], [Descrição do impacto], [Caso(s) de uso], [Requisitos],
    [Caso de uso "Carregar imagens"], [Alterar], [Passa a "Carregar imagens e vídeos": aceita MP4/MOV (H.264/AAC), extrai os metadados do vídeo e rejeita vídeos acima da duração máxima do perfil.], [UC-VID-001 a 005 (pré-condições)], [REQ-VID-SUBMIT-001, REQ-VID-SUBMIT-002],
    [Limite diário de operações e sua exibição (RNF48; T-07)], [Alterar], [O limite diário do Registado (5 operações, usado pelas ferramentas de IA) passa a incluir o vídeo: cada trabalho concluído conta como uma operação, independentemente da duração; falhas e cancelamentos não contam (a operação reservada é devolvida). O Anónimo continua sem contador e o Premium sem limite. O contador visível inclui as operações de vídeo.], [UC-VID-001 a 005 (RN4)], [REQ-VID-QUOTA-001, REQ-VID-QUOTA-002, REQ-VID-QUOTA-003],
    [Tempo de aplicação de filtros (RNF43: < 5 s)], [Alterar], [O alvo de 5 s não é realista para processamento de vídeo e passa a aplicar-se apenas a imagens. Para vídeo, garante-se a confirmação da submissão em < 2 s, a indicação de estado e progresso e alvos próprios por operação.], [UC-VID-001 a 005], [REQ-VID-PERF-001, REQ-VID-STATUS-001, REQ-VID-TRIM-009, REQ-VID-TXT-006],
    [Cancelamento de processamento (RF17; T-01, T-10)], [Estender], [O cancelamento passa a abranger trabalhos de vídeo em fila ou em processamento, sem débito de quota.], [UC-VID-001 (FA2) e restantes], [REQ-VID-STATUS-003],
    [Reverter / Reset (RF42, RF71, RF72, RNF61)], [Estender], [Com as versões de vídeo (RNG-05), Reverter repõe a versão anterior e Reset a versão original de um vídeo. A integridade exigida pelo RNF61 é garantida por nunca se alterar a versão de origem.], [UC-VID-001 a 005], [REQ-VID-RESULT-001, REQ-VID-RESULT-002],
    [Perfis de utilizador (Anónimo, Registado/Gratuito, Premium)], [Estender], [Novos limites de duração e resolução por perfil (RNG-04) e restrições por ferramenta: Pan & Crop e Legendas exigem registo; LUT 3D e _Soft-sub_ são exclusivos do Premium.], [UC-VID-001 a 005], [REQ-VID-SUBMIT-002, REQ-VID-SUBMIT-003, REQ-VID-CROP-005, REQ-VID-CROP-010, REQ-VID-SPD-002, REQ-VID-TXT-004, REQ-VID-TXT-007, REQ-VID-TXT-012, REQ-VID-COL-002],
    [Modelo de domínio (Projeto, Imagem, Ferramenta)], [Estender], [Introdução de Ficheiro multimédia, Vídeo, Ferramenta de vídeo, Trabalho de processamento, Limites do perfil e Quota diária (Secção 3.3). Um projeto pode misturar imagens e vídeos.], [UC-VID-001 a 005], [—],
    [Armazenamento de projetos (MinIO; RNF45)], [Estender], [Passa a guardar ficheiros de vídeo, de dimensão muito superior às imagens, e as respetivas versões. Os ficheiros temporários de cada trabalho são eliminados quando este termina.], [UC-VID-001 a 005], [REQ-VID-RESULT-001, REQ-VID-STATUS-002],
    [Descarregar projeto (RF13; T-09)], [Estender], [Os vídeos resultado são descarregados em MP4 (H.264/AAC), com a faixa de legendas incluída no caso de _Soft-sub_.], [UC-VID-001 a 005], [REQ-VID-SUBMIT-001, REQ-VID-TXT-003, REQ-VID-TXT-004],
    [Segurança e privacidade dos dados (RNF44)], [Manter], [Os vídeos e as suas versões são tratados como as imagens: encriptados em trânsito e em repouso e acessíveis apenas ao utilizador autenticado ou por partilha.], [UC-VID-001 a 005], [—],
    [Encadeamento de ferramentas a conjunto de imagens (RF15; T-06)], [Manter], [Mantém-se apenas para imagens. No MVP as ferramentas de vídeo aplicam-se uma a uma (Secção 5.3).], [—], [—],
    [Presets personalizados (UC05; RF39, RF66)], [Manter], [Os _presets_ do utilizador continuam a aplicar-se só a imagens. As predefinições de cor do UC-VID-005 são do sistema e não são _presets_ do utilizador.], [UC-VID-005], [REQ-VID-COL-007],
    [Assistente IA na edição (UC06)], [Manter], [Não se aplica a vídeo nesta fase.], [—], [—],
    [Partilhar projeto (UC07; RF45, RF53)], [Manter], [Projetos com vídeos partilham-se da mesma forma. Um convidado com permissão de edição usa as ferramentas de vídeo com os limites do seu próprio perfil.], [UC-VID-001 a 005], [—],
  ),
)

== Conflitos entre funcionalidades resolvidos

Na especificação inicial, feita por funcionalidade, surgiram as seguintes inconsistências, resolvidas na versão consolidada:

- *Quota.* Cada funcionalidade definia um "crédito diário de vídeo" próprio. Foi unificado na RNG-01: uma operação do limite diário já existente por trabalho concluído.
- *Limites de resolução.* Só o UC-VID-005 limitava a resolução de saída por perfil, embora todas as operações recodifiquem o vídeo. A regra passou a transversal (RNG-04, REQ-VID-SUBMIT-003).
- *Limite de duração.* O UC-VID-001 limitava a duração do excerto, o que não tem efeito se o vídeo já cumpre o limite ao ser carregado. O limite passou para a submissão (REQ-VID-SUBMIT-002), e o abrandamento do UC-VID-003 ficou impedido de o ultrapassar (REQ-VID-SPD-009).
- *Áudio e falhas.* A cópia do áudio sem recodificação e o tratamento de falhas (notificar, manter a origem, não debitar) estavam repetidos em vários casos de uso; passaram a requisitos transversais (REQ-VID-AUDIO-001, REQ-VID-STATUS-002, REQ-VID-STATUS-005).
- *Caracteres não suportados.* O UC-VID-004 abortava a operação e o requisito de qualidade previa uma fonte de recurso. Prevalece a fonte de recurso (REQ-VID-TXT-005); o aborto fica reservado ao caso em que nem a fonte de recurso consegue desenhar o texto (UC-VID-004/E2).
