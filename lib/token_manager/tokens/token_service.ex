defmodule TokenManager.Tokens.TokenService do
  import Ecto.Query

  alias TokenManager.Repo
  alias TokenManager.Tokens
  alias Tokens.Token
  alias TokenManager.TokenUsages
  alias TokenUsages.TokenUsage

  @number_of_tokens 100

  def get_one_token(id) do
    case(Repo.get(Token, id)) do
      nil -> {:error, :not_found}
      token -> {:ok, token}
    end
  end

  def get_all_tokens() do
    tokens = Repo.all(Token)
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

  @doc """
    Creates a new token usage in the database.
    iex> params = %{status: "active"}
    iex> TokenManager.Tokens.create(params)
  """
  def create_token(params) do
    params
    |> Token.changeset()
    |> Repo.insert()
  end

  @doc """
    Creates a new token usage for an existing token in the database.
    iex> token_params = %{status: "active"}
    iex> TokenManager.Tokens.create(params)
    iex> token_usageparams = %{token_id: 1, user_uuid: "c9007b1f-4ff3-4688-853e-d826cdb708ac", started_at: ~N[2025-04-05 12:00:00]}
    iex> TokenManager.TokenUsages.create()
  """
  def create_token_usage(params) do
    params
    |> TokenUsage.changeset()
    |> Repo.insert()
  end

  def allocate_token(params) do
    updated_params = Map.put(params, "started_at", NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))

    case Repo.transaction(fn ->
          with {:ok, %TokenUsage{} = token_usage} <- create_token_usage(updated_params),
                {:ok, _updated_token} <- update_token_status_and_time(updated_params["token_id"]) do
            token_usage = Repo.preload(token_usage, :token)
            {:ok, token_usage}
          else
            error -> Repo.rollback(error)
          end
        end) do
      {:ok, result} -> result
      {:error, reason} -> {:error, %{message: inspect(reason)}}
    end
  end

  defp update_token_status_and_time(token_id) do
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
