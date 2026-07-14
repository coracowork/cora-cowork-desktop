# Guia de Desenvolvimento — Windows (setup atual)

## Pré-requisitos

| Ferramenta   | Instalado em                          | Versão          |
| ------------ | ------------------------------------- | --------------- |
| Rust         | `D:\tools\rust\.cargo`                | stable GNU      |
| rustup       | `D:\tools\rust\.rustup`               | —               |
| MinGW-w64    | `C:\ProgramData\mingw64\mingw64\bin`  | gcc 14+         |
| Node.js      | Gerenciado pelo backend (v24.11.0)    | 24.11.0         |
| bun          | Necessário para o frontend            | —               |
| LLVM         | `D:\tools\LLVM`                       | 18.1.8          |

**Variáveis de ambiente obrigatórias** (User-level):

```powershell
RUSTUP_HOME = D:\tools\rust\.rustup
CARGO_HOME  = D:\tools\rust\.cargo
```

**Toolchain**: `stable-x86_64-pc-windows-gnu` (NÃO use MSVC — as SDK headers estão
incompletas neste PC). O `rust-toolchain.toml` já fixa essa toolchain.

**Cuidado com o disco C:** há apenas ~1.2 GB livres. Instalações do VS (Build Tools,
Community) e o cache do Rust devem ser redirecionados para D:.

---

## Repositórios

Ambos em `D:\Download\Cora Cowork UI Desktop\`:

```
D:\Download\Cora Cowork UI Desktop\
├── CoraCore 0.1.44\           ← Backend Rust (cora-cowork-app)
└── Cora Cowork UI Desktopre\  ← Frontend Electron (cora-cowork-desktop)
```

**Links**: https://github.com/coracowork/cora-cowork-desktop

---

## Quick Start

### 1. Build do Backend (CoraCore)

Abra PowerShell **como usuário normal** (não Admin) e execute:

```powershell
# Garantir que as variáveis de ambiente estejam na sessão
$env:RUSTUP_HOME = "D:\tools\rust\.rustup"
$env:CARGO_HOME = "D:\tools\rust\.cargo"
$env:Path = "D:\tools\rust\.cargo\bin;C:\ProgramData\mingw64\mingw64\bin;$env:Path"

cd "D:\Download\Cora Cowork UI Desktop\CoraCore 0.1.44"

# Compilar (usar +stable-x86_64-pc-windows-gnu explicitamente)
cargo +stable-x86_64-pc-windows-gnu build --release
```

O binário será gerado em:
`target\release\cora-cowork-app.exe`

> Se houver erro de "acesso negado" ao substituir o .exe, mate o processo
> antigo primeiro:
> ```powershell
> Get-Process -Name "cora-cowork-app" -ErrorAction SilentlyContinue | Stop-Process -Force
> ```

### 2. Verificar o binário

```powershell
where.exe cora-cowork-app
# ou diretamente:
& "D:\Download\Cora Cowork UI Desktop\CoraCore 0.1.44\target\release\cora-cowork-app.exe" --help
```

### 3. Iniciar o Frontend (Electron)

Abra um **novo terminal** (ou o mesmo, desde que o backend esteja no PATH):

```powershell
cd "D:\Download\Cora Cowork UI Desktop\Cora Cowork UI Desktopre"
bun install
bun run start
```

O Electron inicia o `cora-cowork-app.exe` automaticamente.

---

## Atualizando o Backend

Quando houver mudanças no CoraCore:

```powershell
# Matar processo antigo se estiver rodando
Get-Process -Name "cora-cowork-app" -ErrorAction SilentlyContinue | Stop-Process -Force

$env:RUSTUP_HOME = "D:\tools\rust\.rustup"
$env:CARGO_HOME = "D:\tools\rust\.cargo"
$env:Path = "D:\tools\rust\.cargo\bin;C:\ProgramData\mingw64\mingw64\bin;$env:Path"

cd "D:\Download\Cora Cowork UI Desktop\CoraCore 0.1.44"
cargo +stable-x86_64-pc-windows-gnu build --release

