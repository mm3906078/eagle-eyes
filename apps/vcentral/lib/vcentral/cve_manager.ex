defmodule Vcentral.CVEManager do
  require Logger

  @cpe_url "https://services.nvd.nist.gov/rest/json/cpes/2.0?keywordSearch="
  @cve_url "https://services.nvd.nist.gov/rest/json/cves/2.0?cpeName="
  @cpe_url_local "https://nvd.nist.gov/feeds/json/cpematch/1.0/nvdcpematch-1.0.json.zip"
  @local_cache_path "/tmp/"

  def check_vulnerabilities(app, version) do
    case get_CPEs(app, version) do
      {:ok, cpes} ->
        cpes
        |> Enum.reduce(%{}, fn cpe, acc ->
          case get_CVEs(cpe) do
            {:ok, cves} ->
              Map.put(acc, cpe, cves)

            {:error, error} ->
              Logger.error("Failed to get CVEs for CPE: #{cpe}, error: #{inspect(error)}")
              acc
          end
        end)
        |> (fn res -> {:ok, res} end).()

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp get_CPEs(app, version) do
    user_agent = UserAgent.random()

    case HTTPoison.get(@cpe_url <> app, [{"User-Agent", user_agent}]) do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        case Jason.decode(body) do
          {:ok, %{"products" => []}} ->
            {:error, :no_cpe}

          {:ok, %{"products" => products}} ->
            products
            |> Enum.reduce([], fn product, acc ->
              case Enum.find(product["cpe"]["titles"], fn title ->
                     String.contains?(title["title"], version)
                   end) do
                nil -> acc
                _title -> [product["cpe"]["cpeName"] | acc]
              end
            end)
            |> case do
              [] -> {:error, :no_matching_version}
              cpes -> {:ok, cpes}
            end

          {:error, _} = error ->
            error
        end

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, {:unexpected_status_code, status_code}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_CPEs_local(app, version) do
    case download_CPEs() do
      :ok ->
        case File.read(Path.join(@local_cache_path, "nvdcpematch-1.0.json")) do
          {:ok, body} ->
            case Jason.decode(body) do
              {:ok, %{"matches" => matches}} ->
                matches
                |> Enum.reduce([], fn match, acc ->
                  acc ++ filter_matches(match, app, version)
                end)
                |> Enum.uniq_by(& &1)
                |> case do
                  [] -> {:error, :no_cpe}
                  unique_cpes -> {:ok, unique_cpes}
                end

              {:error, _} = error ->
                {:error, error}
            end

          {:error, _} = error ->
            {:error, error}
        end

      :error ->
        :error
    end
  end

  defp filter_matches(%{"cpe23Uri" => cpe23Uri, "cpe_name" => cpe_names}, app, version) do
    if String.contains?(cpe23Uri, app) do
      for %{"cpe23Uri" => cpe_name_uri} <- cpe_names,
          String.contains?(cpe_name_uri, version),
          do: cpe_name_uri
    else
      []
    end
  end

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

              Map.put(acc, cve_id, %{
                #TODO: last version is false, we should read it in the description
                lastVersion: cvss_data["version"],
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
end
