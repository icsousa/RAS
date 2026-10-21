# Overlay & Subtitles
### Casos de Uso · Fase 1: Suporte a Vídeo no PictuRAS

---

## 0. Identificação

| **Campo** | **Valor** |
|-----------|-----------|
| **Grupo / Equipa** | Grupo 1 |
| **Autores** | Duarte Pinto Bravo (*pg63951*), Ivo Costa Sousa (*pg63976*), Tiago Gonçalves de Melo (*pg65445*) |
| **Data** | 2026-10-05 |
| **Versão do documento** | v1.0 |
| **Unidade Curricular** | Requisitos e Arquiteturas de Software — MEI, Universidade do Minho |

---

## 1. Funcionalidade de vídeo escolhida

| **Campo** | **Valor** |
|-----------|-----------|
| **Funcionalidade** | Sobreposição de legendas e texto (*Overlay & Subtitles*) |
| **Perfil(s) de utilizador abrangido(s)** | Registado e Premium. Exige renderização de texto e composição gráfica sobre fotogramas ou manipulação de faixas adicionais no contentor, reservando-se para utilizadores autenticados com diferenciação na exportação de legendas embutidas vs. selecionáveis. |

**Justificação no contexto do MVP**
A adição de legendas e texto é fundamental para a acessibilidade do conteúdo multimédia e para a adaptação de vídeos a plataformas digitais e redes sociais, onde a reprodução sem áudio é predominante. Permite validar o suporte da pipeline à sobreposição de camadas gráficas rasterizadas (*hardcode*) e à multiplexagem de faixas de metadados de texto (*soft-subs*). Sem esta funcionalidade, o PictuRAS não suporta ferramentas de contextualização textual e acessibilidade audiovisual.

---

## 2. Caso de Uso

### 2.1 Cabeçalho

| **Secção** | **Detalhes** |
|------------|--------------|
| **ID do Caso de Uso** | UC-VID-004 |
| **Nome** | Sobreposição de legendas e texto (*Overlay & Subtitles*) |
| **Versão** | v1.0 |
| **Autor** | Ivo Sousa & Tiago Melo |
| **Data** | 2026-10-05 |
| **Objetivo** | Inserir caixas de texto ou blocos de legendas sincronizados temporalmente sobre o vídeo, definindo estilo visual e intervalo de exibição. |
| **Âmbito** | Módulo de Edição Multimédia / Pipeline de Composição Gráfica do PictuRAS |
| **Ator Principal** | Utilizador Registado ou Premium |
| **Stakeholders e Interesses** | - **Utilizador**: Pretende adicionar títulos descritivos ou legendas temporizadas de forma intuitiva com formatação personalizada.<br>- **Consumidor Final do Vídeo**: Beneficiar de acessibilidade audiovisual e facilidade de compreensão em reprodução silenciosa.<br>- **Operador da Infraestrutura**: Controlar a carga computacional associada à rasterização de texto frame a frame na transcodificação.<br>- **Equipa de Produto PictuRAS**: Expandir as funcionalidades colaborativas e profissionais da plataforma. |
| **Pré-condições** | - Um vídeo suportado encontra-se carregado e validado no editor PictuRAS.<br>- O utilizador encontra-se autenticado com perfil Registado ou Premium com quota disponível.<br>- O sistema carregou o catálogo de fontes tipográficas e parâmetros de renderização suportados. |
| **Trigger** | O utilizador seleciona a ferramenta "Legendas e Texto" no painel de edição de vídeo. |

### 2.2 Fluxo Principal

