Enum.each(
  [:vcentral, :vweb],
  fn app ->
    IO.puts("Starting app: #{app}")
    if app == :vweb do
      Application.put_env(:phoenix, :serve_endpoints, true, persistent: true)
    end
    {:ok, _} = Application.ensure_all_started(app)
  end
)
