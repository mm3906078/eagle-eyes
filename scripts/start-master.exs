Enum.each(
  [:vcentral, :vweb],
  fn app ->
    IO.puts("Starting app: #{app}")
    {:ok, _} = Application.ensure_all_started(app)
  end
)
