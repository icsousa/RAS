#import "../template.typ": *

// =============================================================================
//  CASO DE USO — UC-VID-005: Aplicação de filtros de cor
// =============================================================================

== UC-VID-005 — Aplicação de filtros de cor (Color Grading / LUTs)

=== Cabeçalho

#tab([Caso de uso UC-VID-005 — Aplicação de filtros de cor],
  tabela-campos(
    [ID do Caso de Uso], [UC-VID-005],
    [Nome], [Aplicação de filtros de cor (Color Grading / LUTs)],
    [Versão], [v1.1],
    [Autor], [Grupo PL3-G7],
    [Data], [2026-10-21],
    [Objetivo], [Aplicar filtros de cor predefinidos, ajustes paramétricos (brilho, contraste, saturação) ou tabelas LUT 3D a todos os fotogramas de um vídeo.],
    [Âmbito], [Módulo de Edição Multimédia / Pipeline de Processamento Cromático do PictuRAS],
    [Ator Principal], [Utilizador (qualquer perfil de autenticação)],
    [_Stakeholders_ e Interesses], [
      - *Utilizador*: Deseja harmonizar visualmente o vídeo ou conferir um estilo cromático específico com pré-visualização fidedigna.
      - *Operador da Infraestrutura*: Garantir que as operações frame a frame utilizam aceleração gráfica (GPU) eficiente para não sobrecarregar a fila global de processamento.
      - *Equipa de Produto PictuRAS*: Maximizar a reutilização dos algoritmos cromáticos existentes para imagem estática e diferenciar a oferta Premium através de LUTs customizados.
    ],
    [Pré-condições], [
      - Um vídeo suportado encontra-se carregado e validado no editor PictuRAS.
      - A interface gráfica carregou a biblioteca de predefinições de cor suportadas pelo sistema.
      - O utilizador dispõe de operações disponíveis no limite diário do seu perfil (RNG-01).
    ],
    [_Trigger_], [O utilizador seleciona a ferramenta "Filtros de Cor / Ajuste Cromático" no painel de edição de vídeo.],
  ),
)

=== Fluxo Principal

#tab([UC-VID-005 — Fluxo principal],
  tabela(
    colunas: (1.2cm, 1fr, 1fr),
    [Passo], [Ação do Ator], [Resposta do Sistema],
    [1], [O utilizador seleciona a ferramenta "Filtros de Cor".], [O sistema exibe o painel de gradação com uma galeria de filtros predefinidos (ex.: Sépia, Alto Contraste, Preto & Branco, Cinematográfico), controlos paramétricos deslizantes (brilho, saturação, contraste) e um seletor de intensidade global (0 a 100%).],
    [2], [O utilizador seleciona um filtro predefinido e ajusta a barra de intensidade pretendida.], [O sistema aplica a matriz cromática em tempo real sobre o fotograma atualmente pausado no reprodutor de vídeo para pré-visualização.],
    [3], [O utilizador solicita a reprodução do vídeo para avaliar o filtro dinamicamente.], [O sistema reproduz o segmento do vídeo no reprodutor aplicando a transformação cromática via _shaders_ no cliente.],
    [4], [O utilizador confirma a aplicação do filtro de cor.], [O sistema bloqueia a interface de edição, valida a quota do utilizador e envia a instrução de processamento para a fila assíncrona de renderização de vídeo.],
    [5], [—], [O serviço de vídeo processa a transformação cromática sobre a totalidade dos fotogramas da faixa de vídeo, mantendo intactos a taxa de fotogramas e o fluxo de áudio original.],
    [6], [—], [O sistema atualiza o projeto com o novo vídeo processado, deduz uma operação da quota quando aplicável (RNG-01) e desbloqueia a interface com o resultado final.],
  ),
)

=== Fluxos Alternativos

#tab([UC-VID-005 — Fluxos alternativos],
  tabela(
    colunas: (4cm, 1fr),
    [Fluxo], [Descrição (passo de origem: condição -> comportamento -> retorno)],
    [FA1 – Importação de Tabela 3D LUT (.CUBE)], [No Passo 2, se o utilizador possuir perfil Premium, seleciona "Importar LUT 3D" e submete um ficheiro .cube. O sistema valida a estrutura do ficheiro, calcula a matriz tridimensional e renderiza a pré-visualização sobre o vídeo antes da submissão no Passo 4.],
    [FA2 – Ajuste Manual Sem Filtros Predefinidos], [No Passo 2, o utilizador opta por não escolher um preset e ajusta manualmente os valores nos seletores de Brilho, Contraste, Saturação e Gama. O sistema concatena os filtros individuais numa única cadeia de processamento.],
  ),
)

