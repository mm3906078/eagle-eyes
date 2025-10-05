defmodule Vagent.VersionControl do
  require Logger

  @behaviour :gen_statem

  # API

  def start_link(opts) do
    :gen_statem.start_link(__MODULE__, opts, [])
  end

  def get_version(pid) do
    :gen_statem.call(pid, :get_version)
  end

  def get_apps_installed(pid) do
    :gen_statem.call(pid, :get_apps)
  end

  def get_current_state(pid) do
    :gen_statem.call(pid, :get_state)
  end

  def install_app(pid, app, version) do
    :gen_statem.call(pid, {:install_app, app, version})
  end

  def remove_app(pid, app) do
    :gen_statem.call(pid, {:remove_app, app})
  end

  def update_apps(pid, apps) do
    :gen_statem.call(pid, {:update, apps})
  end

  # Callbacks

  def callback_mode() do
    [:handle_event_function, :state_enter]
  end

  def terminate(reason, currentState, _data) do
    Logger.warning(
      "Terminating with reason: #{inspect(reason)}, in state: #{inspect(currentState)}"
    )

    :pg.leave(:agent, self())
    :pg.leave(node(), self())
  end

  def init(_opts) do
    inital_state = %{
      apps: %{},
      state: :get_version
    }

    :pg.join(:agent, self())
    :pg.join(node(), self())

    {:ok, inital_state, [], {:next_event, :internal, :get_version}}
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def handle_event({:call, from}, :get_state, state, _data) do
    {:keep_state_and_data, [{:reply, from, state.state}]}
  end

  #################
  ## get_version ##
  #################

  def handle_event(:enter, _old_state, %{state: :get_version}, _data) do
    Logger.info("Entered get_version state")
    :keep_state_and_data
  end

  def handle_event(:internal, :get_version, %{state: :get_version} = state, data) do
    case Application.get_env(:vagent, :demo) do
      true ->
        Logger.info("Running in demo mode")
        status = :demo

        case get_apps(status) do
          {:ok, apps} ->
            next_state = %{state | apps: apps, state: :idle}
            {:next_state, next_state, data}

          {:error, error} ->
            Logger.error("Error getting apps: #{error}")
            {:stop, :get_version_error, state}
        end

      _ ->
        Logger.info("Getting all apps")
        status = :all

        case get_apps(status) do
          {:ok, apps} ->
            next_state = %{state | apps: apps, state: :idle}
            {:next_state, next_state, data}

          {:error, error} ->
            Logger.error("Error getting apps: #{error}")
            {:stop, :get_version_error, state}
        end
    end
  end

  def handle_event(
        {:call, _from},
        :get_apps,
        %{state: :get_version},
        _data
      ) do
    Logger.debug("Postponing get_apps call")
    {:keep_state_and_data, :postpone}
  end

  ##########
  ## idle ##
  ##########

  def handle_event(:enter, _old_state, %{state: :idle, apps: apps}, _data) do
    Logger.info("Entered idle state, whith apps: #{inspect(apps)}")
    :keep_state_and_data
  end

  def handle_event(
        {:call, from},
        {:install_app, app, version},
        %{state: :idle} = state,
        data
      ) do
    next_state = %{state | state: :installing_app}
    next_event = {:next_event, :internal, {:install_app, app, version}}
    {:next_state, next_state, data, [next_event, {:reply, from, :ok}]}
  end

  def handle_event({:call, from}, :get_version, %{state: :idle} = state, data) do
    next_state = %{state | state: :get_version}
    next_event = {:next_event, :internal, :get_version}
    {:next_state, next_state, data, [next_event, {:reply, from, :ok}]}
  end

  def handle_event({:call, from}, {:remove_app, app}, %{state: :idle} = state, data) do
    next_state = %{state | state: :removing_app}
    next_event = {:next_event, :internal, {:remove_app, app}}
    {:next_state, next_state, data, [next_event, {:reply, from, :ok}]}
  end

  def handle_event({:call, from}, :get_apps, %{state: :idle} = state, _data) do
    {:keep_state_and_data, [{:reply, from, {:ok, state.apps}}]}
  end

  def handle_event({:call, from}, {:update, apps}, %{state: :idle} = state, data) do
    next_state = %{state | state: :update}
    next_event = {:next_event, :internal, {:update, apps}}
    {:next_state, next_state, data, [next_event, {:reply, from, :ok}]}
  end

  #################
  ## install_app ##
  #################

  def handle_event(:enter, _old_state, %{state: :installing_app}, _data) do
    Logger.info("Entered installing_app state")
    :keep_state_and_data
  end

  def handle_event(
        :internal,
        {:install_app, app, version},
        %{state: :installing_app},
        _data
      ) do
    Logger.info("Installing app: #{app} version: #{version}")

    run_script("install_app.sh", [app, version])
    :keep_state_and_data
  end

  def handle_event(
        :info,
        {port, {:data, "install_app_success"}},
        %{state: :installing_app} = state,
        _data
      )
      when is_port(port) do
    Logger.info("App installed successfully")
    next_state = %{state | state: :get_version}
    next_event = {:next_event, :internal, :get_version}
    {:next_state, next_state, %{}, [next_event]}
  end

  def handle_event(
        :info,
        {port, {:data, "Failed_to_install"}},
        %{state: :installing_app},
        _data
      )
      when is_port(port) do
    Logger.error("Error installing app")
    next_state = %{state: :idle}
    {:next_state, next_state, %{}, []}
  end

  def handle_event(:info, _msg, %{state: :installing_app}, _data) do
    :keep_state_and_data
  end

  def handle_event(
        {:call, from},
        {:install_app, _app, _version},
        %{state: :installing_app},
        _data
      ) do
    {:keep_state_and_data, {:reply, from, {:error, :busy}}}
  end

  def handle_event({:call, from}, {:update, _app}, %{state: :installing_app}, _data) do
    {:keep_state_and_data, {:reply, from, {:error, :busy}}}
  end

  def handle_event({:call, from}, {:remove_app, _app}, %{state: :installing_app}, _data) do
    {:keep_state_and_data, {:reply, from, {:error, :busy}}}
  end

  def handle_event({:call, _from}, :get_version, %{state: :installing_app}, _data) do
    Logger.debug("Postponing get_version call")
    {:keep_state_and_data, :postpone}
  end

  def handle_event({:call, _from}, :get_apps, %{state: :installing_app}, _data) do
    Logger.debug("Postponing get_apps call")
    {:keep_state_and_data, :postpone}
  end

  ################
  ## remove_app ##
  ################

  def handle_event(:enter, _old_state, %{state: :removing_app}, _data) do
    Logger.info("Entered removing_app state")
    :keep_state_and_data
  end

  def handle_event(
        :internal,
        {:remove_app, app},
        %{state: :removing_app},
        _data
      ) do
    Logger.info("Removing app: #{app}")

    run_script("remove_app.sh", [app])
    :keep_state_and_data
  end

  def handle_event(
        :info,
        {port, {:data, "remove_app_success"}},
        %{state: :removing_app} = state,
        _data
      )
      when is_port(port) do
    Logger.info("App removed successfully")
    next_state = %{state | state: :get_version}
    next_event = {:next_event, :internal, :get_version}
    {:next_state, next_state, %{}, [next_event]}
  end

  def handle_event(
        :info,
        {port, {:data, "Failed_to_remove"}},
        %{state: :removing_app},
        _data
      )
      when is_port(port) do
    Logger.error("Error removing app")
    next_state = %{state: :idle}
    {:next_state, next_state, %{}, []}
  end

  def handle_event(:info, _msg, %{state: :removing_app}, _data) do
    :keep_state_and_data
  end

  def handle_event({:call, _from}, :get_version, %{state: :removing_app}, _data) do
    Logger.debug("Postponing get_version call")
    {:keep_state_and_data, :postpone}
  end

  def handle_event({:call, _from}, :get_apps, %{state: :removing_app}, _data) do
    Logger.debug("Postponing get_apps call")
    {:keep_state_and_data, :postpone}
  end

  def handle_event({:call, from}, {:update, _app}, %{state: :removing_app}, _data) do
    {:keep_state_and_data, {:reply, from, {:error, :busy}}}
  end

  def handle_event(
        {:call, from},
        {:install_app, _app, _version},
        %{state: :removing_app},
        _data
      ) do
    {:keep_state_and_data, {:reply, from, {:error, :busy}}}
  end

  def handle_event({:call, from}, {:remove_app, _app}, %{state: :removing_app}, _data) do
    {:keep_state_and_data, {:reply, from, {:error, :busy}}}
  end

  ############
  ## update ##
  ############

  def handle_event(:enter, _old_state, %{state: :update}, _data) do
    Logger.info("Entered update state")
    :keep_state_and_data
  end

  def handle_event(:internal, {:update, apps}, %{state: :update}, _data) do
    Logger.info("Updating apps")
    # check if apps are empty list
    if apps == [] do
      run_script("update_apps.sh", [])
    else
      run_script("update_apps.sh", apps)
    end

    :keep_state_and_data
  end

  def handle_event(
        :info,
        {port, {:data, "update_app_success"}},
        %{state: :update} = state,
        _data
      )
      when is_port(port) do
    Logger.info("Apps updated successfully")
    next_state = %{state | state: :get_version}
    next_event = {:next_event, :internal, :get_version}
    {:next_state, next_state, %{}, [next_event]}
  end

  def handle_event(
        :info,
        {port, {:data, "Failed_to_update"}},
        %{state: :update},
        _data
      )
      when is_port(port) do
    Logger.error("Error updating apps")
    next_state = %{state: :idle}
    {:next_state, next_state, %{}, []}
  end

  def handle_event(:info, _msg, %{state: :update}, _data) do
    :keep_state_and_data
  end

  def handle_event({:call, _from}, :get_version, %{state: :update}, _data) do
    Logger.debug("Postponing get_version call")
    {:keep_state_and_data, :postpone}
  end

  def handle_event({:call, _from}, :get_apps, %{state: :update}, _data) do
    Logger.debug("Postponing get_apps call")
    {:keep_state_and_data, :postpone}
  end

  def handle_event({:call, from}, {:update, _app}, %{state: :update}, _data) do
    {:keep_state_and_data, {:reply, from, {:error, :busy}}}
  end

  def handle_event(
        {:call, from},
        {:install_app, _app, _version},
        %{state: :update},
        _data
      ) do
    {:keep_state_and_data, {:reply, from, {:error, :busy}}}
  end

  def handle_event({:call, from}, {:remove_app, _app}, %{state: :update}, _data) do
    {:keep_state_and_data, {:reply, from, {:error, :busy}}}
  end

  #############
  ## PRIVATE ##
  #############

  defp run_script(script, script_args) do
    app_dir = Application.app_dir(:vagent, "priv/scripts")
    script_path = Path.join([app_dir, script])
    Logger.info("Running script: #{script_path} & args: #{inspect(script_args)}")

    _port =
      Port.open({:spawn_executable, script_path}, [:binary, args: script_args])
  end

  defp get_apps(status) do
    case status do
      :all ->
        case System.cmd("dpkg-query", ["-W", "-f='${Package}: ${Version}\n'"]) do
          {output, 0} ->
            apps =
              output
              |> String.trim()
              |> String.split("\n")
              |> Enum.reduce(%{}, fn line, acc ->
                case String.split(line, ": ", parts: 2) do
                  [app, version] when app != "" ->
                    cleaned_app = String.trim(app, "'")
                    # TODO: This is a hack, we should use a proper version comparison
                    version_final = Enum.at(String.split(version, "-"), 0)

                    app_info = %{
                      version: version_final
                    }

                    Map.put(acc, cleaned_app, app_info)

                  _ ->
                    acc
                end
              end)

            {:ok, apps}

          {output, _} ->
            {:error, output}
        end

      :demo ->
        case System.cmd("sh", [
               "-c",
               "dpkg-query -W -f='${Package}: ${Version}\n' | grep -E 'vlc: 3.0.16-1build7|nginx:'"
             ]) do
          {output, 0} when output != "" ->
            apps =
              output
              |> String.trim()
              |> String.split("\n")
              |> Enum.reduce(%{}, fn line, acc ->
                case String.split(line, ": ", parts: 2) do
                  [app, version] when app != "" ->
                    cleaned_app = String.trim(app, "'")
                    # TODO: This is a hack, we should use a proper version comparison
                    version_final = Enum.at(String.split(version, "-"), 0)

                    app_info = %{
                      version: version_final
                    }

                    Map.put(acc, cleaned_app, app_info)

                  _ ->
                    acc
                end
              end)

            {:ok, apps}

          {_output, _exit_code} ->
            # Command failed or no packages found, return empty map for tests
            {:ok, %{}}
        end

      :shallow ->
        # TODO: Implement for smaller list of apps
        {:error, "Not implemented"}
    end
  end
end
