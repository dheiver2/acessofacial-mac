# Acesso Facial

Software nativo de reconhecimento facial para macOS — controle de acesso por câmera, 100% local, sem dependências externas (Python, CoreML de terceiros, nuvem). Escrito em Swift/SwiftUI, usando apenas frameworks do sistema (AVFoundation + Vision).

## Funcionalidades

- **Monitor**: câmera ao vivo com detecção de rosto (caixa delimitadora) e identificação em tempo real — libera (verde), nega por rosto desconhecido/não cadastrado (amarelo) ou nega por confiança baixa (vermelho).
- **Cadastrar**: captura 1–5 amostras do rosto de uma pessoa, com nome, cargo e nível de acesso (Administrador / Colaborador / Visitante).
- **Pessoas**: lista, ativa/desativa e remove cadastros.
- **Registros**: log de tentativas de acesso (liberado/negado), com miniatura, horário e confiança — para auditoria.
- **Configurações**: limiar de confiança do reconhecimento, seleção de câmera.

## Como funciona (técnico)

- **Detecção**: `VNDetectFaceLandmarksRequest` (Vision) localiza rostos e pontos faciais em cada quadro da câmera.
- **Reconhecimento**: o rosto detectado é recortado e passado por `VNGenerateImageFeaturePrintRequest`, gerando uma assinatura (embedding) da imagem. A assinatura ao vivo é comparada por distância (`computeDistance`) contra as assinaturas cadastradas; a menor distância acima do limiar configurado libera o acesso.
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
