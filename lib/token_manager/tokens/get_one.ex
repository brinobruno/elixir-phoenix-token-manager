defmodule TokenManager.Tokens.GetOne do
  alias TokenManager.Tokens.Token
  alias TokenManager.Repo

  def call(id) do
    case(Repo.get(Token, id)) do
      nil -> {:error, :not_found}
      token -> {:ok, token}
    end
  end
end
