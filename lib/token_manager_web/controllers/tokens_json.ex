defmodule TokenManagerWeb.TokensJSON do
  alias TokenManager.Tokens.Token

  def create(%{token: token}) do
    %{
      message: "Token created successfully",
      data: data(token)
    }
  end

  defp data(%Token{} = token) do
    %{
      id: token.id,
      uuid: token.uuid,
      status: token.status,
      activated_at: token.activated_at
    }
  end
end
