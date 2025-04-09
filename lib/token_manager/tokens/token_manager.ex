defmodule TokenManager.Tokens.TokenManager do
  use GenServer

  require Logger

  alias TokenManager.Tokens
  alias Tokens.TokenService
  alias Tokens.Utils

  # Client
  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @doc """
    Lists all active and available tokens.
    iex> TokenManager.Tokens.TokenManager.list_all_tokens
  """
  def list_all_tokens() do
    GenServer.call(__MODULE__, :list_tokens)
  end

  @doc """
    Lists one token.
    iex> TokenManager.Tokens.TokenManager.list_one_token
  """
  def list_one_token(token_uuid) do
    GenServer.call(__MODULE__, {:list_token, token_uuid})
  end

  @doc """
    List one token.
    iex> TokenManager.Tokens.TokenManager.list_one_token
  """
  def list_token_usages(token_id) do
    GenServer.call(__MODULE__, {:list_usages, token_id})
  end

  @doc """
    Assigns a token to a user.
    iex> any_uuid = "5f1448c2-9228-49b7-95eb-fc2352245960"
    iex> TokenManager.Tokens.TokenManager.get_available_token(any_uuid)
  """
  def get_available_token(%{"user_uuid" => user_uuid}) do
    GenServer.call(__MODULE__, {:allocate_token, user_uuid})
  end

  @doc """
    Releases all tokens.
    iex> TokenManager.Tokens.TokenManager.release_all_tokens
  """
  def release_all_tokens() do
    GenServer.call(__MODULE__, :release_all_tokens)
  end

  @doc """
    Releases a token.
    iex> existing_token_uuid = "5f1448c2-9228-49b7-95eb-fc2352245960"
    iex> TokenManager.Tokens.TokenManager.release_token(existing_token_uuid)
  """
  def release_token(token_uuid) do
    GenServer.cast(__MODULE__, {:release_token, token_uuid})
  end

  # Server
  @impl true
  def init(_state) do
    tokens = TokenService.initialize_tokens()
    Logger.info("✅ Tokens initialized: #{inspect(tokens)}")

    # Schedule periodic expiration check
    Process.send_after(self(), :check_expiry, Utils.get(:check_interval_in_seconds) * 1000)

    {:ok, %{tokens: tokens}}
  end

  @impl true
  def handle_call(:list_tokens, _from, state) do
    tokens = TokenService.get_all_tokens()
    {:reply, tokens, state}
  end

  @impl true
  def handle_call({:list_token, token_uuid}, _from, state) do
    token_result = TokenService.get_one_token(token_uuid)

    case token_result do
      {:ok, token} ->
        {:reply, {:ok, token}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:list_usages, token_id}, _from, state) do
    token_usage_result = TokenService.get_token_usages(token_id)

    case token_usage_result do
      {:ok, usages} ->
        {:reply, {:ok, usages}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:allocate_token, user_uuid}, _from, state) do
    {token_result, updated_tokens} = allocate_token(state.tokens, user_uuid)

    case token_result do
      {:ok, token_usage} ->
        {:reply, {:ok, token_usage}, %{state | tokens: updated_tokens}}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call(:release_all_tokens, _from, state) do
    Logger.info("Manual release of all tokens")
    updated_tokens = do_release_token(state.tokens)
    {:reply, :ok, %{state | tokens: updated_tokens}}
  end

  @impl true
  def handle_cast({:release_token, token_uuid}, state) do
    Logger.info("Manual release of token: #{token_uuid}")
    updated_tokens = do_release_token(state.tokens, token_uuid)
    {:noreply, %{state | tokens: updated_tokens}}
  end

  @impl true
  def handle_info(:check_expiry, state) do
    {updated_tokens, expired} = check_and_release_expired(state.tokens)

    if expired, do: Logger.info("Periodic check released expired tokens")

    # Reschedule the check
    Process.send_after(self(), :check_expiry, Utils.get(:check_interval_in_seconds) * 1000)
    {:noreply, %{state | tokens: updated_tokens}}
  end

  def allocate_token(tokens, user_uuid) do
    # Check for expired tokens first
    {tokens_after_expiry, _expired} = check_and_release_expired(tokens)
    available_token = Enum.find(tokens_after_expiry, fn token -> token.status == "available" end)

    if available_token do
      case TokenService.allocate_token(%{
        "token_id" => available_token.id,
        "token_uuid" => available_token.uuid,
        "user_uuid" => user_uuid
      }) do
        {:ok, token_usage} ->
          updated_token = token_usage.token
          updated_tokens = update_token_list(tokens_after_expiry, updated_token)

          {{:ok, token_usage}, updated_tokens}
        {:error, reason} ->
          Logger.error("❌ Failed to allocate token: #{inspect(reason)}")
          {{:error, reason}, tokens_after_expiry}
      end
    else
      Logger.info("No available token found, releasing oldest token...")
      case release_oldest_token(tokens_after_expiry) do
        {:ok, updated_tokens} ->
          allocate_token(updated_tokens, user_uuid)
        {:error, reason} ->
          Logger.error("❌ ailed to release oldest token: #{inspect(reason)}")
          {{:error, reason}, tokens_after_expiry}
      end
    end
  end

  defp do_release_token(tokens, token_uuid) do
    token_to_release = Enum.find(tokens, fn token -> token.uuid == token_uuid end)

    case token_to_release do
      nil ->
        Logger.warn("⚠️ Token not found for release: #{token_uuid}")
        tokens
      token ->
        case TokenService.release_token(token) do
          {:ok, token_usage} ->
            updated_token = token_usage.token
            update_token_list(tokens, updated_token)
          {:error, reason} ->
            Logger.error("❌ Could not release token #{token_uuid}: #{inspect(reason)}")
            tokens
        end
    end
  end

  defp do_release_token(tokens) do
    case TokenService.release_tokens(tokens) do
      {:ok, updated_tokens} ->
        updated_tokens
      {:error, reason} ->
        Logger.error("❌ Could not release all tokens: #{inspect(reason)}")
        tokens
    end
  end

  defp release_oldest_token(tokens) do
    active_tokens = Enum.filter(tokens, fn token -> token.status == "active" end)
    oldest_token = Enum.min_by(active_tokens, fn token -> token.activated_at end, fn -> nil end)

    case oldest_token do
      nil ->
        {:error, :no_active_tokens_available}
      token ->
        updated_tokens = do_release_token(tokens, token.uuid)
        if updated_tokens != tokens do
          Logger.info("✅ Oldest token released successfully: #{token.uuid}")
          {:ok, updated_tokens}
        else
          {:error, :release_failed}
        end
    end
  end

  defp check_and_release_expired(tokens) do
    now = NaiveDateTime.utc_now()
    expiration_threshold = NaiveDateTime.add(now, -Utils.get(:max_active_token_duration_in_minutes) * 60, :second)

    Enum.reduce(tokens, {tokens, false}, fn token, {acc_tokens, expired_flag} ->
      if token.status == "active" && NaiveDateTime.compare(token.activated_at, expiration_threshold) == :lt do
        updated_tokens = do_release_token(acc_tokens, token.uuid)
        Logger.info("✅ Expired token released: #{token.uuid}")
        {updated_tokens, true}
      else
        {acc_tokens, expired_flag}
      end
    end)
  end

  defp update_token_list(tokens, updated_token) do
    Enum.map(tokens, fn
      t when t.id == updated_token.id -> updated_token
      t -> t
    end)
  end
end
