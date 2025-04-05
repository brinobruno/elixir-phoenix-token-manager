defmodule TokenManager.Tokens.Create do
  alias TokenManager.Tokens.Token
  alias TokenManager.Repo

  @doc """
    Creates a new token usage for an existing token in the database.
    iex> token_params = %{status: "active"}
    iex> TokenManager.Tokens.create(params)
    iex> token_usageparams = %{token_id: 1, user_uuid: "c9007b1f-4ff3-4688-853e-d826cdb708ac", started_at: ~N[2025-04-05 12:00:00]}
    iex> TokenManager.TokenUsages.create()
  """

  def call(params) do
    params
    |> Token.changeset()
    |> Repo.insert()
  end
end
