defmodule TokenManager.Tokens.TokenService do
  import Ecto.Query

  alias TokenManager.Repo
  alias TokenManager.Tokens
  alias Tokens.Token
  alias TokenManager.TokenUsages
  alias TokenUsages.TokenUsage

  @number_of_tokens 3

  def get_one_token(id) do
    case(Repo.get(Token, id, preload: [:usages])) do
      nil -> {:error, :not_found}
      token -> {:ok, token}
    end
  end

  def get_all_tokens() do
    tokens = Repo.all(Token, preload: [:usages])
    {:ok, tokens}
  end

  def initialize_tokens() do
    tokens = Repo.all(Token |> preload(:usages))

    if Enum.empty?(tokens) do
      generate_tokens()
      Repo.all(Token |> preload(:usages))
    else
      tokens
    end
  end


  defp generate_tokens() do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    1..@number_of_tokens
    |> Enum.map(fn _ ->
      %{
        status: "available",
        uuid: Ecto.UUID.generate(),
        inserted_at: now,
        updated_at: now,
        activated_at: nil
      }
    end)
    |> Stream.chunk_every(13)
    |> Task.async_stream(fn chunk -> Repo.insert_all(Token, chunk) end, max_concurrency: 8)
    |> Stream.run()
  end

  # TODO: update these @docs later
  @doc """
    Creates a new token usage in the database.
    iex> params = %{status: "active"}
    iex> TokenManager.Tokens.create(params)
  """

  @doc """
    Creates a new token usage for an existing token in the database.
    iex> token_params = %{status: "active"}
    iex> TokenManager.Tokens.create(params)
    iex> token_usageparams = %{token_id: 1, user_uuid: "c9007b1f-4ff3-4688-853e-d826cdb708ac", started_at: ~N[2025-04-05 12:00:00]}
    iex> TokenManager.TokenUsages.create()
  """
  defp update_token_usage(:create, params) do
    params
    |> TokenUsage.changeset()
    |> Repo.insert()
  end

  defp update_token_usage(:update, params) do
    with %{id: id} <- params,
     %TokenUsage{} = token_usage <- Repo.get(TokenUsage, id) do

      token_usage
      |> TokenUsage.changeset(params)
      |> Repo.update()
    else
      _ -> {:error, :not_found}
    end
  end

  def allocate_token(params) do
    updated_params = Map.put(params, "started_at", NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))

    case Repo.transaction(fn ->
          with {:ok, %TokenUsage{} = token_usage} <- update_token_usage(:create, updated_params),
                {:ok, _updated_token} <- update_token_status_and_time(:allocate, updated_params["token_id"]) do
            token_usage = Repo.preload(token_usage, :token)
            {:ok, token_usage}
          else
            error ->
              IO.inspect(error, label: "❌ allocate_token transaction error")
              Repo.rollback(error)
          end
        end) do
      {:ok, result} -> result
      {:error, reason} ->
        IO.inspect(reason, label: "❌ allocate_token outer error")
        {:error, %{message: inspect(reason)}}
    end
  end

  def release_token(token) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    case Repo.transaction(fn ->
      # Get the active usage (with no ended_at)
      usage =
        TokenUsage
        |> where([u], u.token_id == ^token.id and is_nil(u.ended_at))
        |> limit(1)
        |> Repo.one()

        IO.inspect(usage, label: "🔍 Inspecting usage")

      if usage do
        with {:ok, _updated_usage} <- update_token_usage(:update, %{id: usage.id, ended_at: now}),
             {:ok, _updated_token} <- update_token_status_and_time(:release, token.id) do
          {:ok, %{token: %{token | status: "available"}}}
        else
          error ->
            IO.inspect(error, label: "❌ release_token inner error")
            Repo.rollback(error)
        end
      else
        Repo.rollback(:no_active_usage_found)
      end
    end) do
      {:ok, result} -> result
      {:error, reason} -> {:error, %{message: inspect(reason)}}
    end
  end

  defp update_token_status_and_time(:release, token_id) do
    case get_one_token(token_id) do
      {:ok, token} ->
        token
        |> Token.changeset(%{
          status: "available"
        })
        |> Repo.update()

      {:error, :not_found} -> {:error, :not_found}
    end
  end

  defp update_token_status_and_time(:allocate, token_id) do
    case get_one_token(token_id) do
      {:ok, token} ->
        token
        |> Token.changeset(%{
          activated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
          status: "active"
        })
        |> Repo.update()

      {:error, :not_found} -> {:error, :not_found}
    end
  end
end