| **Passo** | **Ação do Ator** | **Resposta do Sistema** |
|-----------|------------------|-------------------------|
| 1 | O utilizador seleciona a ferramenta "Legendas e Texto". | O sistema apresenta a interface de edição de texto com campos de conteúdo, opções de estilo (fonte, tamanho, cor, alinhamento, caixa delimitadora) e um trilho de sobreposição na timeline. |
| 2 | O utilizador introduz o texto pretendido, ajusta o aspeto visual e posiciona a caixa de texto sobre a área de pré-visualização. | O sistema renderiza o texto em tempo real sobre o fotograma atual e calcula as coordenadas $(X, Y)$ da caixa delimitadora. |
| 3 | O utilizador define os instantes de entrada ($t_{\text{in}}$) e saída ($t_{\text{out}}$) da legenda através de marcadores no trilho temporal. | O sistema valida a consistência do intervalo e projeta a barra temporal de visualização do bloco de texto no trilho. |
| 4 | O utilizador escolhe o modo de gravação pretendido: "Hardcode" (queimado na imagem) ou "Soft-sub" (faixa de texto embutida). | O sistema valida a compatibilidade do modo escolhido com o perfil do utilizador e atualiza as opções de exportação. |
| 5 | O utilizador confirma a aplicação do texto/legendas. | O sistema bloqueia a interface de edição, valida a quota e envia a tarefa de composição gráfica para a fila de processamento assíncrono. |
| 6 | — | O serviço de vídeo processa a composição (queima o texto nos fotogramas via filtros de vídeo ou multiplexa a faixa de legendas no contentor de saída). |
| 7 | — | O sistema guarda o vídeo final resultante no projeto, debita a operação da quota do utilizador e restabelece a interface com o resultado visível. |

### 2.3 Fluxos Alternativos

| **Fluxo** | **Descrição** |
|-----------|---------------|
| FA1 – Importação de Ficheiro Estruturado de Legendas (.SRT / .VTT) | No Passo 2, o utilizador clica em "Importar Legendas" e submete um ficheiro nos formatos `.srt` ou `.vtt`. O sistema analisa a sintaxe, extrai os blocos de texto e respetivos timestamps, preenchendo automaticamente o trilho de legendas da timeline com os segmentos importados. |
| FA2 – Adição de Múltiplos Blocos de Texto | No Passo 3, o utilizador clica em "Adicionar Novo Bloco de Texto". O sistema cria uma nova entrada no trilho temporal, permitindo ao utilizador configurar conteúdos e intervalos de tempo distintos de forma sequencial ou concorrente antes de submeter no Passo 5. |

### 2.4 Exceções

| **Condição** | **Comportamento do Sistema** |
|--------------|------------------------------|
| Ficheiro de legendas externo com codificação ou sintaxe inválida | Se o ficheiro `.srt` ou `.vtt` submetido em FA1 contiver codificação não reconhecida (diferente de UTF-8), numeração de blocos incorreta ou erros de formatação temporal, o sistema interrompe a importação, exibe a notificação "Ficheiro de legendas corrompido ou formato não suportado (verifique a codificação UTF-8 e a sintaxe temporal)" e mantém o utilizador no estado prévio do Passo 1. |
| Conflito de renderização tipográfica ou caracteres não mapeáveis | No Passo 6, se o motor de rasterização detetar glifos ou carateres especiais não suportados pela fonte escolhida gerando blocos indefinidos (*tofu*), o sistema interrompe a queima de texto, cancela o processo, notifica o utilizador da incompatibilidade da fonte selecionada e restaura o vídeo base sem debitar quota. |
| Tentativa de seleção de modo Soft-sub em perfil não autorizado | No Passo 4, se um utilizador com perfil Registado selecionar a opção "Soft-sub", o sistema impede a seleção, apresenta a mensagem "A exportação de legendas em faixa separada é exclusiva de contas Premium" e seleciona automaticamente o modo "Hardcode". |

### 2.5 Pós-condições

| **Tipo** | **Resultado** |
|----------|---------------|
| Garantia de Sucesso | É gerado um novo vídeo com as legendas ou textos integrados nos tempos e posições especificadas (visíveis na imagem ou selecionáveis como faixa de legendas no leitor); a integridade dos streams pré-existentes de áudio e vídeo é mantida; a operação é debitada na conta do utilizador. |
| Garantia Mínima | O ficheiro de vídeo original mantém-se inalterado; nenhum ficheiro corrompido ou com texto truncado é gravado no projeto; a quota de operações do utilizador não sofre qualquer débito. |

### 2.6 Regras de Negócio e Restrições

