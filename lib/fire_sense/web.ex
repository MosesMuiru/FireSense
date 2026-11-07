defmodule FireSense.Web do
  @moduledoc """
  Live dashboard and JSON API for the fire-detection experiment.

  * `GET /` dashboard with graphs
  * `GET /api/data?since=<unix seconds>` new samples and events
  * `POST /api/start`, `POST /api/stop` recording sessions
  * `POST /api/mark` with `{"note": "..."}` event marks
  """
  use Plug.Router

  alias FireSense.Recorder

  @index Path.expand("../../priv/static/index.html", __DIR__)
  @external_resource @index
  @html File.read!(@index)

  plug(:match)
  plug(Plug.Parsers, parsers: [:json], pass: ["*/*"], json_decoder: Jason)
  plug(:dispatch)

  get "/" do
    conn |> put_resp_content_type("text/html") |> send_resp(200, @html)
  end

  get "/api/data" do
    conn = fetch_query_params(conn)

    since =
      case Float.parse(conn.query_params["since"] || "0") do
        {t, _} -> t
        :error -> 0.0
      end

    data = Recorder.since(since)
    json(conn, Map.put(data, :status, status()))
  end

  post "/api/start" do
    _ = Recorder.start_session()
    json(conn, %{status: status()})
  end

  post "/api/stop" do
    _ = Recorder.stop_session()
    json(conn, %{status: status()})
  end

  post "/api/mark" do
    case conn.body_params do
      %{"note" => note} when is_binary(note) and note != "" ->
        :ok = Recorder.mark(String.slice(note, 0, 60))
        json(conn, %{ok: true})

      _ ->
        send_resp(conn, 422, ~s({"error":"note is required"}))
    end
  end

  match _ do
    send_resp(conn, 404, "not found")
  end

  defp status do
    s = Recorder.status()
    %{session: s.session, rows: s.rows}
  end

  defp json(conn, data) do
    conn |> put_resp_content_type("application/json") |> send_resp(200, Jason.encode!(data))
  end
end
