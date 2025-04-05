defmodule TokenManager.TokenUsages.Create do
  alias TokenManager.TokenUsages.TokenUsage
  alias TokenManager.Repo

  @doc """
    Creates a new token usage in the database.
    iex> params = %{status: "active"}
    iex> TokenManager.Tokens.create(params)
  """

  def call(params) do
    params
    |> TokenUsage.changeset()
    |> Repo.insert()
  end
end
