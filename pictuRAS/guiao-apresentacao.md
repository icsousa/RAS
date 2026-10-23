# Guião da defesa — Fase 1 (Grupo PL3-G7)

**Duração:** 10 minutos — caso de uso (3 min), dois requisitos (2 min), demonstração (5 min).
**Local:** DI 2.07, nos dias 26, 28 ou 29 de outubro, conforme a marcação no Calendly. Estar à porta **5 minutos antes**.

Atribuam um nome a cada letra antes do ensaio:

| Letra | Nome | Parte |
|---|---|---|
| A | ________ | Abertura e caso de uso (slides 1–3) |
| B | ________ | Os dois requisitos (slides 4–5) |
| C | ________ | Conduz o computador na demonstração |
| D | ________ | Explica a demonstração em voz alta |
| E | ________ | Conclusões (slide 7) e coordena as perguntas |

---

## Antes da sessão (no dia anterior e uma hora antes)

O aviso exige que **tudo esteja pronto num único computador**.

- [ ] Stack a correr em segundo plano: `docker compose up -d` (feito na véspera; **nunca** fazer o build no dia).
- [ ] Browser aberto em `https://localhost:8080`, certificado já aceite.
- [ ] **Conta Registado** com sessão iniciada, numa janela.
- [ ] **Conta Anónimo** numa janela anónima (para mostrar o separador desativado, se houver tempo).
- [ ] **Projeto A** com o `teste30.mp4` (1920×1080) carregado e ainda sem keyframes.
- [ ] **Projeto B** com um vídeo que já tem **5 keyframes definidos** (para o passo do 6.º keyframe).
- [ ] Um projeto com imagens e ferramentas (o aviso pede "projetos com multimédia e ferramentas").
- [ ] O contador de operações do Registado com pelo menos 2 operações disponíveis.
- [ ] **Uma operação de aquecimento** feita 10 minutos antes (a primeira é a mais lenta).
- [ ] Slides abertos noutro separador, em modo de apresentação.
- [ ] **Gravação de backup** da demonstração, aberta e pronta a tocar.
- [ ] Portátil ligado à corrente; notificações desligadas.

---

## Minuto a minuto

### 0:00 – 0:15 · Slide 1 (Título) — Pessoa A
> "Somos o grupo PL3-G7. No MVP implementámos cinco funcionalidades de vídeo. Hoje apresentamos a que consideramos mais importante: o Pan & Crop."

### 0:15 – 1:45 · Slide 2 (Caso de uso) — Pessoa A
> "O Pan & Crop permite escolher a moldura de corte em vários instantes do vídeo — os keyframes — e o sistema anima o enquadramento entre eles. Um uso típico é transformar um vídeo horizontal num vídeo vertical para redes sociais."

- Registado: até 5 keyframes. Premium: ilimitado.
- Anónimo sem acesso, porque é a operação mais pesada: o vídeo é processado fotograma a fotograma.
- Garantia mínima: "Se o processamento falhar, o vídeo original fica igual e a quota não é debitada."

### 1:45 – 3:00 · Slide 3 (Fluxo) — Pessoa A
> "O fluxo tem cinco passos. Os três primeiros — moldura, keyframes e pré-visualização — acontecem só no browser, sem custo no servidor. Ao aplicar, o pedido entra numa fila; um serviço dedicado com FFmpeg processa o vídeo e devolve o progresso em tempo real. No fim é criada uma nova versão."

- Fluxo alternativo: "Podemos editar ou remover um keyframe, e a interpolação é recalculada."
- Exceção: "A moldura não pode ser menor que 320×240, para evitar pixelização."

### 3:00 – 4:00 · Slide 4 (REQ-VID-CROP-002) — Pessoa B
> "O primeiro requisito é o núcleo do caso de uso: o sistema deve interpolar linearmente a posição e a dimensão da moldura entre keyframes consecutivos."

- Apontar para a tabela: "Com keyframes aos 0 e aos 4 segundos, a 2 segundos a moldura está exatamente a meio: [320, 180, 640, 360]."
- "É um requisito Must, verificado pelo teste automático TST-CROP-01, que passa."

### 4:00 – 5:00 · Slide 5 (REQ-VID-CROP-010) — Pessoa B
> "O segundo requisito liga o caso de uso ao modelo de negócio: um utilizador Registado tem no máximo 5 keyframes."

