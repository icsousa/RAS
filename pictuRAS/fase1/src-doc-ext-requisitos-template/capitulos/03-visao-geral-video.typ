#import "../template.typ": *

= Visão Geral da Extensão de Vídeo

== Funcionalidades de vídeo do MVP

#tab([Funcionalidades de vídeo do MVP],
  tabela(
    colunas: (1fr, 2.1cm, 2.3cm, 2cm, 2.4cm, 2.4cm),
    [Funcionalidade], [Caso de uso], [Prefixo(s) REQ], [Perfis], [Dependências], [Estado de implementação],
    [Recorte temporal de vídeo (_trim_)], [UC-VID-001], [REQ-VID-TRIM], [Anón., Reg., Prem.], [REQ-VID-SUBMIT, -STATUS, -QUOTA, -RESULT], [Implementada],
    [Enquadramento dinâmico com keyframes (_Pan & Crop_)], [UC-VID-002], [REQ-VID-CROP], [Reg., Prem.], [REQ-VID-SUBMIT, -STATUS, -QUOTA, -RESULT, -AUDIO], [Implementada],
    [Modificação de velocidade de reprodução (_Speed Adjust_)], [UC-VID-003], [REQ-VID-SPD], [Anón., Reg., Prem.], [REQ-VID-SUBMIT, -STATUS, -QUOTA, -RESULT], [Implementada],
    [Sobreposição de legendas e texto (_Overlay & Subtitles_)], [UC-VID-004], [REQ-VID-TXT], [Reg., Prem.], [REQ-VID-SUBMIT, -STATUS, -QUOTA, -RESULT, -AUDIO], [Implementada],
    [Aplicação de filtros de cor (_Color Grading / LUTs_)], [UC-VID-005], [REQ-VID-COL], [Anón., Reg., Prem.], [REQ-VID-SUBMIT, -STATUS, -QUOTA, -RESULT, -AUDIO], [Implementada],
  ),
)

*Justificação no contexto do MVP.* Para cada funcionalidade: porque é que é das primeiras a valer a pena construir, que valor entrega e que parte do suporte a vídeo ficaria por validar sem ela.

- *UC-VID-001 — Recorte temporal de vídeo*: O recorte temporal é a operação fundacional de edição de vídeo, análoga ao recorte espacial em imagem estática. Permite validar a arquitetura de desmultiplexagem, sincronização áudio/vídeo e persistência de segmentos sem exigir processamento intensivo de todos os fotogramas.
- *UC-VID-002 — Enquadramento dinâmico*: O enquadramento dinâmico introduz no PictuRAS a capacidade de transformação espacial ao longo da linha temporal, indispensável para reformatar vídeos para diferentes rácios de aspeto. Valida o pipeline de renderização com recurso a filtros dinâmicos de corte e escala.
- *UC-VID-003 — Modificação de velocidade*: A alteração de velocidade de reprodução é uma das funcionalidades temporais mais procuradas. Permite validar o suporte a reamostragem de carimbos temporais de apresentação (PTS), interpolação ou descarte de fotogramas e algoritmos de estiramento temporal de áudio.
- *UC-VID-004 — Sobreposição de legendas e texto*: Fundamental para a acessibilidade do conteúdo multimédia e adaptação a plataformas digitais. Permite validar o suporte da pipeline à sobreposição de camadas gráficas rasterizadas (_hardcode_) e à multiplexagem de faixas de metadados de texto (_soft-subs_).
- *UC-VID-005 — Aplicação de filtros de cor*: Estende diretamente o ecossistema existente de processamento fotográfico do PictuRAS para o domínio temporal. Permite validar a capacidade da arquitetura em encadear operações matriciais de transformação de píxeis de forma massiva sobre sequências de fotogramas.

== Diagrama de casos de uso (atualizado)

#figure(
  image("../images/diagrama_casos_uso.png", width: 62%),
  caption: [Diagrama de casos de uso atualizado (Fase 1 — vídeo)],
) <fig-uc>

O diagrama estende o modelo da _baseline_ com os cinco casos de uso de vídeo (a laranja). O caso de uso "Carregar imagens" passa a "Carregar imagens e vídeos" (alterado), uma vez que a submissão de vídeo (validação de formato, extração de metadados e limites por perfil) é comum a todas as funcionalidades e é especificada uma única vez (REQ-VID-SUBMIT-nnn). Os perfis estão organizados por generalização: o Utilizador Registado herda o acesso do Anónimo e o Premium herda o do Registado. As associações refletem as regras de negócio: Recorte temporal, Velocidade e Filtros de cor estão abertos ao Anónimo; Pan & Crop e Legendas e texto, de custo computacional mais elevado, exigem pelo menos o perfil Registado (UC-VID-002/RN3, UC-VID-004). As diferenças dentro de um mesmo caso de uso (LUT 3D e _Soft-sub_ exclusivos do Premium, limites de _keyframes_, blocos e velocidade) são regras locais de cada caso de uso e não alteram as associações.

== Modelo de domínio (atualizado)

#paisagem[
  #figure(
    image("../images/modelo_dominio.png", width: 100%),
    caption: [Modelo de domínio atualizado (Fase 1 — vídeo); conceitos novos a laranja, alterados a azul claro],
  ) <fig-dominio>
]

O modelo (@fig-dominio) responde às questões levantadas pela introdução do vídeo:

