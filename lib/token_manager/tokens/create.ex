defmodule TokenManager.Tokens.Create do
  alias TokenManager.Tokens.Token
  alias TokenManager.Repo

  @doc """
    Creates a new token in the database.
    iex> params = %{status: "active"}
    iex> TokenManager.Token.create(params)
  """

  def call(params) do
    params
    |> Token.changeset()
    |> Repo.insert()
  end
end