=== Exceções

#tab([UC-VID-005 — Exceções],
  tabela(
    colunas: (1fr, 1fr),
    [Condição], [Comportamento do Sistema],
    [Ficheiro 3D LUT malformado ou corrompido], [Se o utilizador submeter um ficheiro .cube com cabeçalhos incorretos, dimensões de grelha não suportadas (diferentes de 17x17x17, 33x33x33 ou 65x65x65) ou valores cromáticos fora da gama [0.0, 1.0], o sistema recusa o ficheiro, emite o erro "Ficheiro LUT inválido ou corrompido" e repõe a visualização do vídeo sem alterações.],
    [Esgotamento de memória gráfica (GPU/VRAM) durante a renderização de fotogramas em alta resolução], [No Passo 5, se o nó de processamento esgotar os recursos de memória ao aplicar a matriz de cor em vídeos de resolução 4K ou superior, a tarefa é interrompida. O sistema notifica o utilizador com a mensagem "Falha temporária de processamento por falta de memória gráfica no nó de renderização", repõe o vídeo anterior e não debita a quota da conta.],
    [Utilizador sem permissão a tentar carregar LUT personalizado], [No Passo 2, se um utilizador Anónimo ou Registado tentar carregar um ficheiro .cube, o sistema bloqueia o envio do ficheiro, exibe uma mensagem informativa informando que a importação de LUTs 3D personalizados é uma funcionalidade exclusiva do perfil Premium e regressa à galeria de predefinições.],
  ),
)

=== Pós-condições

#tabela(
  colunas: (4cm, 1fr),
  [Tipo], [Resultado],
  [Garantia de Sucesso], [Um novo ficheiro de vídeo com a gradação de cor e matriz cromática aplicada a todos os fotogramas é disponibilizado no projeto; o fluxo de áudio e a taxa de fotogramas permanecem inalterados; a operação é deduzida na quota do utilizador.],
  [Garantia Mínima], [O ficheiro de vídeo de entrada mantém-se inalterado; nenhum artefacto com frames incompletos ou corrompidos é guardado; a quota de operações do utilizador não sofre qualquer débito.],
)

=== Regras de Negócio e Restrições

#tabela(
  colunas: (1.4cm, 1fr),
  [ID], [Regra],
  [RN1], [Suporte a LUTs personalizados: O carregamento e aplicação de ficheiros de tabelas 3D LUT (.cube) é restrito exclusivamente ao perfil de utilizador Premium.],
  [RN2], [Resolução máxima de saída por perfil (RNG-04): Anónimo 720p; Registado 1080p; Premium 4K. Vídeos com resolução superior são reduzidos à escala, mantendo o rácio de aspeto.],
  [RN3], [Preservação audiovisual: A aplicação de filtros de cor afeta unicamente a informação do fluxo de vídeo, não devendo reamostrar, alterar ou dessincronizar o fluxo de áudio existente.],
  [RN4], [Consumo de quota: uma operação de filtros de cor concluída com sucesso conta como uma operação do limite diário do perfil (RNG-01).],
)

=== Assunções

#tabela(
  colunas: (1.4cm, 1fr),
  [ID], [Assunção],
  [A1], [Os nós do serviço de processamento multimédia do PictuRAS possuem aceleração por hardware ou bibliotecas com filtros otimizados (lut3d, eq, colorbalance) com capacidade de processamento concorrente.],
  [A2], [O cliente web possui suporte para a API WebGL para conseguir renderizar _shaders_ de correção cromática em tempo real no elemento <video> durante a pré-visualização.],
  [A3], [O espaço de cor do vídeo de entrada encontra-se em normas padrão suportadas (ex.: Rec.709 ou sRGB), evitando distorções imprevistas na aplicação de predefinições de cor.],
)

=== Questões em Aberto

#tabela(
  colunas: (1.4cm, 1fr, 5cm),
  [ID], [Questão], [Resolução],
  [Q1], [O sistema deve disponibilizar aplicação de filtros a trechos temporais delimitados ou a funcionalidade aplica-se invariavelmente à totalidade da linha temporal do vídeo?], [Decidida → no MVP o filtro aplica-se à totalidade do vídeo; aplicação a troços fica para uma versão futura. REQ-VID-COL-010.],
  [Q2], [No caso de vídeos codificados com curvas logarítmicas (_Log Profiles_ como S-Log ou D-Log), deve ser fornecido um passo intermédio de normalização de espaço de cor antes da aplicação dos LUTs criativos?], [Decidida → sem normalização no MVP; assume-se espaço de cor Rec.709/sRGB (A3). Vídeos em perfis _Log_ são processados tal como estão.],
)