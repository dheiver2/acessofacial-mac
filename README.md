# Acesso Facial

Software nativo de reconhecimento facial para macOS — controle de acesso por câmera, 100% local, sem dependências externas (Python, CoreML de terceiros, nuvem). Escrito em Swift/SwiftUI, usando apenas frameworks do sistema (AVFoundation + Vision).

## Funcionalidades

- **Monitor**: câmera ao vivo com reconhecimento de **múltiplos rostos simultâneos** (cada rosto com nome e confiança). O rosto principal (mais próximo) dirige a decisão de acesso — libera (verde), nega (vermelho) ou marca desconhecido (amarelo).
- **Anti-spoofing (prova de vida)**: exige piscada/movimento antes de liberar, bloqueando ataque com foto ou vídeo estático. Configurável.
- **Watchlist**: cada pessoa pode ser marcada como **Normal**, **Alerta** (libera + notifica) ou **Bloqueada** (nega + alarme). Ao detectar uma pessoa em watchlist em qualquer rosto do quadro, dispara **som + notificação do sistema**.
- **Cadastrar**: captura 1–5 amostras do rosto, com nome, cargo, nível de acesso e situação de watchlist.
- **Pessoas**: lista, busca, ativa/desativa, altera situação (watchlist) e remove cadastros.
- **Registros**: log de acessos (liberado/negado/bloqueado/alerta/desconhecido) com miniatura, horário e confiança. **Busca**, **filtro por resultado** e **exportação CSV** para auditoria.
- **Configurações**: limiar de confiança, liga/desliga prova de vida e som de alertas, seleção de câmera.

## Como funciona (técnico)

- **Detecção**: `VNDetectFaceLandmarksRequest` (Vision) localiza rostos e pontos faciais em cada quadro da câmera.
- **Reconhecimento**: o rosto detectado é recortado e passado por `VNGenerateImageFeaturePrintRequest`, gerando uma assinatura (embedding) da imagem. A assinatura ao vivo é comparada por distância (`computeDistance`) contra as assinaturas cadastradas; a menor distância acima do limiar configurado libera o acesso.
- **Prova de vida**: variação da abertura ocular (via landmarks) ao longo de uma janela curta — rosto vivo pisca/move, foto estática não. Cobre o ataque de apresentação mais comum (foto impressa / tela de celular).
- **Persistência**: pessoas, amostras (assinaturas arquivadas via `NSSecureCoding`) e log de acesso são salvos como JSON em `~/Library/Application Support/AcessoFacial/`. Nenhum dado sai da máquina.

## Build

Requer apenas as Command Line Tools (não precisa do Xcode completo):

```bash
bash build_app.sh              # gera "~/Desktop/Acesso Facial.app" (release)
bash build_app.sh --debug      # build de debug
```

Primeira execução: clique direito → Abrir (app assinado ad-hoc, não notarizado).

## Testes

```bash
bash run_tests.sh              # testes de sanidade headless (sem câmera)
```

## Privacidade

Todo o processamento (detecção, reconhecimento, armazenamento) roda localmente no Mac. Nenhuma imagem, rosto ou dado biométrico é enviado para servidores externos.
