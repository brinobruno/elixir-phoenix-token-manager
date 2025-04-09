defmodule TokenManagerWeb.TokensController do
  use TokenManagerWeb, :controller

  alias TokenManager.Tokens
  alias TokenManager.TokenUsages
  alias Tokens.Token
  alias TokenUsages.TokenUsage
  alias Tokens.TokenManager

  action_fallback TokenManagerWeb.FallbackController

  def create(conn, params) do
    with {:ok, %TokenUsage{} = token_usage} <- TokenManager.get_available_token(params) do
      conn
      |> put_status(:created)
      |> render(:create, token_usage: token_usage)
    end
  end

  def index(conn, _params) do
    with {:ok, tokens} <- TokenManager.list_all_tokens() do
      conn
      |> put_status(:ok)
      |> render(:get, tokens: tokens)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, %Token{} = token} <- TokenManager.list_one_token(id) do
      conn
      |> put_status(:ok)
      |> render(:get, token: token)
    end
  end
end
