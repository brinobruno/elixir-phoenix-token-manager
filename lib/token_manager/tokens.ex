defmodule TokenManager.Tokens do
  alias TokenManager.Tokens.Create

  defdelegate create(params), to: Create, as: :call
end
