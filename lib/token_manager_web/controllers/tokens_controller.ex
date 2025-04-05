defmodule TokenManagerWeb.TokensController do
  use TokenManagerWeb, :controller

  alias TokenManager.Tokens
  alias Tokens.Token

  action_fallback TokenManagerWeb.FallbackController

  def create(conn, params) do
    with {:ok, %Token{} = token} <- Tokens.create(params) do
      conn
      |> put_status(:created)
      |> render(:create, token: token)
    end
  end
end