| **ID** | **Regra** |
|--------|-----------|
| RN1 | Modos de exportação por perfil: Utilizadores com perfil Registado estão restritos à gravação em modo "Hardcode" (queimado na imagem); o modo "Soft-sub" (faixa de texto multiplexada sem re-encoding de imagem) é exclusivo do perfil Premium. |
| RN2 | Limite de blocos de texto: O número máximo de blocos de texto/legendas independentes configurados manualmente é de 20 para o perfil Registado e ilimitado para o perfil Premium. |
| RN3 | Codificação de texto suportada: Ficheiros de legendas externos devem encontrar-se estritamente codificados na norma UTF-8. |
| RN4 | Consumo de quota: Uma operação de sobreposição de legendas e texto concluída com sucesso consome 1 crédito diário da quota de vídeo da conta. |

### 2.7 Assunções

| **ID** | **Assunção** |
|--------|--------------|
| A1 | O serviço de vídeo tem instalado o motor de composição gráfica e rasterização de fontes (como `libass` ou `drawtext` integrado em FFmpeg) com suporte a fontes Unicode. |
| A2 | O contentor de destino selecionado para o modo "Soft-sub" (ex.: MP4 com faixas `mov_text` ou MKV com `subrip`) é compatível com os padrões de reprodução dos browsers dos clientes. |
| A3 | O cliente executa um renderizador web capaz de calcular com precisão as caixas delimitadoras de texto (*bounding boxes*) de acordo com a resolução nativa do vídeo. |

### 2.8 Questões em Aberto

| **ID** | **Questão** |
|--------|-------------|
| Q1 | O sistema deve disponibilizar um catálogo de animações pré-configuradas para o aparecimento e desaparecimento de texto (*fade in / fade out*) ou apenas corte seco temporal? |
| Q2 | Na importação de legendas externas, deve ser permitido ao utilizador editar individualmente o texto de cada linha na interface web antes da submissão? |

---

## 3. Utilização de agentes de IA

| **Ferramenta / *skill*** | **Tarefa apoiada** | **Validação realizada pela equipa** |
|--------------------------|--------------------|--------------------------------------|
| Google Gemini | Delineação dos modos de exportação (Hardcode vs. Soft-sub), estruturação dos passos para manipulação de legendas externas e definição de exceções de codificação e tipografia. | Revisão rigorosa pela equipa: validação das restrições de perfil alinhadas com as capacidades dos contentores de vídeo, confirmação dos limites de blocos de texto para utilizadores registados e verificação dos critérios de integridade pós-condição. |

---

## 4. Especificação de Requisitos do Sistema (ERS)

**Caso de Uso:** UC-VID-004 — Sobreposição de legendas e texto (*Overlay & Subtitles*)  
**Versão do dossiê:** v1.1  
**Baseline do Exercício 1:** v1.0 (Requisitos originais REQ-VID-TXT-001 a REQ-VID-TXT-011)

### 4.1 Requisitos da ERS

#### 4.1.1 Requisitos Funcionais

