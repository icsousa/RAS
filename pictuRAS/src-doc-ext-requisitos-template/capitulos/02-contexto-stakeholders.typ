#import "../template.typ": *

= Contexto, Perfis e _Stakeholders_ (revisão)

== Perfis de utilização e vídeo

#tab([Perfis de utilização e respetivo acesso a vídeo],
  tabela(
    colunas: (2.6cm, 4.2cm, 1fr, 2.6cm),
    [Perfil], [Situação na _baseline_], [Alteração introduzida para vídeo], [Regras / requisitos],
    [Anónimo], [Operações limitadas, imagens pequenas], [Vídeos até 60 s e resolução máxima de saída 720p. Como na _baseline_, o Anónimo não tem contador diário de operações: o consumo é limitado pela duração e pela resolução. Acesso vetado a ferramentas de custo elevado (Pan & Crop, Overlay & Subtitles) e a LUTs 3D. Ajuste de velocidade limitado a [0.5x, 2.0x].], [RNG-01, RNG-04, UC-VID-002/RN3, UC-VID-003/RN1, UC-VID-005/RN1],
    [Registado], [Gratuito, até 5 operações/dia], [Vídeos até 300 s e resolução máxima de saída 1080p. Cada trabalho de vídeo concluído conta como uma operação do limite diário de 5 já usado pelas ferramentas de IA de imagem, independentemente da duração. Acesso a Pan & Crop (máximo 5 keyframes) e a Legendas apenas em modo "Hardcode" (máximo 20 blocos). Ajuste de velocidade [0.25x, 4.0x].], [RNG-01, RNG-04, UC-VID-002/RN1, UC-VID-003/RN1, UC-VID-004/RN1, UC-VID-004/RN2],
    [Premium], [Pago, uso ilimitado], [Vídeos até 3600 s e resolução máxima de saída 4K. Sem limite diário de operações (as operações ficam registadas, mas não são debitadas). Acesso integral a todas as ferramentas sem restrições de _keyframes_ ou blocos de texto. Exclusividade na importação de LUTs 3D personalizados e na exportação de legendas em faixa separada ("Soft-sub"). Velocidade [0.1x, 10.0x].], [RNG-01, RNG-04, UC-VID-002/RN1, UC-VID-003/RN1, UC-VID-004/RN1, UC-VID-005/RN1],
  ),
)

== _Stakeholders_ e interesses

#tab([_Stakeholders_ e interesses (novos ou revistos)],
  tabela(
    colunas: (3cm, 2cm, 1fr, 2cm, 2.6cm),
    [_Stakeholder_], [Estado], [Interesse(s) relativamente ao vídeo], [Influência], [UC / requisitos],
    [Utilizador (todos os perfis)], [Revisto], [Edição temporal e espacial precisa com _feedback_ visual em tempo real e preservação de sincronismo audiovisual.], [Alta], [Todos os UC-VID],
    [Consumidor Final do Vídeo], [Novo], [Beneficiar de acessibilidade audiovisual e facilidade de compreensão em reprodução silenciosa.], [Baixa], [UC-VID-004],
    [Operador da Infraestrutura], [Novo], [Controlar picos de alocação de CPU/GPU em processamento de fotogramas, limitar OOM (Out of Memory) e incentivar pass-through de codecs.], [Alta], [UC-VID-001, UC-VID-002, UC-VID-003, UC-VID-004, UC-VID-005],
    [Equipa de Produto PictuRAS], [Revisto], [Garantir monetização através de lógicas rigorosas de quota e ferramentas de alto valor (3D LUTs e Soft-subs) reservadas ao perfil Premium.], [Média], [UC-VID-001, UC-VID-002, UC-VID-003, UC-VID-004, UC-VID-005],
  ),
)

== Elicitação de requisitos

A definição dos limites, quotas e restrições funcionais para o suporte a vídeo resultou de sessões de _brainstorming_ interno focadas na proteção da infraestrutura. A equipa realizou simulações de carga de processamento com o utilitário FFmpeg para estabelecer os limiares de segurança (e.g., restrição do _stream copy_ e exclusão de perfis não pagantes das ferramentas com recálculo massivo de matrizes, como o Pan & Crop). A diferenciação de valor (_benchmarking_) baseou-se em modelos _freemium_ padrão do mercado de edição web, reservando formatos flexíveis (LUTs `.cube` e legendas separadas) exclusivamente para utilizadores Premium. Todos os limites temporais e de resolução têm origem direta nestas decisões arquiteturais preliminares e na necessidade de viabilizar o MVP sem esgotar recursos _cloud_ gratuitos.