#import "../template.typ": *

= Implementação Assistida por Agentes de IA

== Ferramentas, modelos e configuração

#tabela(
  colunas: (3.5cm, 1fr),
  [Ferramenta / modelo], [Configuração e utilização],
  [Google Gemini], [Chat, sem configuração própria. Usado na primeira versão, por funcionalidade, dos casos de uso e da especificação de requisitos (rascunhos em `requesitos/RAS-*.md`).],
  [Claude (Anthropic, Claude Opus 5.5) em claude.ai, com execução de código], [Sessão com acesso de leitura aos repositórios do grupo e da _baseline_, execução de FFmpeg, Node.js e Python num ambiente isolado. Instruções de projeto em `CLAUDE.md` na raiz da solução (convenções, rastreabilidade por comentários `REQ-VID-*`, testes obrigatórios). Sem _skills_ nem servidores MCP próprios. Não havia Docker nem acesso aos registos npm/PyPI no ambiente, pelo que a solução completa não foi executada pelo agente.],
)

== Tarefas apoiadas e validação

#tab([Tarefas apoiadas por agentes de IA e validação],
  tabela(
    colunas: (2.4cm, 2cm, 1fr, 1fr, 2.6cm),
    tamanho: 8.5pt,
    [Ferramenta], [Caso de uso], [Tarefa apoiada], [Validação realizada], [Evidência],
    [Gemini], [UC-VID-001 a 005], [Primeira versão dos fluxos, exceções, regras por perfil e requisitos de cada funcionalidade.], [Revisão manual pela equipa (terminologia, limites por perfil, garantias mínimas).], [`requesitos/RAS-*.md`],
    [Claude], [Todos], [Revisão dos Capítulos 2 a 5 face às diretrizes e ao documento de base: referências ALT erradas, contradições entre casos de uso e requisitos, requisitos em falta e repetidos, classificação ISO 25010; proposta de resolução das questões em aberto.], [Verificação automática de que não há requisitos órfãos nem referências a IDs inexistentes (script); decisões analisadas e aceites pela equipa.], [_Commit_ `656f1a4` (#link("https://github.com/icsousa/RAS")[`icsousa/RAS`])],
    [Claude], [Todos], [Diagrama de casos de uso, modelo de domínio, vista de componentes e diagrama de sequência (PlantUML).], [Comparação com os casos de uso e as regras de negócio; diagramas aceites pela equipa.], [`images/src/*.puml`],
    [Claude], [UC-VID-001 a 005], [Worker `Tools/video` (FFmpeg) e respetivos testes.], [33 testes automáticos com FFmpeg real, incluindo medições de desempenho (Capítulo 10); execução das cinco operações na aplicação pela equipa (TST-UI-01 a 05).], [_Commit_ `656f1a4` (#link("https://github.com/icsousa/RAS")[`icsousa/RAS`]); `picturas-27/CLAUDE.md`],
    [Claude], [Todos], [Módulo de vídeo do `projects` (regras, serviço, rotas, adaptadores), API Gateway, WS Gateway, nginx, RabbitMQ e compose.], [23 testes `node --test` da lógica com dependências simuladas; verificação de sintaxe dos restantes ficheiros; execução pela equipa da stack completa com `docker compose up --build` e dos testes TST-E2E-01 a 04.], [Idem],
    [Claude], [Todos], [Página de vídeo do frontend (Next.js).], [Verificação de tipos parcial com TypeScript e tipos simulados; compilação na imagem Docker e testes manuais TST-UI-01 a 05 pela equipa.], [Idem],
    [Claude], [—], [Identificação e correção de defeitos da _baseline_ (Capítulo 11).], [Reprodução do defeito T-01 com uma simulação do `ToolMSG`; correções incluídas na stack testada pela equipa.], [Idem],
  ),
)

== Análise crítica

O agente foi mais útil nas tarefas com uma verificação objetiva: rastreabilidade (um _script_ detetou órfãos e referências inválidas), e código com testes executáveis contra o FFmpeg real. Nas decisões de requisitos o contributo foi o de identificar inconsistências e propor resoluções; as decisões finais cabem à equipa.

Erros do agente detetados durante o trabalho, e como foram detetados:

- *Quota do Anónimo.* A primeira versão da RNG-01 assumia que o Anónimo tinha um limite diário. A leitura do serviço `users` mostrou que na _baseline_ o Anónimo não tem contador e que o limite de 5 só se aplica às ferramentas de IA; a regra, os requisitos e os capítulos 2 e 6 foram corrigidos.
- *Limite de memória.* A primeira implementação usava `RLIMIT_AS`; o teste TST-STATUS-02 mostrou que o FFmpeg ficava bloqueado em vez de falhar. Foi substituída pela medição da memória residente (DA-08).
- *Fins de linha.* Ao editar quatro ficheiros da _baseline_ com fins de linha CRLF, o agente converteu-os para LF, o que produzia _diffs_ de centenas de linhas. Detetado na revisão do _diff_ e corrigido.
- *Dados de teste.* Um teste de reverter/_reset_ usava um recorte fora da duração do vídeo; a falha do teste revelou o erro no teste, não no código.
- *Projeto só com vídeos.* Nos testes manuais, a equipa verificou que não era possível chegar à página de vídeo sem criar um projeto com pelo menos uma imagem (restrição herdada da _baseline_). A criação de projetos passou a exigir apenas o nome e, sem imagens, abre diretamente a página de vídeos.
- *Erros herdados dos rascunhos.* As referências ALT para RF48, RF20 e RF15 vinham dos rascunhos por funcionalidade e não correspondiam ao documento de base.

Limitação do agente: no seu ambiente não havia Docker nem acesso aos registos de pacotes, pelo que não compilou o frontend nem lançou a stack completa. Esses passos foram feitos pela equipa: a solução foi construída e executada com `docker compose up --build`, os testes automáticos foram corridos nos contentores e os 9 testes manuais do Capítulo 10 foram executados na aplicação, um dos quais falhou (TST-E2E-02, tempo de resposta). Os problemas encontrados nos testes foram reportados ao agente e corrigidos antes de voltar a testar.