| **ID** | **Requisito** | **Prioridade** | **Evolução** | **Novo/Alt** | **Origem (UC / RN / decisão)** | **Justificação** | **Critério de aceitação / verificação** |
|--------|---------------|----------------|--------------|--------------|--------------------------------|-----------------|----------------------------------------|
| REQ-VID-TXT-001 | O sistema deve disponibilizar um editor de texto interativo no canvas e um trilho dedicado na linha temporal para definir a duração de cada bloco. | Deve ter | Refinado | NOVO | Passo 1 | Fornece os controlos espaciais e temporais essenciais à manipulação de texto. | Dado que a ferramenta de Legendas é aberta, Quando a UI carrega, Então o utilizador visualiza controlos de formatação e uma *timeline* com marcadores arrastáveis de entrada e saída. |
| REQ-VID-TXT-002 | O sistema deve renderizar o texto introduzido em tempo real no reprodutor, refletindo formatação, cor e coordenadas espaciais. | Deve ter | Refinado | NOVO | Passo 2 | Permite o posicionamento visual imediato sem necessidade de esperar por processamento remoto (*feedback loop* rápido). | Dado um bloco de texto adicionado, Quando o utilizador altera a cor ou arrasta a caixa de texto, Então a atualização é imediata no fotograma visível. |
| REQ-VID-TXT-003 | O sistema deve suportar a adição de múltiplos blocos de texto (sequenciais ou concorrentes) na linha temporal. | Deve ter | Refinado | NOVO | Passo 3, FA2 | Essencial para legendar diálogos ou sobrepor diversas informações visuais no mesmo instante. | Dado um vídeo com um bloco de texto no minuto 1, Quando o utilizador clica em "Adicionar", Então surge um novo bloco editável independente. |
| REQ-VID-TXT-004 | O sistema deve extrair os timestamps e o texto a partir da importação de ficheiros estruturados de legendas (`.srt` e `.vtt`) codificados em UTF-8. | Deve ter | Refinado | NOVO | FA1, RN3 | Agiliza fluxos de trabalho onde a legendagem foi preparada em software externo. | Dado um ficheiro `.srt` válido, Quando importado pelo utilizador, Então o trilho temporal é automaticamente preenchido com as respetivas entradas e tempos. |
| REQ-VID-TXT-005 | O sistema deve bloquear a importação e alertar o utilizador caso o ficheiro `.srt`/`.vtt` apresente codificação inválida (não-UTF-8) ou formatação temporal corrompida. | Deve ter | Refinado | NOVO | E1 | Evita a propagação de caracteres ilegíveis ("mojibake") ou dessincronização na interface. | Dado um ficheiro `.vtt` com *encoding* ANSI-Windows, Quando é submetido, Então o sistema bloqueia e notifica sobre a obrigatoriedade do formato UTF-8. |
| REQ-VID-TXT-006 | O sistema deve ser capaz de exportar em modo "Hardcode", rasterizando e fundindo destrutivamente o texto nos fotogramas na transcodificação. | Deve ter | Refinado | NOVO | Passo 6 | Garante que as legendas estarão visíveis em 100% dos reprodutores e redes sociais (TikTok, Instagram). | Dado o modo "Hardcode" selecionado, Quando o vídeo é exportado, Então o texto faz parte integrante da imagem e não pode ser desligado num leitor comum. |
| REQ-VID-TXT-007 | O sistema deve ser capaz de exportar em modo "Soft-sub", multiplexando as legendas como uma faixa ativável sem alterar os píxeis do vídeo original. | Poderia ter | Refinado | NOVO | Passo 6 | Respeita as melhores práticas de acessibilidade (*Closed Captions*) e permite preservação da imagem intacta. | Dado o modo "Soft-sub", Quando gerado o MP4, Então o ficheiro contém um *stream* `mov_text` ou `tx3g` que o utilizador pode ocultar no VLC ou browser. |
| REQ-VID-TXT-008 | O sistema deve bloquear a opção "Soft-sub" a contas de perfil Registado, forçando a seleção do modo "Hardcode". | Deve ter | Refinado | NOVO | Passo 4, E3, RN1 | Segrega funcionalidades "Pro" para incentivar a conversão para planos pagos (Premium). | Dado um utilizador Registado, Quando acede às opções de exportação, Então a *checkbox* "Soft-sub" está desativada e com indicativo de funcionalidade Premium. |
| REQ-VID-TXT-009 | O sistema deve impor o limite máximo de 20 blocos de texto por vídeo para contas de perfil Registado. | Deve ter | Refinado | NOVO | RN2 | Limita o peso do *payload* de metadados e o tempo de transcodificação de filtros de vídeo para contas gratuitas. | Dado um vídeo com 20 blocos já criados num perfil Registado, Quando clica em "Adicionar", Então é impedido e alertado para o teto de utilização. |
| REQ-VID-TXT-011 | O sistema deve deduzir 1 crédito à quota diária do utilizador apenas após a finalização bem-sucedida do ficheiro exportado. | Deve ter | Refinado | ALT | Passo 7, RN4 | Normaliza a cobrança de serviços computacionais segundo as regras da plataforma. | Dado um saldo atual de créditos, Quando a queima de legendas conclui, Então o valor em conta decrementa uma unidade. |
| REQ-VID-TXT-012 | O sistema deve fornecer feedback de progresso (estado na fila e percentagem) enquanto executa o processamento do texto. | Deve ter | Novo | NOVO | Passo 5, Passo 6, Secção 4.1.3 | Como o método "Hardcode" requer recodificação (*re-encoding*) pesada frame-a-frame, a comunicação visual previne abandono da página. | Dado o início do processamento, Quando o *worker* é alocado, Então o utilizador vê uma barra progressiva e o estado "A processar frames...". |

