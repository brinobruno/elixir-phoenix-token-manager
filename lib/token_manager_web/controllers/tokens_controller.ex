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

  def index(conn, _params) do
    with {:ok, tokens} <- Tokens.get_all() do
      conn
      |> put_status(:ok)
      |> render(:get, tokens: tokens)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, %Token{} = token} <- Tokens.get_one(id) do
      conn
      |> put_status(:ok)
      |> render(:get, token: token)
    end
  end
end
