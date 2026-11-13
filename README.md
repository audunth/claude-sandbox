# claude-sandbox

Based on [Sandbox AI coding agents with microVMs on Fedora Linux](https://fedoramagazine.org/sandbox-ai-coding-agents-with-microvms-on-fedora-linux/) and [Docker/Podman AI CLI tools safe environment](https://www.bitdoze.com/docker-podman-ai-cli-tools-safe-environment/). Also contains tinytex to compile documents.

## Install and run

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

Arguments after the script's own options are passed on to `claude`, for example `csbx --resume`. Use `--` to pass an option the script also has, such as `csbx -- --help` for Claude's help. `csbx --shell` opens bash in the container instead of Claude.

The project folder must be the top of a git repository, because its `.git` is mounted read-only. In a folder without git, the script offers to run `git init`. It refuses to run in a subfolder of a repository or inside a `.git` folder.

Apart from `git init`, nothing is written to the project folder. All projects share one image, `localhost/claude-sandbox`. The first run builds it, and `--build` rebuilds it. Every run creates the `claude-config` volume if it is missing, then starts Claude in the container. Log in the first time. The login is stored in `claude-config` and shared by all projects. The project is mounted at the same path in the container as on the host, so Claude still keeps memory and history separate for each project. The container is removed when Claude exits.

The sandbox files stay outside the project, so the agent cannot change them. The exception is when the project is this repository: an edited `podman-compose.yaml` takes effect on the next run.

### Python environments

Keep the dependencies in the project (`pyproject.toml`, `requirements.txt`, a lock file such as `uv.lock`), and use separate environments on the host and in the container. In the container, `.venv` is a volume of its own for each project, mounted over the project's `.venv`. So the agent never sees or changes the host's `.venv`, and the host never runs anything the agent installed. If the project has no `.venv`, an empty one appears as the mount point.

The image has Python 3.13 (with `venv`) and uv. In the container (`csbx --shell`, or `!` in front of the command in Claude), for example:

```bash
uv sync                                                # pyproject.toml, uv.lock
uv venv && uv pip install -r requirements.txt          # requirements.txt
python3 -m venv .venv && .venv/bin/pip install -e .    # plain pip
```

Poetry and PDM also use `.venv` in the container (for example `uvx poetry install`). The environment is kept between runs. uv's cache and the Pythons it downloads are kept in the `claude-sandbox-uv` volume, shared by all projects.

Each project's environment is a volume named after the project's path, such as `claude-sandbox-venv-home-me-myproject`. `podman volume ls` lists them, and `podman volume rm` deletes one, for example after deleting the project.

## TODO

### Isolation

- [ ] Guard against code planted for the host. `.git` is read-only, but the agent can still `git init` a subfolder and add hooks or `core.fsmonitor` there, or edit Makefiles and `.envrc`. Document the risk.
- [ ] Add more hardening: `cap_drop: [ALL]` and `pids_limit` (`no-new-privileges` is already set). Check how krun handles these.
- [ ] Consider restricting outbound network. Check the claim that krun bypasses host nftables unless `krun.use_passt` is set.

### Containerfile

- [ ] Set `DISABLE_AUTOUPDATER=1` and rebuild to upgrade. Auto-updates are lost with `--rm` and downloaded again every session.
- [ ] Consider adding `less jq make` (maybe `poppler-utils` for PDFs). Debian already has the GNU core tools.

### Script and README

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
