## Setup

### requirements (master):
- Ubuntu 22.04/Debian 12
- minimum 6GB RAM
- minimum 4 CPU cores
- minimum 10GB RAM+SWAP

### requirements (agent):
- Ubuntu 22.04/Debian 12
- minimum 1GB RAM
- minimum 1 CPU cores

### Installation
I suggest install elixir using `asdf` version manager. please follow the instructions [here](https://medium.com/@prathmeshchavan8652/installing-elixir-and-erlang-using-asdf-in-ubuntu-df1aac56b7a7). then use make to install the dependencies and compile the project.
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


## Development
Run the debugging shell using these commands.
```
export $(xargs < .env)
iex --name vcentral@192.168.1.10 -S mix run --no-start scripts/start-agent.exs
iex --name vagent@192.168.1.10 -S mix run --no-start scripts/start-master.exs
```
if you getting an error of Protocol `'inet_tcp': register/listen error: econnrefused` try to run `epmd -daemon` and then run the above commands.
