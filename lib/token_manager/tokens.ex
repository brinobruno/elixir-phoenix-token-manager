defmodule TokenManager.Tokens do
  alias TokenManager.Tokens.TokenService

  defdelegate allocate(params), to: TokenService, as: :allocate_token
  defdelegate get_all(), to: TokenService, as: :get_all_tokens
  defdelegate get_one(params), to: TokenService, as: :get_one_token
end
