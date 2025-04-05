defmodule TokenManager.Tokens.Allocate do
  alias TokenManager.Tokens
  alias Tokens.Token
  alias TokenManager.TokenUsages
  alias TokenUsages.TokenUsage

  alias TokenManager.Repo

  def call(params) do
    updated_params = Map.put(params, "started_at", NaiveDateTime.utc_now())

    case Repo.transaction(fn ->
          with {:ok, %TokenUsage{} = token_usage} <- TokenUsages.Create.call(updated_params),
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
    case Tokens.GetOne.call(token_id) do
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
