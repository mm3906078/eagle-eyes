.PHONY: compile compile_dev release_agent release_master tar_agent tar_master iex_dev all clean release

all: compile release_agent release_master tar_agent tar_master

compile:
	@echo "Compiling the application..."
	mix do deps.get, compile

compile_dev:
	@echo "Compiling the application in development environment..."
	MIX_ENV=dev mix do deps.get, compile

release_agent:
	@echo "Creating release for agent..."
	MIX_ENV=prod mix release agent

release_master:
	@echo "Creating release for master..."
	MIX_ENV=prod mix release master

release: release_agent release_master
	@echo "All releases created successfully!"

iex_dev_master:
	@echo "Starting an interactive Elixir session in development environment..."
	iex -S mix run --no-start scripts/start-master.exs

iex_dev_agent:
	@echo "Starting an interactive Elixir session in development environment..."
	iex -S mix run --no-start scripts/start-agent.exs

clean:
	@echo "Cleaning up..."
	mix clean
	rm -rf _build
	rm -rf deps
	rm -rf .elixir_ls

# Release management targets
release_patch:
	@./scripts/release.sh patch

release_minor:
	@./scripts/release.sh minor

release_major:
	@./scripts/release.sh major

version:
	@grep 'version:' mix.exs | head -1 | sed 's/.*version: "\(.*\)".*/\1/'