#### 4.1.2 Requisitos Não Funcionais e de Qualidade

| **ID** | **Requisito** | **Característica ISO/IEC 25010** | **Alvo MVP** | **Alvo produção** | **Evolução** | **Origem (UC / DQ)** | **Critério de aceitação / verificação** |
|--------|---------------|----------------------------------|--------------|------------------|--------------|----------------------|----------------------------------------|
| REQ-VID-TXT-010 | O sistema deve validar preventivamente glifos complexos e interromper de forma graciosa se ocorrer erro de rasterização (falha de fonte), evitando vídeos corrompidos. | Fiabilidade (Tolerância a Falhas) | Falha reportada via erro claro, sem consumir quota | *Fallback* automático para fonte universal (Noto Sans) | Refinado | E2, Garantia Mínima, DQ-002 | Dado um texto com emoji não suportado pela fonte X, Quando o FFmpeg falha no filtro `drawtext`, Então o sistema interceta o erro e avisa o utilizador sem deduzir créditos. |
| REQ-VID-TXT-013 | O processo de exportação em "Hardcode" deve completar-se em tempo razoável para garantir usabilidade do sistema interativo. | Eficiência de Desempenho (Comportamento Temporal) | Tempo < 2.5x a duração do vídeo | Tempo < 1.5x a duração do vídeo com aceleração GPU | Novo | Secção 4.1.3, DQ-001 | Dado um vídeo de 1 minuto em 1080p, Quando submetido a renderização "Hardcode", Então o ficheiro resultante deve estar disponível em menos de 2m30s. |

#### 4.1.3 Verificação da completude e dos limites do âmbito

| **Tópico a verificar** | **Aplicável?** | **Decisão / justificação** | **Requisito(s) relacionado(s)** |
|-----------------------|---------------|----------------------------|--------------------------------|
| Formato, codec, duração e dimensão do vídeo | Sim | A multiplexagem "Soft-sub" exige suporte estrito pelo contentor destino (MP4 vs MKV). "Hardcode" impõe carga sobre codecs de vídeo H.264/H.265. | REQ-VID-TXT-006, REQ-VID-TXT-007 |
| Estado, progresso, cancelamento e resultado | Sim | Essencial para os utilizadores Registados, visto que o "Hardcode" exige *re-encoding* total, originando latência significativa (minutos). | REQ-VID-TXT-012 |
| Falhas durante o processamento | Sim | Incompatibilidades de carateres e fontes (*missing glyphs* / erro `drawtext` FFmpeg) são frequentes na inserção de texto. | REQ-VID-TXT-010 |
| Persistência e expiração dos ficheiros | Não | Apenas aplicam as diretivas de arquitetura geral de ficheiros da cloud PictuRAS (TTL). Fora do escopo do caso de uso de texto. | N/A |
| Perfis e contagem de operações | Sim | A funcionalidade bloqueia a opção leve (Soft-sub) a Premium para monetização, limitando contas Registadas a 20 *hardcodes*. | REQ-VID-TXT-008, REQ-VID-TXT-009, REQ-VID-TXT-011 |
| Encadeamento de ferramentas e processamento em lote | Não | Operação de fim de cadeia (aplicação de metadados ou grafismo final). Processado atonicamente no MVP. | N/A |

### 4.2 Impacto no sistema existente

