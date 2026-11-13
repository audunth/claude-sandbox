# claude-sandbox

Based on [Sandbox AI coding agents with microVMs on Fedora Linux](https://fedoramagazine.org/sandbox-ai-coding-agents-with-microvms-on-fedora-linux/) and [Docker/Podman AI CLI tools safe environment](https://www.bitdoze.com/docker-podman-ai-cli-tools-safe-environment/). Also contains tinytex to compile documents.

## Install with `claude-sandbox.sh`

You need `podman`, `podman-compose` and the krun runtime (`crun-krun` on Fedora). The compose file runs the container in a libkrun microVM.

Clone the repository and put the script on your `PATH` (here `~/.local/bin`):

```bash
git clone https://github.com/audunth/claude-sandbox.git ~/claude-sandbox
chmod +x ~/claude-sandbox/claude-sandbox.sh
ln -s ~/claude-sandbox/claude-sandbox.sh ~/.local/bin/claude-sandbox
```

By default the script copies the templates from `~/AI`. Point it at the clone instead, e.g. in `~/.bashrc`:

```bash
export CLAUDE_SANDBOX_TEMPLATES="$HOME/claude-sandbox"
```

Then run it from a project folder (it refuses to run in `$HOME`):

```bash
claude-sandbox --build   # first time, or after updating the templates
claude-sandbox           # later runs
```

`--build` copies `Containerfile` and `podman-compose.yaml` into `.claude-sandbox/` in the project, overwriting any earlier copies, and builds the image. Every run creates the `claude-config` volume if it is missing, then opens a shell in the container at the project's path. Start Claude with `claude` and log in the first time. The login is stored in `claude-config` and shared by all projects. The container is removed when you exit.

## Manual usage (without the script)

Run all commands from the project folder. The project is mounted at the same path inside the container (`PROJECT_DIR`), so Claude keeps memory and history separate for each project.

Copy `Containerfile` and `podman-compose.yaml` to a `.claude-sandbox` directory in your project:

```bash
mkdir -p .claude-sandbox
cp /path/to/claude-sandbox/{Containerfile,podman-compose.yaml} .claude-sandbox/
```

Create the volume that stores Claude's login and settings (once per machine, shared by all projects):

```bash
podman volume exists claude-config || podman volume create claude-config
```

Build with

```bash
HOST_UID=$(id -u) HOST_GID=$(id -g) PROJECT_DIR=$(pwd -P) podman-compose -f .claude-sandbox/podman-compose.yaml build
```

Run with

```bash
HOST_UID=$(id -u) HOST_GID=$(id -g) PROJECT_DIR=$(pwd -P) podman-compose -f .claude-sandbox/podman-compose.yaml run --rm claude
```

`PROJECT_DIR` is needed for the build too: podman-compose expands every variable in the file before running any command.

## TODO

### Bugs

- [x] Remove the stray `bash` line above the shebang in `claude-sandbox.sh`. Without a valid shebang, the script opens a nested interactive shell before doing anything.
- [x] Mount each project at its own path instead of `/app`. Claude keys memory, `/resume` history and project settings by path (`~/.claude/projects/-app/`), so all projects currently share them through the `claude-config` volume. Mirror the host path, e.g. `${PROJECT_DIR}:${PROJECT_DIR}:z` with `working_dir: ${PROJECT_DIR}` and `export PROJECT_DIR="$(pwd -P)"` in the script.
- [x] Create the external `claude-config` volume if it is missing (`podman volume exists claude-config || podman volume create claude-config`). The first run fails without it.
- [x] Fix or remove the root branch in `entrypoint.sh`. It calls `su-exec`, which is not installed (unused today because compose sets `user:`). Removed `entrypoint.sh` altogether: without that branch it only ran `exec "$@"`.
- [ ] Give each project its own compose project name (`podman-compose -p "$(basename "$PWD")"`). Otherwise every project is probably named after the `.claude-sandbox` folder and shares the image and venv volume. Drop the `project-name-*` placeholders.

### Isolation

- [x] Stop the agent from editing its own sandbox config. `.claude-sandbox/podman-compose.yaml` is inside the mounted project and is read on every run. Build one image from this repo and keep the compose file outside the project, or mount `.claude-sandbox` read-only.
- [ ] .claude-sandbox is read-only. Consider hiding it or doing most outside the project.
- [ ] Guard against code planted for the host: `.git/hooks`, `.git/config` (`core.hooksPath`, `core.fsmonitor`), Makefiles, `.envrc`. At least mount `.git/hooks` read-only, or document the risk.
- [x] Drop `U` from the project bind mount (keep it on named volumes). It recursively chowns the host project tree.
- [ ] Add hardening: `security_opt: [no-new-privileges:true]`, `cap_drop: [ALL]`, `pids_limit`. Check how krun handles these.
- [ ] Consider restricting outbound network. Check the claim that krun bypasses host nftables unless `krun.use_passt` is set.

### Containerfile

- [ ] Pin the base image (`alpine:3.24`) instead of `latest`.
- [ ] Set `ENV USE_BUILTIN_RIPGREP=0`, as Claude Code's docs recommend for Alpine/musl.
- [ ] Set `DISABLE_AUTOUPDATER=1` and rebuild to upgrade. Auto-updates are lost with `--rm` and downloaded again every session.
- [ ] Bake TeX packages into the image (`tlmgr install revtex pgf textcase`). Note: `revtex`, not `revtext`.
- [ ] Install TinyTeX before Claude so Claude updates reuse the TinyTeX layer.
- [ ] Add GNU tools that BusyBox lacks options for: `coreutils findutils grep sed diffutils less jq make` (maybe `poppler-utils` for PDFs).
- [ ] Either install uv (`apk add uv`) or remove the `UV_*` variables and `/venv` volume.
- [ ] Set a git identity in the container (`GIT_AUTHOR_*`/`GIT_COMMITTER_*` env or a read-only gitconfig). Keep SSH keys out so the agent cannot push.

### Script and README

- [ ] Start Claude directly and forward arguments (`run --rm claude claude "$@"`) instead of landing in `/bin/sh`.
- [ ] Default the template folder to the script's own location (`$(dirname "$(readlink -f "$0")")`) instead of `$HOME/AI`.
- [ ] Check the minimum libkrun version (>= 1.8?) and add it to the requirements in the README.

## Not installed yet (consider if needed)

- uv
- pandoc (using just .tex for now)
- any compilers (rust, c++, julia)

## Inspiration

- <https://fedoramagazine.org/sandbox-ai-coding-agents-with-microvms-on-fedora-linux/>
- <https://github.com/msehnout/agent-sandbox>
- <https://www.bitdoze.com/docker-podman-ai-cli-tools-safe-environment/>
