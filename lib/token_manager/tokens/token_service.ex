defmodule TokenManager.Tokens.TokenService do
  @behaviour TokenManager.Tokens.TokenServiceBehaviour

  import Ecto.Query

  require Logger

  alias TokenManager.Repo
  alias TokenManager.Tokens
  alias Tokens.Token
  alias TokenManager.TokenUsages
  alias TokenUsages.TokenUsage
  alias Tokens.Utils

  def get_one_token(token_uuid) do
    case Repo.get_by(Token, uuid: token_uuid) do
      nil -> {:error, :not_found}
      token -> {:ok, Repo.preload(token, :usages)}
    end
  end

  def get_all_tokens() do
    tokens =
      from(t in Token, preload: [:usages])
      |> Repo.all()

    {:ok, tokens}
  end

  def get_token_usages(token_id) do
    query = from(u in TokenUsage, where: u.token_id == ^token_id)
    usages = Repo.all(query)

    case usages do
      [] ->
        case Repo.get(Token, token_id) do
          nil -> {:error, :not_found}
          _ -> {:ok, []}
        end

      _ ->
        {:ok, usages}
    end
  end

  def initialize_tokens() do
    token_count = Repo.aggregate(Token, :count, :id)

    if token_count == 0 do
      generate_tokens()
      load_tokens_in_batches(token_count)
    else
      load_tokens_in_batches(token_count)
    end
  end

  defp load_tokens_in_batches(token_count) do
    max_concurrency = Utils.get(:max_concurrency)
    chunk_size = get_chunk_size(token_count, max_concurrency)

    {:ok, tokens} = Repo.transaction(fn ->
      Token
      |> Repo.stream()
      |> Stream.chunk_every(chunk_size)
      |> Task.async_stream(fn chunk ->
        Repo.preload(chunk, :usages)
      end, max_concurrency: max_concurrency)
      |> Enum.reduce([], fn {:ok, tokens}, acc -> acc ++ tokens end)
    end)

    tokens
  end

  def allocate_token(params) do
    updated_params =
      Map.put_new(params, "started_at", NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))

    case Repo.transaction(fn ->
          with {:ok, %TokenUsage{} = token_usage} <- update_token_usage(:create, updated_params),
                {:ok, _updated_token} <- update_token_status_and_time(:allocate, updated_params["token_uuid"]) do
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
    if token == nil do
      {:error, %{message: "Invalid token provided"}}
    else
      case Repo.transaction(fn ->
        do_release_token_and_usage(token)
      end) do
        {:ok, result} -> result
        {:error, reason} -> {:error, %{message: inspect(reason)}}
      end
    end
  end

  def release_tokens(tokens) do
    max_concurrency = Utils.get(:max_concurrency)
    chunk_size = get_chunk_size(length(tokens), max_concurrency)

    case Repo.transaction(fn ->
      tokens
      |> Stream.chunk_every(chunk_size)
      |> Task.async_stream(fn chunk ->
        Enum.map(chunk, fn token ->
          {:ok, %{token: updated_token}} = do_release_token_and_usage(token)
          updated_token
        end)
      end, max_concurrency: max_concurrency)
      |> Enum.reduce([], fn {:ok, updated_tokens}, acc -> acc ++ updated_tokens end)
    end) do
      {:ok, updated_tokens} -> {:ok, updated_tokens}
      {:error, reason} -> {:error, %{message: inspect(reason)}}
    end
  end

  defp generate_tokens() do
    total_tokens = Utils.get(:number_of_tokens)
    max_concurrency = Utils.get(:max_concurrency)
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    chunk_size = get_chunk_size(total_tokens, max_concurrency)

    1..total_tokens
    |> Enum.map(fn _ ->
      %{
        status: "available",
        uuid: Ecto.UUID.generate(),
        inserted_at: now,
        updated_at: now,
        activated_at: nil
      }
    end)
    |> Stream.chunk_every(chunk_size)
    |> Task.async_stream(fn chunk ->
      Repo.insert_all(Token, chunk)
    end, max_concurrency: max_concurrency)
    |> Stream.run()
  end

  defp get_chunk_size(total_tokens, max_concurrency) do
    # Calculate optimal chunk size (ceiling division to ensure all items are processed)
    div(total_tokens + max_concurrency - 1, max_concurrency)
  end

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

  defp do_release_token_and_usage(token) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    usage =
      TokenUsage
      |> where([u], u.token_id == ^token.id and is_nil(u.ended_at))
      |> limit(1)
      |> Repo.one()

    case usage do
      %TokenUsage{} = usage ->
        with {:ok, _updated_usage} <- update_token_usage(:update, %{id: usage.id, ended_at: now}),
             {:ok, _updated_token} <- update_token_status_and_time(:release, token.uuid) do
          {:ok, %{token: %{token | status: "available"}}}
        else
          error ->
            IO.inspect(error, label: "❌ release_token inner error")
            Repo.rollback(error)
        end
      nil ->
        Logger.warn("No active usage found for token of id: #{token.id}")
        {:ok, %{token: %{token | status: "available"}}}
    end
  end

  defp update_token_status_and_time(:release, token_uuid) do
    case get_one_token(token_uuid) do
      {:ok, token} ->
        token
        |> Token.changeset(%{
          status: "available"
        })
        |> Repo.update()

      {:error, :not_found} -> {:error, :not_found}
    end
  end

  defp update_token_status_and_time(:allocate, token_uuid) do
    case get_one_token(token_uuid) do
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