| **Elemento existente afetado** | **Impacto (Manter / Estender / Alterar)** | **Descrição do impacto** | **Requisito(s) relacionado(s)** |
|--------------------------------|-------------------------------------------|--------------------------|--------------------------------|
| Interface do utilizador (Canvas Textual) | Estender | O gestor de texto de imagens terá de ser ancorado à biblioteca de reprodução de vídeo para injetar variáveis de tempo ($t_{\text{in}}$/$t_{\text{out}}$) associadas a cada DOM element de texto. | REQ-VID-TXT-001, REQ-VID-TXT-003 |
| Motor de Composição Assíncrona (*Workers*) | Alterar | O backend de processamento de imagem tem de incorporar filtros FFmpeg dedicados a texto (`drawtext` para queimar imagem ou módulos de cópia de *streams* de subtítulos para os contentores de saída). | REQ-VID-TXT-006, REQ-VID-TXT-007, REQ-VID-TXT-010 |
| Módulo de Controlo de Acessos e Quotas | Estender | Introduzir novas chaves limitativas na API: validação de quantidade máxima de chaves na matriz JSON de submissão (limite 20) e restrição da *flag* de exportação para contas não-premium. | REQ-VID-TXT-008, REQ-VID-TXT-009, REQ-VID-TXT-011 |

### 4.3 Matriz de Rastreabilidade Atualizada

| **Elemento de origem** | **Descrição abreviada** | **Requisito(s) relacionado(s)** |
|------------------------|-------------------------|--------------------------------|
| Passo 1 | Exibição da interface de texto integrada com *timeline* | REQ-VID-TXT-001 |
| Passo 2 | Edição, posicionamento espacial e WYSIWYG no reprodutor | REQ-VID-TXT-002 |
| Passo 3, FA2 | Inserção demarcada de blocos concorrentes | REQ-VID-TXT-001, REQ-VID-TXT-003 |
| Passo 4, E3, RN1 | Opções de exportação segregadas (Premium=Soft, Registado=Hard) | REQ-VID-TXT-008 |
| Passo 6 | Fluxo de queima destrutiva (*re-encoding* visual do texto) | REQ-VID-TXT-006 |
| Passo 6 | Fluxo de multiplexagem (*metadata streams*) de legendas | REQ-VID-TXT-007 |
| Passo 7, RN4 | Dedução de quota transacional na finalização do clip | REQ-VID-TXT-011 |
| FA1, RN3 | Ferramenta de injeção automática de standard `.srt`/`.vtt` | REQ-VID-TXT-004 |
| E1 | Validação de higienização de *encoding* (anti-mojibake) | REQ-VID-TXT-005 |
| E2, Garantia Mínima, DQ-002 | Graceful termination em caso de falha no render da tipografia | REQ-VID-TXT-010 |
| RN2 | Regra de limitação de esforço (Max 20 blocos não-Premium) | REQ-VID-TXT-009 |
| Secção 4.1.3, DQ-001 | Transparência de *status* da infraestrutura por CPU limit | REQ-VID-TXT-012, REQ-VID-TXT-013 |

**Decisões de qualidade introduzidas nesta aula**

| **ID** | **Decisão de qualidade** | **Justificação** | **Requisito(s) relacionado(s)** |
|--------|--------------------------|-----------------|--------------------------------|
| DQ-001 | Estabelecer modo *Hardcode* como fallback obrigatório para contas base. | Nem todos os dispositivos/leitores web processam *Soft-subs* de forma idêntica (podendo desformatar cores e fontes). O *Hardcode*, apesar de ser mais pesado no servidor, garante fidelidade absoluta de design para o utilizador padrão. | REQ-VID-TXT-006, REQ-VID-TXT-013 |
| DQ-002 | Tratamento estrito de erros do motor de texto (FFmpeg `drawtext`) como falhas seguras. | Incompatibilidades Unicode entre o texto introduzido e a fonte TTF/OTF escolhida corrompem o comando de *render*. É imperativo falhar cedo e alertar o utilizador em vez de entregar um vídeo com "quadrados pretos" (*tofus*). | REQ-VID-TXT-010 |