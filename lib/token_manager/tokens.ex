defmodule TokenManager.Tokens do
  alias TokenManager.Tokens.Allocate
  alias TokenManager.Tokens.GetOne
  alias TokenManager.Tokens.GetAll

  defdelegate allocate(params), to: Allocate, as: :call
  defdelegate get_all(), to: GetAll, as: :call
  defdelegate get_one(params), to: GetOne, as: :call
end
