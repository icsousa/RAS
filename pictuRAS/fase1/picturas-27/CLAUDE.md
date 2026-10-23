# Instruções de projeto para agentes de IA (PictuRAS, Fase 1 — vídeo)

Contexto: extensão de vídeo do PictuRAS (RAS 2026/2027, grupo PL3-G7). A especificação está no
relatório da Fase 1 (`doc-ext-requisitos.pdf`); cada alteração deve ser rastreável a um requisito
`REQ-VID-*`, a uma regra `RNG-*` ou a uma decisão `DA-*` / `DQ-*`.

## Regras
- Estender, não reescrever: não alterar `projects/routes/projects.js` exceto para correções
  identificadas (T-nn) ou para ligar o módulo de vídeo.
- Os limites por perfil vivem apenas em `projects/utils/videoRules.js` (fonte única).
- O worker `Tools/video` recebe parâmetros já validados, mas volta a validar o essencial.
- Indicar nos comentários os requisitos realizados (e.g. `// REQ-VID-TRIM-004`).
- Mensagens para o utilizador em português de Portugal.
- Todo o código novo tem testes: `Tools/video/tests` (unittest + FFmpeg real) e `projects/test`
  (`node --test`, sem dependências). Os IDs dos testes seguem `TST-{FUNC}-nn`.

## Validação pela equipa
- Rever cada diff antes de o integrar; correr os testes e o fluxo completo com `docker compose up --build`.
- Registar no Capítulo 9 do relatório o que foi gerado com IA, o que foi alterado e porquê.
