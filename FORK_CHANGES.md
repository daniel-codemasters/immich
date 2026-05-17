<!-- ----------- daniel ------------- -->

# Alterações do fork

Este arquivo documenta as customizações deste fork do Immich em relação ao
projeto upstream. Cada entrada descreve **o quê**, **por quê**, **arquivos
tocados** e **como verificar/reaplicar** — para sobreviver às atualizações do
Immich.

## Permissões do git no devcontainer

Se o `git add`/commit falhar com:

> `error: insufficient permission for adding an object to repository database .git/objects`

é porque arquivos em `.git/` ficaram com dono `root` (o git rodou como `root`
em algum momento) e o devcontainer mobile roda como `node`. Corrija rodando
**no host** da instância (não no terminal do VSCode, que é `node` e não tem
permissão):

```bash
# 1. devolve o dono de todo o .git para o node (precisa de root -> -u 0)
docker exec -u 0 immich_server chown -R node:node /usr/src/app/.git

# 2. evita repetir: novos objetos passam a ser graváveis por qualquer usuário
docker exec -u 0 immich_server git config -f /usr/src/app/.git/config core.sharedRepository 0777
```

Verificar (não deve imprimir nada):

```bash
docker exec -u 0 immich_server find /usr/src/app/.git ! -user node
```

Notas:

- Para corrigir o workspace inteiro (não só o `.git`), troque `/usr/src/app/.git`
  por `/usr/src/app`.
- Se o container não se chamar `immich_server`: `docker ps --format '{{.Names}}'`.
- Para não reincidir, faça commits sempre pelo mesmo devcontainer/usuário.

## Convenção de marcação

Toda alteração nossa fica dentro de um bloco marcado, usando o caractere de
comentário da linguagem do arquivo:

```ts
// ----------- daniel -------------
<nossas alterações>
// ---------------------------------
```

- `//` em TS/JS/Svelte, `--` em SQL, `<!-- -->` em Markdown, `#` em YAML/`mise.toml`.
- Vale para linhas **adicionadas e modificadas**.
- Arquivos 100% nossos (ex.: a migration, `DeviceLabelsEditor.svelte`, este arquivo)
  levam apenas um cabeçalho marcador no topo.
- `i18n/*.json` não aceita comentários — as chaves novas usam prefixo identificável.
- Arquivos gerados (`open-api/`, `packages/sdk/`, `mobile/openapi/`) não são
  marcados; são reproduzidos por `mise //:open-api`.

**Listar todas as alterações marcadas:**

```bash
git grep -l -F -e "----------- daniel"      # arquivos
git grep -n -F -e "----------- daniel"      # linha a linha
```

## Reaplicar após atualizar o upstream

1. Faça o merge/rebase do upstream normalmente.
2. Conflitos nos arquivos abaixo: resolva preservando os blocos `daniel`.
3. **Não** resolva conflitos em arquivos gerados — regenere com `mise //:open-api`
   após o servidor compilar.
4. Se o upstream mexer no schema, confira se a migration do fork ainda aplica.
5. Rode a verificação descrita em cada entrada.

---

## 1. Storage Template — pastas separadas por dispositivo (`{{device}}`)

**Commit:** `34b4347ae` · **Branch:** `dev`

### Motivação

Uma única conta do Immich é compartilhada por dois celulares (marido e esposa).
O objetivo é que as fotos de cada aparelho fiquem em pastas distintas no disco.
O Storage Template não tinha nenhuma variável que identificasse o aparelho, e o
Immich **removeu de propósito** os campos `deviceId`/`deviceAssetId` da tabela
`asset` no PR upstream #27818.

### O que faz

- Reintroduz a coluna `asset.deviceId` (nullable). O app mobile já envia esse
  identificador (FlutterUdid) no upload — só não era mais lido pelo servidor.
- Nova variável de Storage Template **`{{device}}`**, que resolve para um nome
  amigável definido pelo admin (sanitizado igual a `{{album}}`). Aparelho sem
  mapeamento → valor vazio (sem segmento de pasta).
- O admin mapeia `deviceId → nome` na seção **Device folders** das configurações
  de Storage Template.
- Novo endpoint `GET /system-config/storage-template-devices` lista os aparelhos
  que já fizeram upload (id, contagem de assets, último upload), para popular o mapa.

### Como usar

1. Ative o Storage Template no admin.
2. Faça upload de ≥1 foto de cada celular pelo app Immich.
3. Em **Administration → Settings → Storage Template → Device folders**, cada
   aparelho aparece automaticamente. Identifique qual é qual pela data do último
   upload / contagem e digite o nome (ex.: `Daniel`, `Maria`).
