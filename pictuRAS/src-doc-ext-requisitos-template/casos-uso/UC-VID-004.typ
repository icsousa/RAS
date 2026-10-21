#import "../template.typ": *

// =============================================================================
//  CASO DE USO — UC-VID-004: Sobreposição de legendas e texto
// =============================================================================

== UC-VID-004 — Sobreposição de legendas e texto (Overlay & Subtitles)

=== Cabeçalho

#tab([Caso de uso UC-VID-004 — Sobreposição de legendas e texto],
  tabela-campos(
    [ID do Caso de Uso], [UC-VID-004],
    [Nome], [Sobreposição de legendas e texto (Overlay & Subtitles)],
    [Versão], [v1.1],
    [Autor], [Grupo PL3-G7],
    [Data], [2026-10-21],
    [Objetivo], [Inserir caixas de texto ou blocos de legendas sincronizados temporalmente sobre o vídeo, definindo estilo visual e intervalo de exibição.],
    [Âmbito], [Módulo de Edição Multimédia / Pipeline de Composição Gráfica do PictuRAS],
    [Ator Principal], [Utilizador Registado ou Premium],
    [_Stakeholders_ e Interesses], [
      - *Utilizador*: Pretende adicionar títulos descritivos ou legendas temporizadas de forma intuitiva com formatação personalizada.
      - *Consumidor Final do Vídeo*: Beneficiar de acessibilidade audiovisual e facilidade de compreensão em reprodução silenciosa.
      - *Operador da Infraestrutura*: Controlar a carga computacional associada à rasterização de texto frame a frame na transcodificação.
      - *Equipa de Produto PictuRAS*: Expandir as funcionalidades colaborativas e profissionais da plataforma.
    ],
    [Pré-condições], [
      - Um vídeo suportado encontra-se carregado e validado no editor PictuRAS.
      - O utilizador encontra-se autenticado com perfil Registado ou Premium com quota disponível.
      - O sistema carregou o catálogo de fontes tipográficas e parâmetros de renderização suportados.
    ],
    [_Trigger_], [O utilizador seleciona a ferramenta "Legendas e Texto" no painel de edição de vídeo.],
  ),
)

=== Fluxo Principal

#tab([UC-VID-004 — Fluxo principal],
  tabela(
    colunas: (1.2cm, 1fr, 1fr),
    [Passo], [Ação do Ator], [Resposta do Sistema],
    [1], [O utilizador seleciona a ferramenta "Legendas e Texto".], [O sistema apresenta a interface de edição de texto com campos de conteúdo, opções de estilo (fonte, tamanho, cor, alinhamento, caixa delimitadora) e um trilho de sobreposição na timeline.],
    [2], [O utilizador introduz o texto pretendido, ajusta o aspeto visual e posiciona a caixa de texto sobre a área de pré-visualização.], [O sistema renderiza o texto em tempo real sobre o fotograma atual e calcula as coordenadas (X, Y) da caixa delimitadora.],
    [3], [O utilizador define os instantes de entrada ($t_"in"$) e saída ($t_"out"$) da legenda através de marcadores no trilho temporal.], [O sistema valida a consistência do intervalo e projeta a barra temporal de visualização do bloco de texto no trilho.],
    [4], [O utilizador escolhe o modo de gravação pretendido: "Hardcode" (queimado na imagem) ou "Soft-sub" (faixa de texto embutida).], [O sistema valida a compatibilidade do modo escolhido com o perfil do utilizador e atualiza as opções de exportação.],
    [5], [O utilizador confirma a aplicação do texto/legendas.], [O sistema bloqueia a interface de edição, valida a quota e envia a tarefa de composição gráfica para a fila de processamento assíncrono.],
    [6], [—], [O serviço de vídeo processa a composição (queima o texto nos fotogramas via filtros de vídeo ou multiplexa a faixa de legendas no contentor de saída).],
    [7], [—], [O sistema guarda o vídeo final resultante no projeto, debita uma operação da quota quando aplicável (RNG-01) e restabelece a interface com o resultado visível.],
  ),
)

=== Fluxos Alternativos

#tab([UC-VID-004 — Fluxos alternativos],
  tabela(
    colunas: (4cm, 1fr),
    [Fluxo], [Descrição (passo de origem: condição -> comportamento -> retorno)],
    [FA1 – Importação de Ficheiro Estruturado de Legendas (.SRT / .VTT)], [No Passo 2, o utilizador clica em "Importar Legendas" e submete um ficheiro nos formatos .srt ou .vtt. O sistema analisa a sintaxe, extrai os blocos de texto e respetivos timestamps, preenchendo automaticamente o trilho de legendas da timeline com os segmentos importados.],
    [FA2 – Adição de Múltiplos Blocos de Texto], [No Passo 3, o utilizador clica em "Adicionar Novo Bloco de Texto". O sistema cria uma nova entrada no trilho temporal, permitindo ao utilizador configurar conteúdos e intervalos de tempo distintos de forma sequencial ou concorrente antes de submeter no Passo 5.],
  ),
)