# Reiniciar o frontend
cd "D:\Download\Cora Cowork UI Desktop\Cora Cowork UI Desktopre"
bun run start
```

---

## Comandos Úteis

| Ação                                    | Comando                                                                                |
| --------------------------------------- | -------------------------------------------------------------------------------------- |
| Build backend (release)                 | `cargo +stable-x86_64-pc-windows-gnu build --release`                                  |
| Build backend (check rápido)            | `cargo +stable-x86_64-pc-windows-gnu check --release`                                  |
| Rodar backend standalone                | `.\target\release\cora-cowork-app.exe --data-dir data --local`                         |
| Rodar testes do backend                 | `cargo +stable-x86_64-pc-windows-gnu test`                                             |
| Iniciar frontend dev                    | `bun run start`                                                                        |
| Iniciar frontend WebUI                  | `bun run webui`                                                                        |
| Lint + formatação (frontend)            | `bun run lint:fix && bun run format`                                                   |
| Lint + formatação (backend)             | `cargo +stable-x86_64-pc-windows-gnu fmt && cargo +stable-x86_64-pc-windows-gnu clippy` |

---

## Problemas Conhecidos neste PC

### Path relativo do Node runtime (corrigido)

Sintoma: `Cannot find module '...\project\data\runtime\node\...\npm-cli.js'`

O `data-dir` relativo (`data`) era propagado sem absolutizar para os
subprocessos Node/npm. A correção está em `crates/cora-cowork-runtime/src/cache.rs`
— o `data_dir` agora é convertido para caminho absoluto via
`std::path::absolute()` antes de montar os paths do runtime.

Se ainda ocorrer, verificar se está usando o binário novo
(`target\release\cora-cowork-app.exe` atualizado após 10:51).

### Disco C: cheio

Apenas ~1.2 GB livres. Evitar instalar ferramentas grandes no C:.
Redirecionar sempre para D:. O `rustup` e `cargo` já estão em D:.

### Electron não encontra disco C: para cache

O instalador do Electron tenta gravar cache em `%LOCALAPPDATA%\electron\Cache`
(C:). Solução: criar um junction redirect para D::

```powershell
# Executar UMA VEZ apenas
Move-Item "$env:LOCALAPPDATA\electron" "D:\tools\electron\appdata-electron" -Force
cmd /c "mklink /J `"$env:LOCALAPPDATA\electron`" `"D:\tools\electron\appdata-electron`""

