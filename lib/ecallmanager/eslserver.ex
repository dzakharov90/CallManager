defmodule Ecallmanager.ESLServer do

  require Logger
  # alias FSModEvent.Connection, as: C
  alias EventSocketOutbound


  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def start_link(_opts) do
    with {:ok, [port: port]} <- config() do
      Logger.info("Starting ESL server for FreeSWITCH on port #{port}\n\n")
      EventSocketOutbound.start(port: port)
    end
  end

  defp config, do: Application.fetch_env(:ecallmanager, __MODULE__)

end