- Ler o critério Dado / Quando / Então.
- "Vem da regra RN1 do caso de uso. Validamos na interface e também no servidor, porque a interface pode ser contornada. É verificado pelo teste TST-CROP-05."
- Frase de transição: "Vamos ver isto a funcionar."

### 5:00 – 9:30 · Slide 6 (Demonstração) — Pessoa C no computador, Pessoa D a explicar

| Passo | Pessoa C faz | Pessoa D diz |
|---|---|---|
| 1 | Projeto A → Vídeos → Pan & Crop → rácio **9:16** | "Escolhemos o formato vertical." |
| 2 | Moldura à esquerda, keyframe aos 0 s; cursor aos 10 s, moldura à direita, keyframe | "Cada keyframe guarda o instante e a moldura." |
| 3 | **Pré-visualizar animação** e play | "Isto é só no browser — o servidor ainda não fez nada." |
| 4 | Projeto B → tentar adicionar o 6.º keyframe | "Aqui está o REQ-VID-CROP-010: bloqueado, com sugestão de Premium." |
| 5 | Voltar ao projeto A → **Aplicar** | "O pedido entrou na fila: Em fila, A processar, percentagem…" |
| 6 | Esperar por **Concluído**, dar play ao resultado | "O resultado é vertical. Foi criada uma nova versão e o original continua lá." |
| 7 | Mostrar o contador de operações e carregar em **Reverter** | "A operação foi descontada da quota diária, e podemos voltar à versão anterior." |
| 8 *(se houver tempo)* | Janela do Anónimo → separador Pan & Crop desativado | "Para o Anónimo, a ferramenta não está disponível." |

**Se algo falhar:** a Pessoa D diz "Vamos mostrar a gravação da mesma demonstração" e a Pessoa C abre o backup. Não tentem depurar à frente dos professores.

### 9:30 – 10:00 · Slide 7 (Conclusões) — Pessoa E
> "O caso de uso está implementado e verificado: 56 testes automáticos e 8 de 9 testes manuais passam. O que falha é o tempo de resposta da submissão, que demora mais de 2 segundos. Isto acontece porque o pedido espera pelo serviço de utilizadores e pelo RabbitMQ antes de responder. Na Fase 2 respondíamos primeiro. Obrigado, ficamos para as perguntas."

**Deixar este slide no ecrã durante as perguntas.**

---

## Perguntas prováveis

Cada pessoa responde às da sua área; as outras não interrompem.

| Pergunta | Quem | Resposta curta |
|---|---|---|
| Porque escolheram o Pan & Crop? | A | É o caso de uso mais exigente: junta tempo, espaço, perfis e processamento assíncrono. |
| Como é feita a interpolação no servidor? | B | Em Python com Pillow, fotograma a fotograma, com redimensionamento bilinear; não usámos o `zoompan` do FFmpeg porque não fazia exatamente a interpolação especificada (DA-07). |
| E se o worker morrer a meio? | D | A mensagem só é confirmada no fim, por isso volta para a fila; o original nunca é alterado. |
| Como funciona a quota? | B | Reserva uma operação ao criar o trabalho; se falhar ou for cancelado, é devolvida (RNG-01, DA-06). |
| Porque não é um microserviço novo? | D | O vídeo pertence a um projeto e precisa da mesma autenticação e armazenamento; seria duplicar tudo (DA-01). |
| Porque falha o teste dos 2 segundos? | E | O pedido espera pelo `users` e pelo RabbitMQ antes de responder; a correção é responder primeiro. |
| Como usaram a IA e como validaram? | E | Para especificação, código e testes; validámos com testes automáticos, testes manuais e revisão. Exemplo: os testes manuais encontraram que não era possível criar um projeto só com vídeos. |
| Mostrem onde está a regra dos 5 keyframes no código. | C | `projects/utils/videoRules.js`, caso `video_crop`, `maxKeyframes`. |

**Toda a gente deve saber:** o que é um keyframe, o que faz a fila `video_queue`, e onde estão os testes (`Tools/video/tests` e `projects/test`).

---

## Ensaios

- [ ] Ensaio 1 com cronómetro: cada parte dentro do tempo?
- [ ] Ensaio 2 no computador da apresentação, com a demonstração real.
- [ ] Gravação de backup feita durante o ensaio 2.
- [ ] Cada pessoa sabe as respostas da sua linha na tabela de perguntas.
