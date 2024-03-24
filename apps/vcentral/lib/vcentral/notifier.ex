defmodule Vcentral.Notifier do
  @telegram_api "https://api.telegram.org/bot"
  def create_message(node, cves) do
    header = "--- #{node} ---"
    footer = "------------"

    apps_messages =
      Enum.map(cves, fn {app, cve_data} ->
        cve_ids = Enum.map(cve_data, fn {cve_id, _details} -> cve_id end)
        "app = \"#{app}\", cve = #{inspect(cve_ids)}"
      end)

    message_body = Enum.join(apps_messages, "\n")

    result = "#{header}\n#{message_body}\n#{footer}"

    {:ok, result}
  end

  def send_message_telegram(message) do
    token = Application.get_env(:vcentral, :telegram_bot_token)
    chat_id = Application.get_env(:vcentral, :telegram_chat_id)
    url = "#{@telegram_api}#{token}/sendMessage"
    body = %{"chat_id" => chat_id, "text" => message}
    headers = [{"Content-Type", "application/json"}]

    case HTTPoison.post(url, Jason.encode!(body), headers) do
      {:ok, %HTTPoison.Response{status_code: 200, body: response_body}} ->
        {:ok, Jason.decode!(response_body)}

      {:ok, %HTTPoison.Response{status_code: status_code}} ->
        {:error, {:http_error, status_code}}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end
end