4. Use `{{device}}` no template. Recomendado, com fallback para fotos antigas
   (que não têm `deviceId`) e aparelhos não mapeados:

   ```
   {{#if device}}{{device}}{{else}}Compartilhado{{/if}}/{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}
   ```

5. Rode o job **Storage Template Migration** para aplicar a assets já existentes.

### Migração de banco

`server/src/schema/migrations/1778968836203-AddAssetDeviceId.ts` — adiciona a
coluna `asset.deviceId` (`character varying`, nullable). Roda automaticamente na
inicialização do servidor.

### Arquivos alterados

**Schema / banco**

- `server/src/schema/tables/asset.table.ts` — coluna `deviceId`
- `server/src/schema/migrations/1778968836203-AddAssetDeviceId.ts` — _(novo)_

**Captura no upload**

- `server/src/dtos/asset-media.dto.ts` — campo `deviceId` no upload
- `server/src/services/asset-media.service.ts` — grava `deviceId` no asset

**Render do template / variável `{{device}}`**

- `server/src/services/storage-template.service.ts` — variável, resolução do
  nome amigável, endpoint de descoberta
- `server/src/types.ts` — `deviceId` no tipo `StorageAsset`
- `server/src/repositories/asset-job.repository.ts` — `deviceId` na query

**Config / mapa `deviceLabels`**

- `server/src/config.ts` — `storageTemplate.deviceLabels`
- `server/src/dtos/system-config.dto.ts` — schema do mapa + DTO de descoberta

**Endpoint de descoberta**

- `server/src/repositories/asset.repository.ts` — `getDistinctDeviceIds()`
- `server/src/controllers/system-config.controller.ts` — `GET /system-config/storage-template-devices`

**Web**

- `web/src/lib/components/admin-settings/DeviceLabelsEditor.svelte` — _(novo)_ editor do mapa
- `web/src/lib/components/admin-settings/StorageTemplateSettings.svelte` — integra o editor + preview
- `web/src/lib/components/admin-settings/SupportedVariablesPanel.svelte` — documenta `{{device}}`

**Outros**

- `server/src/dtos/asset-response.dto.ts` — `deviceId` no tipo `MapAsset`
- `i18n/en.json` — chaves `admin.storage_template_device_*`
- `docs/docs/partials/_storage-template.md` — documentação da variável
- Testes: `server/test/factories/asset.factory.ts`, `server/test/mappers.ts`,
  `server/test/repositories/asset.repository.mock.ts`, e os specs
  `storage-template.service.spec.ts` / `asset-media.service.spec.ts` /
  `system-config.service.spec.ts`

**Gerados (regenerar, não editar à mão):** `open-api/immich-openapi-specs.json`,
`packages/sdk/src/fetch-client.ts`, `mobile/openapi/**`.

### Ressalvas

- Só vale para uploads feitos **depois** deste deploy — assets antigos têm
  `deviceId` nulo e somem na pasta de fallback.
- O `deviceId` é um UDID opaco; não é exibido no app. Identifica-se pela
  atividade de upload na tela de Device folders.
- Mudança exclusiva do fork — não será aceita upstream e precisa ser reaplicada
  a cada atualização do Immich.

### Verificação

```bash
cd server && pnpm run check && pnpm test storage-template
pnpm run test:medium                       # precisa de Docker (Postgres)
cd ../web && pnpm run check:svelte && pnpm run check:typescript
mise //:open-api                           # regenera spec + SDKs
```

---

## 2. Configuração do devcontainer + Claude Code

**Commit:** `5374132d4` · **Branch:** `dev`

### O que faz

- Fixa `CLAUDE_CONFIG_DIR` em `/usr/src/app/.claude` (bind-mount do host) nos
  dois devcontainers, para a config do Claude Code sobreviver a rebuilds.
- Adiciona `.devcontainer/devcontainer-lock.json` e o `CLAUDE.md` do projeto.
- Adiciona `/.claude/` ao `.gitignore` — o diretório guarda credenciais,
  sessões e memória e **não pode ser commitado**.

### Arquivos alterados

- `.devcontainer/devcontainer.json`, `.devcontainer/mobile/devcontainer.json`
- `.devcontainer/devcontainer-lock.json` — _(novo)_
- `CLAUDE.md` — _(novo)_
- `.gitignore`

---

## 3. Toolchain mobile no devcontainer (Flutter 3.41.9 + Android SDK)

**Branch:** `dev` · _(pendente de commit)_

