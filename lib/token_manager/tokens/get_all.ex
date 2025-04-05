defmodule TokenManager.Tokens.GetAll do
  alias TokenManager.Tokens.Token
  alias TokenManager.Repo

  def call() do
    tokens = Repo.all(Token)
    {:ok, tokens}
  end
end
