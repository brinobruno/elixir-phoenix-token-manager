defmodule TokenManager.TokenUsages do
  alias TokenManager.TokenUsages.Create

  defdelegate create(params), to: Create, as: :call
end
