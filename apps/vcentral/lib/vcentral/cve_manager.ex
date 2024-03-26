defmodule Vcentral.CVEManager do
  require Logger

  @cve_url "https://services.nvd.nist.gov/rest/json/cves/2.0?cpeName="
  @cpe_url_local "https://nvd.nist.gov/feeds/json/cpematch/1.0/nvdcpematch-1.0.json.zip"
  @cpe_guesser_url "https://cpe-guesser.cve-search.org/search"
  @local_cache_path "/tmp/"

  defp download_CPEs() do
    path = Path.join(@local_cache_path, "nvdcpematch-1.0.json")
    zip_path = Path.join(@local_cache_path, "cpe.zip")
    user_agent = UserAgent.random()

    case File.exists?(path) do
      true ->
        # TODO: Check if file is outdated
        :ok

      false ->
        Logger.debug("Local CPE cache not found, downloading new CPE data")

        case HTTPoison.get(@cpe_url_local, [{"User-Agent", user_agent}]) do
          {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
            File.write!(zip_path, body)
            {_result, 0} = System.cmd("unzip", [zip_path, "-d", @local_cache_path])
            File.rm(zip_path)
            :ok

          {:ok, %HTTPoison.Response{status_code: status_code}} ->
            Logger.error("Failed to download CPE data, status code: #{status_code}")
            :error

          {:error, reason} ->
            Logger.error("Failed to download CPE data, reason: #{inspect(reason)}")
            :error

          {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
            File.write!(zip_path, body)
            {_result, 0} = System.cmd("unzip", [zip_path, "-d", @local_cache_path])
            File.rm(zip_path)
            :ok

          {:ok, %HTTPoison.Response{status_code: status_code}} ->
            Logger.error("Failed to download CPE data, status code: #{status_code}")
            :error
        end
    end
  end

  def get_CVEs(cpe_name) do
    user_agent = UserAgent.random()

    case HTTPoison.get(@cve_url <> cpe_name, [{"User-Agent", user_agent}]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"vulnerabilities" => []}} ->
            {:error, :no_cve}

          {:ok, %{"vulnerabilities" => vulnerabilities}} ->
            vulnerabilities
            |> Enum.reduce(%{}, fn vulnerability, acc ->
              cve_id = vulnerability["cve"]["id"]

              cvss_data =
                case vulnerability["cve"]["metrics"]["cvssMetricV2"] do
                  nil ->
                    Enum.at(vulnerability["cve"]["metrics"]["cvssMetricV31"], 0)["cvssData"]

                  cvssMetricV2 ->
                    Enum.at(cvssMetricV2, 0)["cvssData"]
                end

              last_version =
                vulnerability["cve"]["configurations"]
                |> Enum.flat_map(fn config -> config["nodes"] end)
                |> Enum.flat_map(fn node -> node["cpeMatch"] end)
                |> Enum.filter(fn cpe_match -> cpe_match["vulnerable"] end)
                |> Enum.map(fn cpe_match -> cpe_match["versionEndExcluding"] end)
                |> List.first()

              Map.put(acc, cve_id, %{
                lastVersion: last_version || "Not specified",
                baseScore: cvss_data["baseScore"],
                description: Enum.at(vulnerability["cve"]["descriptions"], 0)["value"]
              })
            end)
            |> (fn res -> {:ok, res} end).()

          {:error, _} = error ->
            {:error, error}
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, {:unexpected_status_code, status_code}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # to this function work and optimized i tear my hair out
  def cpe_checker(app, version) do
    cpes_result = cpe_guesser(app)

    # Check if cpes is empty and return early
    case cpes_result do
      {:ok, cpes} when cpes == [] ->
        {:error, :no_cpe_found}

      {:ok, cpes} ->
        # Proceed with the rest of the function if cpes is not empty
        with :ok <- download_CPEs(),
             {:ok, body} <- File.read(Path.join(@local_cache_path, "nvdcpematch-1.0.json")),
             {:ok, %{"matches" => all_cpes}} <- Jason.decode(body) do
          let_cpes_patterns =
            Enum.map(cpes, fn cpe ->
              ~r/#{Regex.escape(cpe)}:#{Regex.escape(version)}($|:)/
            end)

          matches =
            all_cpes
            |> Enum.filter(fn %{"cpe23Uri" => cpe23Uri} -> String.contains?(cpe23Uri, app) end)
            |> Enum.reduce([], fn %{"cpe23Uri" => cpe23Uri, "cpe_name" => cpe_name}, acc ->
              matched_uris =
                if Enum.any?(let_cpes_patterns, &Regex.match?(&1, cpe23Uri)) do
                  [cpe23Uri]
                else
                  for %{"cpe23Uri" => name_uri} <- cpe_name,
                      Enum.any?(let_cpes_patterns, &Regex.match?(&1, name_uri)),
                      into: [],
                      do: name_uri
                end

              acc ++ matched_uris
            end)
            |> Enum.uniq()

          case matches do
            [] -> {:error, :no_cpe_found}
            _ -> {:ok, matches}
          end
        else
          error -> error
        end

      {:error, _} = error ->
        error
    end
  end

  defp cpe_guesser(app) do
    user_agent = UserAgent.random()

    case HTTPoison.post(@cpe_guesser_url, "{\"query\": [\"#{app}\"]}", [
           {"User-Agent", user_agent}
         ]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"results" => []}} ->
            {:error, :no_cpe}

          {:ok, results} ->
            results
            |> Enum.map(fn [_, cpe] -> cpe end)
            |> (fn res -> {:ok, res} end).()

          {:error, _} = error ->
            {:error, error}
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        Logger.error("Failed to get CPEs from cpe-guesser, status code: #{status_code}")
        {:error, {:unexpected_status_code, status_code}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
