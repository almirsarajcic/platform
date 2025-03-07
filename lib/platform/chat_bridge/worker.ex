defmodule Platform.ChatBridge.Worker do
  @moduledoc "Talks to Chat through PubSub"

  require Logger

  use GenServer

  alias Phoenix.PubSub
  alias Platform.ChatBridge.Logic

  @incoming_topic "chat->platform"
  @outgoing_topic "platform->chat"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, Keyword.merge([name: __MODULE__], opts))
  end

  @impl true
  def init(_) do
    Process.send_after(self(), :init, 1000)

    {:ok, %{}}
  end

  @impl true
  def handle_info(:init, state) do
    PubSub.subscribe(Chat.PubSub, @incoming_topic)

    noreply(state)
  end

  def handle_info(message, state) do
    case message do
      :get_wifi_settings -> Logic.get_wifi_settings()
      {:set_wifi, ssid} -> Logic.set_wifi_settings(ssid)
      {:set_wifi, ssid, password} -> Logic.set_wifi_settings(ssid, password)
      :get_device_log -> Logic.get_device_log()
      :unmount_main -> Logic.unmount_main()
    end
    |> respond()

    noreply(state)
  end

  defp noreply(x), do: {:noreply, x}

  defp respond(message) do
    # Logger.info("Platform responds: " <> inspect(message, pretty: true))
    PubSub.broadcast(Chat.PubSub, @outgoing_topic, {:platform_response, message})
  end
end