### Motivação

O devcontainer mobile não consegue compilar nem rodar o app:

- A imagem traz **Flutter 3.35.7** embutido (`server/Dockerfile.dev`, target
  `dev-container-mobile`), mas o projeto exige Dart ≥ 3.11 — `mobile/mise.toml`
  fixa **Flutter 3.41.9**.
- A imagem só tem **JRE** (sem `javac`); builds Gradle precisam de um JDK.
- Não há **Android SDK** nem `adb`.
- O `mise` (que instalaria a versão certa do Flutter) **não está instalado**
  neste container.

### O que faz

- Script idempotente `.devcontainer/mobile/install-mobile-toolchain.sh` instala
  a toolchain em **`/usr/src/app/.mobile-tools/`** — pasta no bind-mount do host
  (sobrevive a rebuilds) e gitignored:
  - `flutter/` — Flutter 3.41.9 (fica à frente do `/flutter` da imagem no `PATH`)
  - `jdk-21/` — Temurin JDK 21
  - `android-sdk/` — platform-tools (`adb`), `platforms;android-36`, `build-tools;36.0.0`
  - `android-user/`, `gradle/`, `pub-cache/` — chaves do adb e caches de build persistentes
  - `gradle/gradle.properties` — limita a memória de Gradle/Kotlin (ver Ressalvas)
  - `env.sh` — exporta as variáveis (gerado pelo script)
- Ligado como **`postCreateCommand`** no `devcontainer.json`: um clone novo
  provisiona tudo sozinho no build do container; um checkout que já tem a pasta
  pula em segundos (o script é idempotente).
- O `devcontainer.json` (`remoteEnv`) exporta `FLUTTER_HOME`, `JAVA_HOME`,
  `ANDROID_HOME`, `GRADLE_USER_HOME`, `PUB_CACHE`, `PATH` etc. — ativos
  automaticamente após um rebuild.
- `/.mobile-tools/` adicionado ao `.gitignore`.

### Como rodar o app

1. **Ambiente.** Após um *Rebuild Container* as variáveis já valem. Num terminal
   aberto **antes** do rebuild, carregue manualmente:

   ```bash
   source /usr/src/app/.mobile-tools/env.sh
   which flutter   # deve apontar para .mobile-tools/flutter/bin/flutter
   ```

2. **Conectar o celular Android (ADB sem fio)** — celular e host na mesma rede:
   - No celular: Opções de desenvolvedor → **Depuração sem fio**.
   - "Parear dispositivo com código de pareamento" → anote `IP:PORTA` e o código.

   ```bash
   adb pair <IP>:<PORTA_PAREAMENTO> <CÓDIGO>
   adb connect <IP>:<PORTA_CONEXÃO>   # porta da tela principal, ≠ a de pareamento
   adb devices
   ```

3. **Rodar.** O `postCreateCommand` já roda `pub get` + codegen de i18n; para
   refazer à mão (os arquivos de i18n em `mobile/lib/generated/` não são
   commitados):

   ```bash
   cd mobile
   flutter pub get
   dart run easy_localization:generate -S ../i18n
   dart run bin/generate_keys.dart
   flutter run
   ```

   Para gerar **apenas o APK** (instalação manual), em vez de `flutter run`:

   ```bash
   flutter build apk --debug --target-platform android-arm64
   adb install -r build/app/outputs/flutter-apk/app-debug.apk
   ```

4. **Login no app.** O `immich-server` é publicado na porta `2283` do host —
   no app use `http://<IP-DO-HOST-NA-LAN>:2283`.

### Arquivos alterados

- `.devcontainer/mobile/install-mobile-toolchain.sh` — _(novo)_ instalador idempotente
- `.devcontainer/mobile/devcontainer.json` — `postCreateCommand` + `remoteEnv` (Flutter/Android/JDK/caches)
- `.gitignore` — ignora `/.mobile-tools/`

### Ressalvas

- `.mobile-tools/` é local da máquina (~3.3 GB) e nunca é commitado.
- A imagem continua trazendo Flutter 3.35.7 em `/flutter`; o `PATH` do fork o
  ignora — não foi removido para não tocar no `Dockerfile.dev` compartilhado.
- Se um build Gradle reclamar de **NDK ausente**, instale a versão pedida:
  `sdkmanager "ndk;<versão>"`.
- Ao atualizar o Flutter do projeto, sincronize `FLUTTER_VERSION` no script com
  `mobile/mise.toml`.
