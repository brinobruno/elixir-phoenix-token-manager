defmodule TokenManager.Tokens.TokenServiceBehaviour do
  @callback initialize_tokens() :: list()
  @callback get_all_tokens() :: {:ok, list()}
  @callback get_one_token(String.t()) :: {:ok, map()} | {:error, atom()}
  @callback get_token_usages(integer()) :: {:ok, list()} | {:error, atom()}
  @callback allocate_token(map()) :: {:ok, map()} | {:error, map()}
  @callback release_token(map()) :: {:ok, map()} | {:error, map()}
  @callback release_tokens(list()) :: {:ok, list()} | {:error, map()}
end
