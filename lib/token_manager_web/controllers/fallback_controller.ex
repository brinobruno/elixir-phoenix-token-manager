defmodule TokenManagerWeb.FallbackController do
  use TokenManagerWeb, :controller

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> put_view(json: TokenManagerWeb.ErrorJSON)
    |> render(:error, status: :not_found)
  end

  def call(conn, {:error, :bad_request}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: TokenManagerWeb.ErrorJSON)
    |> render(:error, status: :bad_request)
  end

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: TokenManagerWeb.ErrorJSON)
    |> render(:error, changeset: changeset)
  end

  def call(conn, {:error, message}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: TokenManagerWeb.ErrorJSON)
    |> render(:error, message: message)
  end
end
