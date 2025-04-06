defmodule TokenManager.Tokens.TokenManager do
  use GenServer

  require Logger

  alias TokenManager.Tokens.TokenService

  # Server
  def init(_state) do
    tokens = TokenService.initialize_tokens()
    Logger.info("Tokens initialized: #{inspect(tokens)}")

    # schedule_event()

    {:ok, %{tokens: tokens}}
  end

  def handle_info(:initialize_tokens, state) do
    tokens = TokenService.initialize_tokens()
    Logger.info("Tokens initialized (from :initialize_tokens): #{inspect(tokens)}")

    {:noreply, %{state | tokens: tokens}}
  end

  # Client
  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end
end
