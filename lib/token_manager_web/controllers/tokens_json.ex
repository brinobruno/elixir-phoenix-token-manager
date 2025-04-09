defmodule TokenManagerWeb.TokensJSON do
  alias TokenManager.Tokens.Token
  alias TokenManager.TokenUsages.TokenUsage

  def create(%{token_usage: token_usage}) do
    %{
      message: "Token allocated successfully",
      token_usage: data(token_usage)
    }
  end

  def get(%{token: token}), do: %{data: data(token)}
  def get(%{tokens: tokens}), do: %{data: Enum.map(tokens, &data/1)}
  def usages(%{usages: usages}), do: %{data: Enum.map(usages, &data/1)}

  defp data(%Token{} = token) do
    %{
      id: token.id,
      uuid: token.uuid,
      status: token.status,
      activated_at: token.activated_at
    }
  end

  defp data(%TokenUsage{} = token_usage) do
    %{
      id: token_usage.id,
      token_id: token_usage.token_id,
      user_uuid: token_usage.user_uuid,
      started_at: token_usage.started_at,
      ended_at: token_usage.ended_at
    }
  end
end
