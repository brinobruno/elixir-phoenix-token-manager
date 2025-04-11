defmodule TokenManager.Tokens.TokenManagerTest do
  use ExUnit.Case, async: false

  alias TokenManager.Tokens
  alias Tokens.Token
  alias Tokens.Utils
  alias TokenManager.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    unless Process.whereis(Tokens.TokenManager) do
      {:ok, _pid} = start_supervised(Tokens.TokenManager)
    end

    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  test "lists all tokens" do
    assert {:ok, tokens} = Tokens.TokenManager.call(:list_tokens)
    assert is_list(tokens) == true
    assert Enum.all?(tokens, fn token -> is_struct(token, Token) end)
  end

  test "releases all tokens" do
    1..Utils.get(:number_of_tokens)
    |> Enum.map(fn _ -> Tokens.TokenManager.call(:allocate_token, %{
      "user_uuid" => Ecto.UUID.generate()
      }) end)

    assert {:ok, tokens} = Tokens.TokenManager.call(:list_tokens)
    assert Enum.all?(tokens, fn token -> token.status == "active" end)

    assert {:ok, updated_tokens} = Tokens.TokenManager.call(:release_all_tokens)
    assert Enum.all?(updated_tokens, fn token -> token.status == "available" end)
  end

  test "allocates an available token to a user" do
    user_uuid = Ecto.UUID.generate()

    assert {:ok, usage} = Tokens.TokenManager.call(:allocate_token, %{"user_uuid" => user_uuid})
    assert usage.user_uuid == user_uuid
  end
end
