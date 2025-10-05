# Eagle Eyes

Eagle Eyes is a vulnerability scanner that scans the servers agents set up on them to find vulnerabilities in the installed packages. The master server is responsible for managing the agents and the agents are responsible for scanning the servers and sending the results to the master server. The master server can notify you using a telegram bot.

## Setup

### requirements (master)

- Ubuntu 22.04/Debian 12
- minimum 6GB RAM
- minimum 4 CPU cores
- minimum 10GB RAM+SWAP

### requirements (agent)

- Ubuntu 22.04/Debian 12
- minimum 1GB RAM
- minimum 1 CPU cores

### Installation

I suggest installing Elixir using `asdf` version manager. please follow the instructions [here](https://medium.com/@prathmeshchavan8652/installing-elixir-and-erlang-using-asdf-in-ubuntu-df1aac56b7a7). then use make to install the dependencies and compile the project.

```bash
git clone git@github.com:mm3906078/eagle-eyes.git
cd eagle-eyes
make compile
make release_master
make release_agent
```

the agent and master releases will be in `_build/prod/agent-<VERSION>.tar.gz` and `_build/prod/master-<VERSION>.tar.gz` respectively.

### Production Notices

- for finding `CPEs` we use `cpe-guesser.cve-search.org` API, but in the production environment, you should use their code in the self-hosted environment. Please check the [cve-search](https://github.com/cve-search/cpe-guesser) repository for more information.

## Feature List

- [ ] Master load for finding CVEs can be distributed to agents.
- [ ] Support for Windows agents.
- [ ] Support for MacOS agents.
- [ ] Support for Linux older than Ubuntu 22.04/Debian 12.
- [x] Rewrite the `version_control.ex` module for installing large packages.
- [ ] Unit tests for the `vagent` application.
- [ ] Unit tests for the `vcentral` application.

## Development

Run the debugging shell using these commands.

```bash
export $(xargs < .env)
iex --name vagent@192.168.1.10 -S mix run --no-start scripts/start-agent.exs
iex --name vcentral@192.168.1.10 -S mix run --no-start scripts/start-master.exs
```

if you getting an error of Protocol `'inet_tcp': register/listen error: econnrefused` try to run `epmd -daemon` and then run the above commands.

## Releases

### Automated Releases

This project uses GitHub Actions for automated building and releasing. Releases are triggered by pushing version tags to the repository.

### Creating a Release

1. **Using the release script (recommended):**
   ```bash
   # Increment patch version (0.1.0 -> 0.1.1)
   ./scripts/release.sh patch
   
   # Increment minor version (0.1.0 -> 0.2.0)
   ./scripts/release.sh minor
   
   # Increment major version (0.1.0 -> 1.0.0)
   ./scripts/release.sh major
   ```

2. **Manual process:**
   ```bash
   # Update version in mix.exs
   # Commit the changes
   git add mix.exs
   git commit -m "Bump version to X.Y.Z"
   
   # Create and push tag
   git tag -a vX.Y.Z -m "Release X.Y.Z"
   git push origin main
   git push origin vX.Y.Z
   ```

### Release Artifacts

Each release includes two main artifacts:
- **agent-X.Y.Z.tar.gz**: The agent application for deployment on monitored servers
- **master-X.Y.Z.tar.gz**: The master application including the central server and web interface

### CI/CD Pipeline

The release process includes:
1. **Test**: Runs formatting checks and test suite
2. **Build**: Compiles and creates release artifacts for both agent and master
3. **Release**: Creates GitHub release with artifacts when a version tag is pushed

### Download Releases

Released artifacts can be downloaded from the [GitHub Releases page](https://github.com/mm3906078/eagle-eyes/releases).
