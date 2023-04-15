defmodule Ecallmanager.Routes do
  use Plug.Router
  use Plug.Debugger
  use Plug.ErrorHandler

  alias Ecallmanager.Directory
  alias Ecallmanager.Dialplan
  alias Ecallmanager.Configuration
  #alias Ecallmanager.Callrouting
  alias Plug.{Cowboy}

  require Logger

  plug(Plug.Logger, log: :debug)
  plug(:match)

  plug Plug.Parsers,
  parsers: [:urlencoded, {:json, json_decoder: Jason}]

  plug(:dispatch)

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def start_link(_opts) do
    with {:ok, [port: port] = config} <- config() do
      Logger.info("Starting server at http://localhost:#{port}/")
      Cowboy.http(__MODULE__, [], config)
      #Callrouting
    end
  end

  forward "/api/v1/DirectoryXML", to: Directory

  forward "/api/v1/DialplanXML", to: Dialplan

  forward "/api/v1/ConfigurationXML", to: Configuration

  match _ do
    send_resp(conn, 404, "oops")
  end

  defp config, do: Application.fetch_env(:ecallmanager, __MODULE__)

  def handle_errors(%{status: status} = conn, %{kind: _kind, reason: _reason, stack: _stack}),
    do: send_resp(conn, status, "Something went wrong")

end
