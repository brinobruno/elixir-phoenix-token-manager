defmodule TokenManager.Tokens.TokenManagerTest do
  use ExUnit.Case, async: false

  alias TokenManager.Tokens
  alias TokenManager.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    unless Process.whereis(Tokens.TokenManager) do
      {:ok, _pid} = start_supervised(Tokens.TokenManager)
    end

    # Allow the GenServer process access to the DB connection
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), Process.whereis(Tokens.TokenManager))

    :ok
  end

  test "allocates an available token to a user" do
    user_uuid = Ecto.UUID.generate()

    assert {:ok, usage} = Tokens.TokenManager.call(:allocate_token, %{"user_uuid" => user_uuid})
    assert usage.user_uuid == user_uuid
  end
end
