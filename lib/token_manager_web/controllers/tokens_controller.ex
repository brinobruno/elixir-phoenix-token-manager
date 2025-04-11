defmodule TokenManagerWeb.TokensController do
  use TokenManagerWeb, :controller

  alias TokenManager.Tokens
  alias TokenManager.TokenUsages
  alias Tokens.Token
  alias TokenUsages.TokenUsage
  alias Tokens.TokenManager

  action_fallback TokenManagerWeb.FallbackController

  def create(conn, params) do
    with {:ok, %TokenUsage{} = token_usage} <- TokenManager.call(:allocate_token, params) do
      conn
      |> put_status(:created)
      |> render(:create, token_usage: token_usage)
    end
  end

  def index(conn, _params) do
    with {:ok, tokens} <- TokenManager.call(:list_tokens) do
      conn
      |> put_status(:ok)
      |> render(:get, tokens: tokens)
    end
  end

  def show(conn, %{"id" => id}) do
    with {:ok, %Token{} = token} <- TokenManager.call(:list_token, id) do
      conn
      |> put_status(:ok)
      |> render(:get, token: token)
    end
  end

  def show_usages(conn, %{"id" => id}) do
    with {:ok, usages} <- TokenManager.call(:list_usages, id) do
      conn
      |> put_status(:ok)
      |> render(:usages, usages: usages)
    end
  end

  def clear(conn, _params) do
    with {:ok, tokens} <- TokenManager.call(:release_all_tokens) do
      conn
      |> put_status(:ok)
      |> render(:get, tokens: tokens)
    end
  end
end