- *Vídeo e Imagem.* Foi introduzido o conceito abstrato *Ficheiro multimédia* (nome, formato, tamanho), especializado em *Imagem* (largura, altura) e *Vídeo* (duração, resolução, taxa de fotogramas, _codecs_ de vídeo e áudio). Um *Projeto* contém ficheiros multimédia e pode, por isso, misturar imagens e vídeos.
- *Versões.* As operações de vídeo nunca alteram o vídeo de origem: cada operação concluída produz um novo Vídeo que *deriva de* outro (RNG-05). É isto que permite reverter e garantir as pós-condições mínimas dos casos de uso.
- *Processamento demorado.* O conceito *Trabalho de processamento* representa a aplicação de uma Ferramenta de vídeo a um Vídeo de origem, com estado (Em fila, A processar, Concluído, Falhado, Cancelado), progresso e motivo de falha; quando concluído produz o Vídeo resultado e consome, se aplicável, uma unidade da *Quota diária*.
- *Ferramentas.* *Ferramenta* passa a ter duas especializações: as ferramentas de imagem da _baseline_ (que continuam a aplicar-se apenas a imagens; no MVP não são aplicadas a fotogramas de vídeo) e as cinco *Ferramentas de vídeo*. Os parâmetros de cada ferramenta são conceitos do domínio: *Segmento temporal* (recorte e troço de velocidade), *Keyframe* (Pan & Crop), *Bloco de texto* e *Ficheiro de legendas* (Legendas e texto), *Predefinição de cor* e *LUT 3D* (Filtros de cor).
- *Quotas e limites.* Cada perfil está sujeito a *Limites do perfil* (duração máxima, resolução máxima de saída, operações diárias, _keyframes_ e blocos de texto máximos), e cada utilizador tem uma *Quota diária* com as operações já usadas (RNG-01, RNG-04).

Os conceitos da _baseline_ não afetados pelo vídeo (Preset, Assistente IA, Sugestão IA e o convite entre utilizadores) mantêm-se como no modelo de base e foram omitidos da figura por legibilidade.

== Regras de negócio transversais

#tab([Regras de negócio transversais],
  tabela(
    colunas: (1.6cm, 1fr, 3cm, 3cm),
    [ID], [Regra], [Origem / justificação], [Requisitos],
    [RNG-01], [Quota de operações: na _baseline_ só o perfil Registado tem limite diário (5 operações, consumidas pelas ferramentas de IA de imagem). Cada trabalho de vídeo concluído com sucesso de um utilizador Registado conta como exatamente uma operação desse limite, independentemente da duração do vídeo; falhas e cancelamentos não contam. O Anónimo continua sem contador e o Premium sem limite; para ambos, o custo da duração é controlado pelos limites da RNG-04.], [Regra de quotas da _baseline_ (`FREE_DAILY_OP`) reinterpretada para vídeo; Equipa de Produto], [REQ-VID-QUOTA-001, REQ-VID-QUOTA-002, REQ-VID-QUOTA-003],
    [RNG-02], [Formatos suportados: o sistema aceita vídeos nos contentores MP4 ou MOV, codificados em H.264 (vídeo) e AAC (áudio), e produz resultados em MP4 (H.264/AAC; legendas _Soft-sub_ em faixa `mov_text`).], [Limitação técnica do MVP; formatos reproduzíveis nativamente pelos _browsers_], [REQ-VID-SUBMIT-001],
    [RNG-03], [Estado de processamento: todas as operações de vídeo são processadas de forma assíncrona e indicam ao utilizador o estado e o progresso do trabalho.], [Prevenção do abandono durante esperas longas (UX)], [REQ-VID-STATUS-001, REQ-VID-STATUS-004],
    [RNG-04], [Limites de vídeo por perfil: duração máxima do vídeo — Anónimo 60 s, Registado 300 s, Premium 3600 s; resolução máxima de saída — Anónimo 720p, Registado 1080p, Premium 4K.], [Proteção da infraestrutura e diferenciação _freemium_; Operador da Infraestrutura, Equipa de Produto], [REQ-VID-SUBMIT-002, REQ-VID-SUBMIT-003, REQ-VID-SPD-009],
    [RNG-05], [Não destrutividade: nenhuma operação altera o vídeo de origem; cada operação concluída cria uma nova versão do vídeo no projeto.], [Garantias mínimas dos casos de uso; UC-VID-001/Q2], [REQ-VID-RESULT-001, REQ-VID-RESULT-002],
    [RNG-06], [Falhas: se um trabalho falhar, for abortado ou cancelado, o utilizador é notificado da causa, a versão de origem mantém-se, os ficheiros temporários são eliminados e a quota não é debitada.], [Garantias mínimas comuns aos cinco casos de uso], [REQ-VID-STATUS-002, REQ-VID-STATUS-003, REQ-VID-QUOTA-001],
  ),
)

== Convenções de identificação

#tabela(
  colunas: (4.2cm, 1fr),
  [Identificador], [Utilização],
  [UC-VID-nnn], [Caso de uso de vídeo (numeração única no relatório, a partir de UC-VID-001)],
  [REQ-VID-{FUNC}-nnn], [Requisito (funcional ou não funcional); {FUNC} identifica a funcionalidade (TRIM, CROP, SPD, TXT, COL) ou a área transversal do serviço (SUBMIT, STATUS, QUOTA, RESULT, AUDIO, PERF); IDs nunca se reutilizam, mesmo que o requisito seja eliminado],
  [RN$k$, A$k$, Q$k$, FA$k$], [Regra, assunção, questão em aberto e fluxo alternativo de um caso de uso (locais ao caso de uso; qualificados, e.g. `UC-VID-001/RN2`, nas tabelas partilhadas)],
  [RNG-nn / DQ-nnn], [Regra de negócio transversal / decisão de qualidade (globais)],
  [DA-nn], [Decisão arquitetural (Capítulo de Arquitetura)],
  [TST-{FUNC}-nn], [Teste (automático ou manual)],
  [T-nn], [Tarefa de manutenção corretiva da solução de base],
  [UCnn, RFnn, RNFnn], [Elementos do documento de requisitos de base (referidos quando são alterados — ALT)],
)