# Depois reinstalar o Electron
cd "D:\Download\Cora Cowork UI Desktop\Cora Cowork UI Desktopre"
node node_modules\electron\install.js
```

### Falta SDK headers do Windows

O SDK Include (`C:\Program Files (x86)\Windows Kits\10\Include`) está vazio.
Por isso usamos a toolchain **GNU** (`x86_64-pc-windows-gnu`), que tem seus
próprios headers. Não tente usar a toolchain MSVC sem antes instalar os
headers (exigiria ~5 GB extras no C:).

---

## Scripts de Referência (Frontend)

### Desenvolvimento

| Comando                   | Descrição                                           |
| ------------------------- | --------------------------------------------------- |
| `bun start`               | Iniciar Electron em modo dev                         |
| `bun run start:multi`     | Iniciar segunda instância Electron (multi-instance)  |
| `bun run cli`             | Atalho para `bun start`                             |
| `bun run webui`           | Modo WebUI (navegador, sem Electron)                 |
| `bun run webui:remote`    | Modo WebUI com acesso remoto                         |
| `bun run webui:prod`      | WebUI em produção                                    |
| `bun run webui:prod:remote` | WebUI produção com acesso remoto                  |
| `bun run resetpass`       | Resetar senha do usuário via CLI                     |
| `bun run lint`            | Verificar lint (oxlint, somente leitura)             |
| `bun run lint:fix`        | Auto-corrigir lint                                   |
| `bun run format`          | Auto-formatar código (oxfmt)                         |
| `bun run format:check`    | Verificar formatação sem modificar                   |
| `bun run i18n:types`      | Gerar tipos TypeScript para chaves i18n              |

### Build / Distribuição

| Comando                   | Descrição                                             |
| ------------------------- | ----------------------------------------------------- |
| `bun run package`         | Build de todos os processos (main, preload, renderer)  |
| `bun run make`            | Atalho para `bun run package`                         |
| `bun run dist`            | Build + pacote distribuível para plataforma atual      |
| `bun run dist:mac`        | Build distribuível para macOS                          |
| `bun run dist:win`        | Build distribuível para Windows                        |
| `bun run dist:linux`      | Build distribuível para Linux                          |
| `bun run build-mac`       | Build macOS (arm64 + x64)                              |
| `bun run build-mac:arm64` | Build macOS Apple Silicon                              |
| `bun run build-mac:x64`   | Build macOS Intel                                      |
| `bun run build-win`       | Build Windows                                          |
| `bun run build-win:arm64` | Build Windows ARM64                                    |
| `bun run build-win:x64`   | Build Windows x64                                      |
| `bun run build-deb`       | Build Linux (.deb)                                     |
| `bun run build`           | Atalho para `bun run build-mac`                        |

### Servidor Standalone (sem Electron)

| Comando                          | Descrição                                          |
| -------------------------------- | -------------------------------------------------- |
| `bun run build:renderer:web`     | Build renderer para deploy web standalone           |
| `bun run build:server`           | Build servidor standalone para `dist-server/`       |
| `bun run server:start`           | Iniciar servidor standalone em modo dev             |
| `bun run server:start:remote`    | Servidor standalone com acesso remoto               |
| `bun run server:start:prod`      | Servidor standalone em produção                     |
| `bun run server:start:prod:remote` | Servidor standalone produção com acesso remoto   |
| `bun run server:resetpass`       | Resetar senha via CLI do servidor standalone        |
| `bun run server:resetpass:prod`  | Resetar senha via CLI (produção)                    |

### Testes

| Comando                      | Descrição                                          |
| ---------------------------- | -------------------------------------------------- |
| `bun run test`               | Rodar todos os testes unitários (vitest)            |
| `bun run test:watch`         | Testes em modo watch                                |
| `bun run test:coverage`      | Testes com relatório de cobertura                   |
| `bun run test:contract`      | Testes de contrato                                  |
| `bun run test:integration`   | Testes de integração                                |
| `bun run test:bun`           | Testes específicos do driver Bun                    |
| `bun run test:e2e`           | Testes end-to-end (Playwright)                      |
| `bun run test:packaged:i18n` | Testes i18n contra build empacotado                 |
| `bun run test:packaged:bun`  | Testes Bun contra build empacotado                  |

### Debug

| Comando                       | Descrição                                          |
| ----------------------------- | -------------------------------------------------- |
| `bun run debug:perf`          | Iniciar app com monitoramento de desempenho         |
| `bun run debug:perf:report`   | Gerar relatório de desempenho                       |
| `bun run debug:mcp`           | Debug de conexões MCP                               |
| `bun run debug:mcp:list`      | Listar servidores MCP configurados                  |
| `bun run debug:mcp:validate`  | Validar configurações de servidores MCP             |
| `bun run debug:custom-agent`  | Debug de conexões de agente customizado             |

### Multi-Instance

Quando houver dois clones do repositório (ex: `CoraUi` e `CoraUi-refactor`),
o segundo pode ser iniciado com:

```bash
bun run start:multi
```

Isso define `CORACOWORK_MULTI_INSTANCE=1`, que:
- Ignora o lock single-instance do Electron
- Usa diretório `userData` separado (`CoraUi-Dev-2`)
- Isola caminhos de dados/config
- Portas do Vite renderer, CDP e WebUI proxy auto-incrementam

> **Nota:** O WebUI multi-instance usa porta 25810 (padrão 25809).
> Use janela anônima/privativa para a segunda instância no navegador.

### Code Checks (prek)

```bash
npm install -g @j178/prek
prek install                          # hooks git (opcional)
prek run                              # checar arquivos staged
prek run --from-ref origin/main --to-ref HEAD  # checar diff com main
```

### Build System

O projeto usa **electron-vite**:
- **Main process**: bundlado com Vite (ESM)
- **Renderer process**: bundlado com Vite (React + TypeScript)
- **Preload scripts**: bundlado com Vite

Saída em `out/`:
```
out/main/       - Código do processo principal
out/renderer/   - Código do renderer
out/preload/    - Preload scripts
```

### Tech Stack

| Tecnologia         | Função                              |
| ------------------ | ----------------------------------- |
| Electron           | Framework desktop cross-platform    |
| React 19           | UI                                  |
| TypeScript         | Tipagem estática                    |
| Vite (electron-vite) | Bundler rápido                    |
| UnoCSS             | CSS atômico                         |
| better-sqlite3     | Banco local                         |
| vitest             | Testes                              |
