<p align="center"><img src="docs/icon.png" width="128" alt="Ícone do FixMacAudioInput"></p>

# FixMacAudioInput

**Impede o macOS de trocar seu microfone (e alto-falantes) toda vez que você conecta um fone.**

[English](README.md)

Sempre que você conecta AirPods, um headset Bluetooth ou um dongle USB, o macOS transforma o
aparelho na **entrada** e na **saída** padrão sem perguntar. Seu microfone bom vira o microfone do
fone e, no Bluetooth, o áudio cai para o "modo chamada", de baixa qualidade. O FixMacAudioInput é
um app nativo pequeno que fica na Dock e desfaz a troca na hora.

## O que faz

- **Desfaz trocas automáticas.** Quando o macOS troca para um aparelho que *acabou* de conectar, o
  app volta para o dispositivo que você usava antes.
- **Respeita suas escolhas.** Se você escolher um dispositivo (Ajustes de Som, barra de menus ou o
  próprio app), ele vira o novo preferido. Não tem nada para configurar.
- **Entrada e saída independentes.** Por padrão só a **entrada** fica fixa (o fone continua tocando
  o som). Ligue *Manter fixa* na saída se quiser.
- **Efeitos sonoros também.** Com a saída fixa, os sons de alerta também não vão para o aparelho
  novo.
- **Lembra de dispositivos desconectados.** Se o mic USB preferido for desplugado, o macOS usa
  outro; quando o mic volta, o app o restaura.
- **Fica na Dock.** Fechar a janela não encerra o app. Clique com o botão direito no ícone para
  pausar.
- **Abrir ao iniciar sessão**, histórico de tudo que fez e log em
  `~/Library/Logs/FixMacAudioInput.log`.
- **Idiomas:** English, Português (Brasil), Español, Français, Deutsch. Segue o idioma do sistema
  ou o ajuste por app em Ajustes do Sistema › Geral › Idioma e Região.
- Swift/SwiftUI nativo, binário universal (Apple silicon + Intel), sem rede, sem acesso ao
  microfone, sem dependências.

## Instalação

1. Baixe o `FixMacAudioInput-x.y.z.dmg` (ou `.zip`) mais recente em [Releases](../../releases).
2. Arraste o **FixMacAudioInput** para **Aplicativos** e abra.
3. O app **não é notarizado** (assinatura ad-hoc), então o Gatekeeper bloqueia a primeira
   abertura. Clique com o botão direito no app › **Abrir** › **Abrir**, ou vá em Ajustes do Sistema
   › Privacidade e Segurança › **Abrir Mesmo Assim**. Ou no Terminal:

   ```sh
   xattr -dr com.apple.quarantine /Applications/FixMacAudioInput.app
   ```

4. Opcional: ligue **Abrir ao iniciar sessão** na janela.

Requer macOS 14 Sonoma ou mais recente.

## Como funciona

O app escuta as propriedades do CoreAudio `kAudioHardwarePropertyDevices`,
`kAudioHardwarePropertyDefaultInputDevice`, `kAudioHardwarePropertyDefaultOutputDevice` e
`kAudioHardwarePropertyDefaultSystemOutputDevice`.

| Evento | O que o app faz |
|---|---|
| O padrão muda para um aparelho visto pela primeira vez **há menos de 8 s** | Troca automática → volta para o preferido |
| O padrão muda para um aparelho que já estava conectado | Escolha sua → vira o preferido |
| O preferido desconecta | Mantém a preferência e restaura quando ele voltar |
| Proteção pausada ou *Manter fixa* desligado | Só acompanha o que estiver selecionado |

Efeito colateral: se você escolher manualmente um aparelho nos primeiros 8 segundos depois de
conectá-lo, o app entende como troca automática e desfaz. Espere alguns segundos ou escolha pela
janela do app.

## Compilar

Precisa do Xcode (ou Command Line Tools) com Swift 5.9+.

```sh
./build.sh              # build/FixMacAudioInput.app + build/simulate_plug
./build.sh --install    # também copia o app para /Applications
./build.sh --package    # também gera dist/*.zip, dist/*.dmg e SHA-256
SIGN_IDENTITY="Developer ID Application: Você (TEAMID)" ./build.sh --package
```

Não há projeto Xcode: o `build.sh` chama o `swiftc` direto, compila as duas arquiteturas e monta o
bundle (ícone, traduções, Info.plist, assinatura).

## Testar

O `build/simulate_plug` cria um dispositivo agregado público temporário (o macOS o vê como um
aparelho recém-conectado), define-o como padrão do mesmo jeito que o macOS faz com fones e verifica
o que o app fez. O padrão anterior é restaurado no final.

```sh
open build/FixMacAudioInput.app --args -protectOutput YES   # fixa a saída só nesta execução
build/simulate_plug input auto      # esperado: PASS: automatic switch undone
build/simulate_plug input manual    # esperado: PASS: manual choice respected (troca após 10 s)
build/simulate_plug output auto
build/simulate_plug output manual
```

## Licença

[MIT](LICENSE) © 2026 Pedro Beraldo. Sem vínculo com a Apple.
