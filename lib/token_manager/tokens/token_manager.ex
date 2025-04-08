defmodule TokenManager.Tokens.TokenManager do
  use GenServer

  require Logger

  alias TokenManager.Tokens.TokenService

  @max_active_token_duration_in_minutes 1

  # Client
  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def get_available_token(user_uuid) do
    GenServer.call(__MODULE__, {:get_token, user_uuid})
  end

  def release_token(token_uuid) do
    GenServer.cast(__MODULE__, {:release_token, token_uuid})
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

  # Handles manual release from client
  @impl true
  def handle_cast({:release_token, token_uuid}, state) do
    Logger.info("Manual release of token: #{token_uuid}")
    updated_tokens = do_release_token(state.tokens, token_uuid)
    {:noreply, %{state | tokens: updated_tokens}}
  end

  # Handles auto-release after timeout
  @impl true
  def handle_info({:release_token, token_uuid}, state) do
    Logger.info("Auto-release of token: #{token_uuid}")
    updated_tokens = do_release_token(state.tokens, token_uuid)
    {:noreply, %{state | tokens: updated_tokens}}
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

          schedule_token_release(updated_token.uuid)

          updated_tokens = update_token_list(tokens, updated_token)

          {token_usage, updated_tokens}
        {:error, reason} ->
          Logger.error("Failed to allocate token: #{inspect(reason)}")
          {:error, tokens}
      end
    else
      Logger.info("No available token found, releasing oldest token...")

      case release_oldest_token(tokens) do
        {:ok, {token_usage, updated_tokens}} ->
          allocate_token(updated_tokens, user_uuid)
        {:error, reason} ->
          Logger.error("Failed to release oldest token: #{inspect(reason)}")
          {:error, tokens}
      end
    end
  end

  defp do_release_token(tokens, token_uuid) do
    token_to_release = Enum.find(tokens, fn token -> token.uuid == token_uuid end)

    case TokenService.release_token(token_to_release) do
      {:ok, token_usage} ->
        updated_token = token_usage.token
        update_token_list(tokens, updated_token)
      {:error, reason} ->
        IO.puts("❌ Could not release a token: #{inspect(reason)}")
        tokens  # <-- fallback to current state if error
    end
  end


  defp release_oldest_token(tokens) do
    oldest_token = Enum.min_by(tokens, fn token -> token.activated_at end)

    IO.inspect(oldest_token, label: "🔍 Oldest Token")

    case TokenService.release_token(oldest_token) do
      {:ok, token_usage} ->
        updated_token = token_usage.token
        IO.inspect(updated_token, label: "✅ Updated Token")

        updated_tokens = update_token_list(tokens, updated_token)

        {:ok, {token_usage, updated_tokens}}

      {:error, reason} ->
        IO.puts("❌ Could not release a token: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp schedule_token_release(token_uuid) do
    Process.send_after(self(), {:release_token, token_uuid}, @max_active_token_duration_in_minutes * 60 * 1000)
  end

  defp update_token_list(tokens, updated_token) do
    Enum.map(tokens, fn
      t when t.id == updated_token.id -> updated_token
      t -> t
    end)
  end
end
