defmodule TokenManager.Factory do
  use ExMachina.Ecto, repo: TokenManager.Repo

  alias TokenManager.Tokens.Token
  alias TokenManager.TokenUsages.TokenUsage

  @doc """
  Usage:
  - creates a token in the database with status: "available".
    insert(:token)
  - build(:token, status: "active", activated_at: ~N[2025-04-14 20:00:00])
    creates a token struct with custom values.
  """
  def token_factory do
    %Token{
      status: "available",
      uuid: Ecto.UUID.generate(),
      activated_at: nil
    }
  end

  @doc """
  Usage:
  - inserts a TokenUsage with an associated Token in the database.
    insert(:usage)
  - creates a usage struct with a custom ended_at.
    build(:usage, ended_at: ~N[2025-04-14 20:01:00])
  - links to a specific token.
    insert(:usage, token: insert(:token, status: "active"))
  """
  def usage_factory do
    %TokenUsage{
      token: build(:token),
      user_uuid: Ecto.UUID.generate(),
      started_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second),
      ended_at: nil
    }
  end
end
