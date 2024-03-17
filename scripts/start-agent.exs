Enum.each(
  [:vagent],
  fn app ->
    IO.puts("Starting app: #{app}")
    {:ok, pid} = Application.ensure_all_started(app)
  end
)