=== Exceções

#tab([UC-VID-004 — Exceções],
  tabela(
    colunas: (1fr, 1fr),
    [Condição], [Comportamento do Sistema],
    [Ficheiro de legendas externo com codificação ou sintaxe inválida], [Se o ficheiro .srt ou .vtt submetido em FA1 contiver codificação não reconhecida (diferente de UTF-8), numeração de blocos incorreta ou erros de formatação temporal, o sistema interrompe a importação, exibe a notificação "Ficheiro de legendas corrompido ou formato não suportado (verifique a codificação UTF-8 e a sintaxe temporal)" e mantém o utilizador no estado prévio do Passo 1.],
    [Caracteres não suportados pela fonte escolhida], [No Passo 2, se o texto contiver caracteres sem glifo na fonte escolhida, o sistema usa para esses caracteres uma fonte de recurso Unicode e avisa o utilizador. Se, no Passo 6, ainda assim o texto não puder ser rasterizado, a tarefa é abortada, o utilizador é notificado da causa e o vídeo base mantém-se sem débito de quota (RNG-06).],
    [Tentativa de seleção de modo Soft-sub em perfil não autorizado], [No Passo 4, se um utilizador com perfil Registado selecionar a opção "Soft-sub", o sistema impede a seleção, apresenta a mensagem "A exportação de legendas em faixa separada é exclusiva de contas Premium" e seleciona automaticamente o modo "Hardcode".],
  ),
)

=== Pós-condições

#tabela(
  colunas: (4cm, 1fr),
  [Tipo], [Resultado],
  [Garantia de Sucesso], [É gerado um novo vídeo com as legendas ou textos integrados nos tempos e posições especificadas (visíveis na imagem ou selecionáveis como faixa de legendas no leitor); a integridade dos streams pré-existentes de áudio e vídeo é mantida; a operação é debitada na conta do utilizador.],
  [Garantia Mínima], [O ficheiro de vídeo original mantém-se inalterado; nenhum ficheiro corrompido ou com texto truncado é gravado no projeto; a quota de operações do utilizador não sofre qualquer débito.],
)

=== Regras de Negócio e Restrições

#tabela(
  colunas: (1.4cm, 1fr),
  [ID], [Regra],
  [RN1], [Modos de exportação por perfil: Utilizadores com perfil Registado estão restritos à gravação em modo "Hardcode" (queimado na imagem); o modo "Soft-sub" (faixa de texto multiplexada sem re-encoding de imagem) é exclusivo do perfil Premium.],
  [RN2], [Limite de blocos de texto: O número máximo de blocos de texto/legendas independentes configurados manualmente é de 20 para o perfil Registado e ilimitado para o perfil Premium.],
  [RN3], [Codificação de texto suportada: Ficheiros de legendas externos devem encontrar-se estritamente codificados na norma UTF-8.],
  [RN4], [Consumo de quota: uma operação de legendas e texto concluída com sucesso conta como uma operação do limite diário do perfil (RNG-01).],
)

=== Assunções

#tabela(
  colunas: (1.4cm, 1fr),
  [ID], [Assunção],
  [A1], [O serviço de vídeo tem instalado o motor de composição gráfica e rasterização de fontes (como libass ou drawtext integrado em FFmpeg) com suporte a fontes Unicode.],
  [A2], [No modo "Soft-sub" a faixa de legendas é multiplexada num contentor MP4 como faixa `mov_text` (RNG-02), reproduzível pelos leitores que suportam legendas embutidas em MP4.],
  [A3], [O cliente executa um renderizador web capaz de calcular com precisão as caixas delimitadoras de texto (_bounding boxes_) de acordo com a resolução nativa do vídeo.],
  [A4], [O texto aparece e desaparece por corte seco nos instantes $t_"in"$ e $t_"out"$; não há animações de entrada ou saída no MVP.],
)

=== Questões em Aberto

#tabela(
  colunas: (1.4cm, 1fr, 5cm),
  [ID], [Questão], [Resolução],
  [Q1], [O sistema deve disponibilizar um catálogo de animações pré-configuradas para o aparecimento e desaparecimento de texto (_fade in / fade out_) ou apenas corte seco temporal?], [Decidida → apenas corte seco no MVP; animações ficam fora do âmbito (A4).],
  [Q2], [Na importação de legendas externas, deve ser permitido ao utilizador editar individualmente o texto de cada linha na interface web antes da submissão?], [Decidida → sim: os blocos importados são editáveis com os mesmos controlos dos blocos manuais. REQ-VID-TXT-008.],
)