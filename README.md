# claude-sandbox

Based on [Sandbox AI coding agents with microVMs on Fedora Linux](https://fedoramagazine.org/sandbox-ai-coding-agents-with-microvms-on-fedora-linux/) and [Docker/Podman AI CLI tools safe environment](https://www.bitdoze.com/docker-podman-ai-cli-tools-safe-environment/). Also contains tinytex to compile documents.

## Install with `claude-sandbox.sh`

You need `git`, `podman`, `podman-compose` and the krun runtime (`crun-krun` on Fedora). The compose file runs the container in a libkrun microVM.

Clone the repository and put the script on your `PATH` (here `~/.local/bin`):

```bash
git clone https://github.com/audunth/claude-sandbox.git ~/claude-sandbox
chmod +x ~/claude-sandbox/claude-sandbox.sh
ln -s ~/claude-sandbox/claude-sandbox.sh ~/.local/bin/csbx
```

The script uses the `Containerfile` and `podman-compose.yaml` in its own folder (it follows the symlink). To use files from another folder, set `CLAUDE_SANDBOX_DIR` to that folder.

Then run it from a project folder below `$HOME` (not `$HOME` itself):

```bash
csbx --build   # after changing the Containerfile
csbx           # every other run
```

The project folder must be the top of a git repository, because its `.git` is mounted read-only. In a folder without git, the script offers to run `git init`. It refuses to run in a subfolder of a repository or inside a `.git` folder.

Apart from `git init`, nothing is written to the project folder. All projects share one image, `localhost/claude-sandbox`. The first run builds it, and `--build` rebuilds it. Every run creates the `claude-config` volume if it is missing, then opens a shell in the container at the project's path. Start Claude with `claude` and log in the first time. The login is stored in `claude-config` and shared by all projects. The container is removed when you exit.

The sandbox files stay outside the project, so the agent cannot change them. The exception is when the project is this repository: an edited `podman-compose.yaml` takes effect on the next run.

### Python environments

Keep the dependencies in the project (`pyproject.toml`, `requirements.txt`, a lock file such as `uv.lock`), and use separate environments on the host and in the container. In the container, `.venv` is a volume of its own for each project, mounted over the project's `.venv`. So the agent never sees or changes the host's `.venv`, and the host never runs anything the agent installed. If the project has no `.venv`, an empty one appears as the mount point.

The image has Python 3.13 (with `venv`) and uv. In the container, for example:

```bash
uv sync                                                # pyproject.toml, uv.lock
uv venv && uv pip install -r requirements.txt          # requirements.txt
python3 -m venv .venv && .venv/bin/pip install -e .    # plain pip
```

Poetry and PDM also use `.venv` in the container (for example `uvx poetry install`). The environment is kept between runs. uv's cache and the Pythons it downloads are kept in the `claude-sandbox-uv` volume, shared by all projects.

Each project's environment is a volume named after the project's path, such as `claude-sandbox-venv-home-me-myproject`. `podman volume ls` lists them, and `podman volume rm` deletes one, for example after deleting the project.

## Manual usage (without the script)

Run all commands from the top of the project's git repository (run `git init` first if needed). Its `.git` is mounted read-only, and podman-compose would create an empty `.git` folder if it were missing. The project is mounted at the same path inside the container (`PROJECT_DIR`), so Claude keeps memory and history separate for each project.

The compose file is used from the cloned repository, here `~/claude-sandbox`. Nothing is copied into the project.

Create the volume that stores Claude's login and settings (once per machine, shared by all projects):

```bash
podman volume exists claude-config || podman volume create claude-config
```

Set the variables the compose file needs. `VENV_VOLUME` names the volume that holds the container's `.venv` for this project:

```bash
export HOST_UID=$(id -u) HOST_GID=$(id -g) PROJECT_DIR=$(pwd -P)
export VENV_VOLUME="claude-sandbox-venv$(pwd -P | tr / -)"
```

Build with

```bash
podman-compose -f ~/claude-sandbox/podman-compose.yaml build
```

Run with

```bash
podman-compose -f ~/claude-sandbox/podman-compose.yaml run --rm claude
```

The variables are needed for the build too: podman-compose expands every variable in the file before running any command.

## TODO

### Bugs

- [x] Remove the stray `bash` line above the shebang in `claude-sandbox.sh`. Without a valid shebang, the script opens a nested interactive shell before doing anything.
- [x] Mount each project at its own path instead of `/app`. Claude keys memory, `/resume` history and project settings by path (`~/.claude/projects/-app/`), so all projects currently share them through the `claude-config` volume. Mirror the host path, e.g. `${PROJECT_DIR}:${PROJECT_DIR}:z` with `working_dir: ${PROJECT_DIR}` and `export PROJECT_DIR="$(pwd -P)"` in the script.
- [x] Create the external `claude-config` volume if it is missing (`podman volume exists claude-config || podman volume create claude-config`). The first run fails without it.
- [x] Fix or remove the root branch in `entrypoint.sh`. It calls `su-exec`, which is not installed (unused today because compose sets `user:`). Removed `entrypoint.sh` altogether: without that branch it only ran `exec "$@"`.
- [x] Give each project its own compose project name. No longer needed: each project's `.venv` volume is named after its path, `run` names each container itself, and the image is shared on purpose (`image:` in the compose file). Dropped the `project-name-*` placeholders.

### Isolation

- [x] Stop the agent from editing its own sandbox config. `.claude-sandbox/podman-compose.yaml` is inside the mounted project and is read on every run. Build one image from this repo and keep the compose file outside the project, or mount `.claude-sandbox` read-only.
- [x] Remove `.claude-sandbox` from the project. The script now uses the compose file and Containerfile from its own folder and builds one shared image.
- [ ] Guard against code planted for the host. `.git` is read-only, but the agent can still `git init` a subfolder and add hooks or `core.fsmonitor` there, or edit Makefiles and `.envrc`. Document the risk.
- [x] Drop `U` from the project bind mount (keep it on named volumes). It recursively chowns the host project tree.
- [ ] Add hardening: `security_opt: [no-new-privileges:true]`, `cap_drop: [ALL]`, `pids_limit`. Check how krun handles these.
- [ ] Consider restricting outbound network. Check the claim that krun bypasses host nftables unless `krun.use_passt` is set.

### Containerfile

- [x] Switch from `alpine:latest` to `debian:trixie-slim` (glibc), so compiled Python packages, conda/pixi environments and Claude Code's bundled ripgrep work. This also pins the base image and makes `USE_BUILTIN_RIPGREP=0` unnecessary.
- [ ] Set `DISABLE_AUTOUPDATER=1` and rebuild to upgrade. Auto-updates are lost with `--rm` and downloaded again every session.
- [x] Bake TeX packages into the image (`tlmgr install revtex pgf textcase`). Note: `revtex`, not `revtext`.
- [x] Install TinyTeX before Claude so Claude updates reuse the TinyTeX layer.
- [ ] Consider adding `less jq make` (maybe `poppler-utils` for PDFs). Debian already has the GNU core tools.
- [x] Install uv, and give the container its own `.venv` in a volume per project (see Python environments).
- [ ] Set a git identity in the container (`GIT_AUTHOR_*`/`GIT_COMMITTER_*` env or a read-only gitconfig). Keep SSH keys out so the agent cannot push.

### Script and README

- [ ] Start Claude directly and forward arguments (`run --rm claude claude "$@"`) instead of landing in a shell.
- [x] Default the template folder to the script's own location (`$(dirname "$(readlink -f "$0")")`) instead of `$HOME/AI`.
- [ ] Check the minimum libkrun version (>= 1.8?) and add it to the requirements in the README.

## Not installed yet (consider if needed)

- pandoc (using just .tex for now)
- any compilers (rust, c++, julia)

## AI use

Claude was actively used in writing the shell script and removing escape routes.

## Inspiration

- <https://fedoramagazine.org/sandbox-ai-coding-agents-with-microvms-on-fedora-linux/>
- <https://github.com/msehnout/agent-sandbox>
- <https://www.bitdoze.com/docker-podman-ai-cli-tools-safe-environment/>
