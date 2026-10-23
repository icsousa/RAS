#import "../template.typ": *

// =============================================================================
//  CASO DE USO — UC-VID-002: Enquadramento dinâmico com keyframes (Pan & Crop)
// =============================================================================

== UC-VID-002 — Enquadramento dinâmico com keyframes (Pan & Crop)

=== Cabeçalho

#tab([Caso de uso UC-VID-002 — Enquadramento dinâmico com keyframes (Pan & Crop)],
  tabela-campos(
    [ID do Caso de Uso], [UC-VID-002],
    [Nome], [Enquadramento dinâmico com keyframes (Pan & Crop)],
    [Versão], [v1.1],
    [Autor], [Grupo PL3-G7],
    [Data], [2026-10-21],
    [Objetivo], [Aplicar efeitos contínuos de zoom e deslocamento espacial através da definição de áreas de corte associadas a pontos temporais específicos (keyframes).],
    [Âmbito], [Módulo de Edição Multimédia / Pipeline de Transformação de Vídeo do PictuRAS],
    [Ator Principal], [Utilizador Registado ou Premium],
    [_Stakeholders_ e Interesses], [
      - *Utilizador*: Deseja criar movimentos suaves de câmara e focar áreas de interesse sem perder resolução desnecessariamente.
      - *Operador da Infraestrutura*: Deseja mitigar picos de consumo de CPU/GPU estabelecendo limites no número de keyframes interpolados e na duração do vídeo.
      - *Equipa de Produto PictuRAS*: Valorizar as contas Premium oferecendo interpolações avançadas e keyframes ilimitados.
    ],
    [Pré-condições], [
      - Um vídeo suportado encontra-se carregado e validado no editor PictuRAS.
      - O utilizador está autenticado como Registado ou Premium com quota de operações disponível.
      - As dimensões de resolução nativa do vídeo foram calculadas com sucesso pelo sistema.
    ],
    [_Trigger_], [O utilizador seleciona a ferramenta "Pan & Crop" no painel de ferramentas de vídeo.],
  ),
)

=== Fluxo Principal

#tab([UC-VID-002 — Fluxo principal],
  tabela(
    colunas: (1.2cm, 1fr, 1fr),
    [Passo], [Ação do Ator], [Resposta do Sistema],
    [1], [O utilizador seleciona a ferramenta "Pan & Crop".], [O sistema apresenta a interface de recorte com uma moldura de enquadramento sobreposta ao reprodutor, uma linha temporal com trilho dedicado a keyframes e controlos de rácio de aspeto.],
    [2], [O utilizador posiciona o cursor temporal no instante pretendido e ajusta a posição e dimensão da moldura de corte.], [O sistema valida as dimensões mínimas da moldura, gera um novo _keyframe_ nesse instante e atualiza a pré-visualização.],
    [3], [O utilizador desloca o cursor para outro instante temporal e redimensiona/desloca a moldura de corte para uma nova área.], [O sistema regista o segundo _keyframe_, calcula a curva de interpolação linear entre ambos e indica visualmente o trajeto do movimento no trilho da timeline.],
    [4], [O utilizador solicita a pré-visualização da animação.], [O sistema simula a transição contínua de escala e posição entre os keyframes definidos ao longo da reprodução.],
    [5], [O utilizador confirma a aplicação do enquadramento.], [O sistema valida a quota do utilizador, bloqueia a interface contra novas alterações e envia a tarefa de processamento para a fila de renderização.],
    [6], [—], [O serviço de vídeo processa a transformação espacial contínua fotograma a fotograma através da pipeline de filtros de vídeo.],
    [7], [—], [O sistema guarda o vídeo final resultante no projeto, debita uma operação da quota quando aplicável (RNG-01) e desbloqueia a interface exibindo o resultado.],
  ),
)

=== Fluxos Alternativos

#tab([UC-VID-002 — Fluxos alternativos],
  tabela(
    colunas: (4cm, 1fr),
    [Fluxo], [Descrição (passo de origem: condição -> comportamento -> retorno)],
    [FA1 – Edição ou Remoção de Keyframe], [No Passo 3, o utilizador pode selecionar um _keyframe_ pré-existente na timeline para ajustar as suas coordenadas espaciais ou removê-lo. O sistema recalcula automaticamente a interpolação entre os keyframes vizinhos que restarem.],
    [FA2 – Fixação de Rácio de Aspeto Fixo (Aspect Ratio Lock)], [No Passo 2, o utilizador ativa uma proporção fixa (ex.: 1:1, 9:16, 16:9). O sistema força a caixa delimitadora a manter a proporção escolhida durante todas as ações de redimensionamento e deslocamento.],
  ),
)

