defmodule TokenManager.Tokens.TokenManager do
  use GenServer

  require Logger

  alias TokenManager.Tokens
  alias Tokens.TokenService
  alias Tokens.Utils

  @token_service Application.compile_env(:token_manager, :token_service, TokenService)

  # Client (Public API)
  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  @doc """
  Handles various token-related operations.
    - Lists all active and available tokens:
    iex> TokenManager.Tokens.TokenManager.call(:list_tokens)

    - Lists one token:
    iex> token_uuid = "5f1448c2-9228-49b7-95eb-fc2352245960"
    iex> TokenManager.Tokens.TokenManager.call(:list_token, token_uuid)

    - Lists one token usage:
    iex> TokenManager.Tokens.TokenManager.call(:list_usages, 1)

    - Assigns a token to a user:
    iex> any_uuid = "5f1448c2-9228-49b7-95eb-fc2352245960"
    iex> TokenManager.Tokens.TokenManager.call(:allocate_token, any_uuid)

    - Releases all tokens:
    iex> existing_token_uuid = "5f1448c2-9228-49b7-95eb-fc2352245960"
    iex> TokenManager.Tokens.TokenManager.call(existing_token_uuid)
  """
  def call(:list_tokens) do
    GenServer.call(__MODULE__, :list_tokens)
  end

  def call(:release_all_tokens) do
    GenServer.call(__MODULE__, :release_all_tokens)
  end

  def call(:list_token, token_uuid) do
    GenServer.call(__MODULE__, {:list_token, token_uuid})
  end

  def call(:list_usages, token_id) do
    GenServer.call(__MODULE__, {:list_usages, token_id})
  end

  def call(:allocate_token, %{"user_uuid" => user_uuid}) do
    GenServer.call(__MODULE__, {:allocate_token, user_uuid})
  end

  # Server (GenServer Callbacks)
  @impl true
  def init(_state) do
    tokens = @token_service.initialize_tokens()
    Logger.info("✅ Tokens initialized: #{length(tokens)}")

    # Schedule periodic expiration check
    Process.send_after(self(), :check_expiry, Utils.get(:check_interval_in_seconds) * 1000)

    {:ok, %{tokens: tokens}}
  end

  @impl true
  def handle_call(:list_tokens, _from, state) do
    tokens = @token_service.get_all_tokens()
    {:reply, tokens, state}
  end

  @impl true
  def handle_call({:list_token, token_uuid}, _from, state) do
    token_result = @token_service.get_one_token(token_uuid)

    case token_result do
      {:ok, token} ->
        {:reply, {:ok, token}, state}
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:list_usages, token_id}, _from, state) do
    token_usage_result = @token_service.get_token_usages(token_id)

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
    {:reply, {:ok, updated_tokens}, %{state | tokens: updated_tokens}}
  end

  @impl true
  def handle_cast({:release_token, token_uuid}, state) do
    Logger.info("Manual release of token: #{token_uuid}")
    updated_tokens = do_release_token(state.tokens, token_uuid)
    {:noreply, %{state | tokens: updated_tokens}}
  end

  @impl true
  def handle_info(:check_expiry, state) do
    {updated_tokens, expired} = check_and_release_expired()

    if expired, do: Logger.info("Periodic check released expired tokens")

    # Reschedule the check
    Process.send_after(self(), :check_expiry, Utils.get(:check_interval_in_seconds) * 1000)
    {:noreply, %{state | tokens: updated_tokens}}
  end

  defp allocate_token(_tokens, user_uuid) do
    # Check for expired tokens first
    {tokens_after_expiry, _expired} = check_and_release_expired()
    available_token = Enum.find(tokens_after_expiry, fn token -> token.status == "available" end)

    if available_token do
      case @token_service.allocate_token(%{
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
        case @token_service.release_token(token) do
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
    case @token_service.release_tokens(tokens) do
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

  defp check_and_release_expired do
    now = NaiveDateTime.utc_now()
    expiration_threshold = NaiveDateTime.add(now, -Utils.get(:max_active_token_duration_in_minutes) * 60, :second)

    # Fetch only active tokens that might be expired
    {:ok, expired_tokens} = @token_service.get_expired_tokens(expiration_threshold)

    {updated_tokens, expired_flag} =
      Enum.reduce(expired_tokens, {[], false}, fn token, {acc_tokens, expired_flag} ->
        case @token_service.release_token(token) do
          {:ok, token_usage} ->
            Logger.info("✅ Expired token released: #{token.uuid}")
            {acc_tokens ++ [token_usage.token], true}
          {:error, reason} ->
            Logger.error("❌ Could not release token #{token.uuid}: #{inspect(reason)}")
            {acc_tokens ++ [token], expired_flag}
        end
      end)

    {:ok, all_tokens} = @token_service.get_all_tokens()
    {Enum.map(all_tokens, fn t ->
       case Enum.find(updated_tokens, &(&1.id == t.id)) do
         nil -> t
         updated -> updated
       end
     end), expired_flag}
  end

  defp update_token_list(tokens, updated_token) do
    Enum.map(tokens, fn
      t when t.id == updated_token.id -> updated_token
      t -> t
    end)
  end
end
