## Development
Run the debugging shell using these commands.
```
iex -S mix run --no-start scripts/start-agent.exs
iex -S mix run --no-start scripts/start-master.exs
```
if you getting error of Protocol `'inet_tcp': register/listen error: econnrefused` try to run `epmd -daemon` and then run the above commands.