=== Exceções

#tab([UC-VID-002 — Exceções],
  tabela(
    colunas: (1fr, 1fr),
    [Condição], [Comportamento do Sistema],
    [Dimensão de corte inferior à resolução mínima suportada (< 320x240)], [Se o utilizador tentar reduzir a caixa de enquadramento abaixo do limite mínimo de resolução, o sistema bloqueia a redução adicional, emite a notificação "A área de corte não pode ser inferior a 320x240 píxeis para evitar pixelização excessiva" e mantém a última dimensão válida.],
    [Número de keyframes excede o limite do perfil de utilizador], [Se um utilizador com perfil Registado tentar adicionar um keyframe para além do limite máximo permitido por regra de negócio, o sistema bloqueia a criação do ponto, apresenta uma notificação sobre o teto do plano e sugere a subscrição de conta Premium.],
    [Erro de alocação de memória na pipeline de transcodificação de filtros de vídeo], [Se o nó de processamento esgotar a memória durante o cálculo dos filtros espaciais ao longo do tempo, a tarefa é interrompida. O sistema notifica o utilizador com "Falha de processamento por falta de recursos no nó de renderização", preserva o vídeo original e não debita a quota da conta.],
  ),
)

=== Pós-condições

#tabela(
  colunas: (4cm, 1fr),
  [Tipo], [Resultado],
  [Garantia de Sucesso], [É gerado um novo vídeo com as transformações de zoom e enquadramento interpoladas suavemente de acordo com os keyframes; a taxa de fotogramas e o áudio mantêm-se íntegros; a operação é debitada na quota do utilizador.],
  [Garantia Mínima], [O ficheiro de vídeo original permanece inalterado; quaisquer dados temporários de renderização são eliminados; a quota de operações do utilizador não é debitada.],
)

=== Regras de Negócio e Restrições

#tabela(
  colunas: (1.4cm, 1fr),
  [ID], [Regra],
  [RN1], [Limite de keyframes por perfil: Utilizadores Registados podem definir no máximo 5 keyframes por vídeo; Utilizadores Premium têm suporte para keyframes ilimitados.],
  [RN2], [Resolução mínima de recorte: Nenhuma janela de corte em qualquer keyframe pode ter dimensões inferiores a 320x240 píxeis.],
  [RN3], [Restrição de perfil: A funcionalidade de _Pan & Crop_ requer autenticação prévia, não se encontrando disponível para o perfil de utilizador Anónimo devido ao custo de processamento associado.],
  [RN4], [Consumo de quota: uma operação de _Pan & Crop_ concluída com sucesso conta como uma operação do limite diário do perfil (RNG-01).],
)

=== Assunções

#tabela(
  colunas: (1.4cm, 1fr),
  [ID], [Assunção],
  [A1], [O serviço de vídeo dispõe de capacidade de aceleração gráfica (GPU) ou bibliotecas de processamento multimédia com suporte a filtros de transformação afim em lote (_batch_).],
  [A2], [A interface do cliente tem capacidade para calcular e renderizar a pré-visualização em tempo real das matrizes de transformação 2D antes da renderização final no servidor.],
  [A3], [O rácio de amostragem de fotogramas original (FPS) do vídeo de entrada mantém-se estável para garantir a linearidade temporal da interpolação.],
)

=== Questões em Aberto

#tabela(
  colunas: (1.4cm, 1fr, 5cm),
  [ID], [Questão], [Resolução],
  [Q1], [A curva de interpolação deve limitar-se a uma transição linear ou deve ser disponibilizada aceleração e desaceleração suave (_ease-in / ease-out_) na versão base?], [Decidida → apenas interpolação linear no MVP; curvas _ease_ ficam para uma versão futura. REQ-VID-CROP-002.],
  [Q2], [Se o vídeo final resultante do _crop_ mantiver as dimensões originais do ficheiro de entrada através de _upscaling_, que algoritmo de interpolação (bilinear, bicúbico ou lanczos) deve ser aplicado por omissão?], [Decidida → interpolação bilinear por omissão; o vídeo final mantém a resolução de origem, limitada à do perfil. DQ-007, REQ-VID-CROP-008, REQ-VID-CROP-011.],
)