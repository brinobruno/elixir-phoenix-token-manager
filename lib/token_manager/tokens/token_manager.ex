defmodule TokenManager.Tokens.TokenManager do
  use GenServer

  require Logger

  alias TokenManager.Tokens.TokenService

  # Client
  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def get_available_token(user_uuid) do
    GenServer.call(__MODULE__, {:get_token, user_uuid})
  end

  # Server
  @impl true
  def init(_state) do
    tokens = TokenService.initialize_tokens()
    Logger.info("Tokens initialized: #{inspect(tokens)}")

    # schedule_event()

    {:ok, %{tokens: tokens}}
  end

  @impl true
  def handle_info(:initialize_tokens, state) do
    tokens = TokenService.initialize_tokens()
    Logger.info("Tokens initialized (from :initialize_tokens): #{inspect(tokens)}")

    {:noreply, %{state | tokens: tokens}}
  end

  @impl true
  def handle_call({:get_token, user_uuid}, _from, state) do
    # Logic to allocate a token, releasing oldest if necessary
    {token, updated_tokens} = allocate_token(state.tokens, user_uuid)
    {:reply, token, %{state | tokens: updated_tokens}}
  end

  def allocate_token(tokens, user_uuid) do
    available_token =
      case tokens do
        tokens when is_list(tokens) ->
          Enum.find(tokens, fn token ->
            IO.inspect(token, label: "🔍 Inspecting token")
            token.status == "available"
          end)

        _ ->
          IO.puts("❌ Tokens is not a list!")
          nil
      end

    if available_token do
      case TokenService.allocate_token(%{
        "token_id" => available_token.id,
        "user_uuid" => user_uuid
      }) do
        {:ok, token_usage} ->
          updated_token = token_usage.token

          updated_tokens =
            Enum.map(tokens, fn
              t when t.id == updated_token.id -> updated_token
              t -> t
            end)

          {token_usage, updated_tokens}
        {:error, reason} ->
          Logger.error("Failed to allocate token: #{inspect(reason)}")
          {:error, tokens}
      end
    else
      Logger.info("No available token found, releasing oldest token...")

      case release_oldest_token(tokens) do
        {:ok, {token_usage, updated_tokens}} ->
          IO.inspect(token_usage.token, label: "✅ Updated Token")

          allocate_token(updated_tokens, user_uuid)

        {:error, reason} ->
          Logger.error("Failed to release oldest token: #{inspect(reason)}")
          {:error, tokens}
      end
    end
  end

  defp release_oldest_token(tokens) do
    oldest_token = Enum.min_by(tokens, fn token -> token.activated_at end)

    IO.inspect(oldest_token, label: "🔍 Oldest Token")

    case TokenService.release_token(oldest_token) do
      {:ok, token_usage} ->
        updated_token = token_usage.token
        IO.inspect(updated_token, label: "✅ Updated Token")

        updated_tokens =
          Enum.map(tokens, fn
            t when t.id == updated_token.id -> updated_token
            t -> t
          end)

        IO.inspect(Enum.find(updated_tokens, fn token -> token.id == 100 end), label: "✅ Updated Token last")

        {:ok, {token_usage, updated_tokens}}

      {:error, reason} ->
        IO.puts("❌ Could not release a token: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