- O build mobile é pesado de RAM e o devcontainer ainda roda o stack Immich
  inteiro (host de ~8 GB). `gradle/gradle.properties` (gerado em `.mobile-tools/`)
  limita os heaps de Gradle/Kotlin e compila Kotlin _in-process_ para não tomar
  OOM. Se ainda faltar memória, pare os containers do Immich durante o build ou
  dê mais RAM ao Docker.
- Mudança exclusiva do fork — reaplicar a cada atualização do upstream.

### Verificação

```bash
bash .devcontainer/mobile/install-mobile-toolchain.sh   # idempotente
source /usr/src/app/.mobile-tools/env.sh
flutter --version       # 3.41.9
flutter doctor          # Android toolchain [✓]
```

---

## 4. App mobile — botão "Copy device ID" na tela de login

**Branch:** `dev` · _(pendente de commit)_

### Motivação

A variável `{{device}}` (seção 1) exige que o admin mapeie `deviceId → nome` na
tela Device folders do servidor. O `deviceId` é um UDID opaco e não era exibido
em lugar nenhum do app — só dava para adivinhar pela atividade de upload. Este
botão expõe o id para copiar.

### O que faz

- Na tela de login, no passo em que se informa a **URL do servidor**, adiciona
  um botão **"Copy device ID"** que copia para a área de transferência o mesmo
  identificador que o app envia como `asset.deviceId`
  (`FlutterUdid.consistentUdid`, com fallback no `StoreKey.deviceId` salvo). Um
  toast confirma o valor copiado.

### Como usar

1. Em cada celular, na tela inicial do app (campo da URL do servidor), toque em
   **Copy device ID**.
2. Cole o id em **Administration → Settings → Storage Template → Device
   folders** do servidor e dê um nome ao aparelho.

### Arquivos alterados

- `mobile/lib/widgets/forms/login/login_form.dart` — import do `flutter_udid`,
  hook que resolve o device id, função `copyDeviceId` e o botão `ImmichTextButton`.

### Ressalvas

- Rótulo fixo em inglês (`Copy device ID`) — não passa por i18n.
- Requer rebuild do app (`flutter build apk --debug --target-platform android-arm64`).
- Mudança exclusiva do fork — reaplicar a cada atualização do upstream.

---

## 5. App mobile — data de corte para o backup (`backupCutoffDate`)

**Branch:** `dev` · _(pendente de commit)_

### Motivação

O backup do app envia toda a biblioteca das galerias selecionadas. Quem já tem
outro backup das fotos antigas acaba reenviando tudo. Esta opção permite definir
uma data a partir da qual as fotos devem ser enviadas.

### O que faz

- Nova configuração **"Only back up photos from"** em **Settings → Backup →
  Backup cutoff date**: um seletor de data. Fotos tiradas **antes** da data são
  ignoradas pelo backup. Um botão limpa o corte (volta para "All photos").
- O filtro usa o `createdAt` do asset local e vale para o backup em primeiro e
  em segundo plano (ambos passam por `getCandidates`).
- A contagem da tela de backup (`getAllCounts`) também respeita o corte, então
  total/restante batem com o que será de fato enviado.
- Persistido como epoch millis em `AppSettingsEnum.backupCutoffDate`
  (`StoreKey.backupCutoffDate`, id `142`); `0` = sem corte (comportamento padrão).

### Como usar

1. **Settings → Backup → Backup cutoff date → Only back up photos from**.
2. Escolha a data a partir da qual as fotos devem ser enviadas.
3. As fotos anteriores ficam de fora. Toque no **X** para remover o corte.

### Arquivos alterados

- `mobile/lib/domain/models/store.model.dart` — `StoreKey.backupCutoffDate` (id 142)
- `mobile/lib/services/app_settings.service.dart` — `AppSettingsEnum.backupCutoffDate`
- `mobile/lib/infrastructure/repositories/backup.repository.dart` — helper
  `_backupCutoff()` e filtro por data em `getCandidates` e `getAllCounts`
- `mobile/lib/widgets/settings/backup_settings/drift_backup_settings.dart` — tile
  `_BackupCutoffDateTile` (seletor de data)

### Ressalvas

- Filtra pela data de criação (`createdAt`) do asset no dispositivo.
- Não mexe em fotos já enviadas — só deixa de selecionar candidatos; nada é apagado.
- Rótulos fixos em inglês — não passa por i18n.
- A contagem na tela de backup pode ficar desatualizada até a tela recarregar
  após a mudança da data.
- Requer rebuild do app.
- Mudança exclusiva do fork — reaplicar a cada atualização do upstream.

<!-- ----------- daniel ------------- -->
