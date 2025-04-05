defmodule TokenManager.Tokens do
  alias TokenManager.Tokens.Create
  alias TokenManager.Tokens.GetOne
  alias TokenManager.Tokens.GetAll

  defdelegate create(params), to: Create, as: :call
  defdelegate get_all(), to: GetAll, as: :call
  defdelegate get_one(params), to: GetOne, as: :call
end
