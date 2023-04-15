defmodule Ecallmanager.Callmgm do
  @moduledoc """
  Sample module implements call routing logic
  """
  # @behaviour EventSocketOutbound.CallMgmt

  require Logger
  use GenServer
  alias EventSocketOutbound.Protocol, as: EventProtocol

  def start_link(pid) do
    GenServer.start_link(__MODULE__, {pid})
  end

  def onEvent(pid, event) do
    GenServer.cast(pid, {:event, event})
  end

  #
  # GenServer Callbacks
  #
  @doc false
  def init({pid}) do
    send(self(), :start_up)
    {:ok, %{:tcp_server => pid}}
  end

  @doc false
  def handle_cast({:event, %{"Event-Name" => "DETECTED_SPEECH"}}, state) do
      {:ok, data} = EventProtocol.connect(state.tcp_server)
      Logger.info("Speech detected!")
      Logger.info("DETECTED_SPEECH result: #{inspect(data)}")
      {:noreply, state}
  end

  @doc false
  def handle_cast({:event, _event}, state) do
    {:noreply, state}
  end

  @doc false
  def handle_info(:start_up, state) do
    {:ok, data} = EventProtocol.connect(state.tcp_server)
    Logger.info("data is: #{inspect(data)}")
    Logger.info("CallManager call started")
    my_uuid = Map.get(data, "Channel-Unique-ID")
    {:ok, _} = EventProtocol.filter(state.tcp_server, "Unique-ID " <> my_uuid)
    {:ok, _} = EventProtocol.eventplain(state.tcp_server, "DETECTED_SPEECH")
    {:ok, _} = EventProtocol.answer(state.tcp_server)
    playback_args = "ivr/ivr-welcome.wav"
    {:ok, _} = EventProtocol.execute(state.tcp_server, "playback", playback_args)
    #{:ok, _} = EventProtocol.execute(state.tcp_server, "detect_speech", "nogrammar grammarsalloff")
    {:ok, _} = EventProtocol.execute(state.tcp_server, "detect_speech", "pocketsphinx yesno yesno")
    {:noreply, state}
  end
end
