defmodule TokenManager.Tokens.TokenManagerTest do
  use ExUnit.Case, async: false
  use ExMachina

  import TokenManager.Factory

  alias TokenManager.Tokens
  alias Tokens.TokenService
  alias Tokens.Token
  alias Tokens.Utils
  alias TokenManager.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    # Start the GenServer (therefore, initializes tokens, so sending empty arr)
    {:ok, pid} = start_supervised({Tokens.TokenManager, []})

    {:ok, tokens} = TokenService.get_all_tokens()
    {:ok, pid: pid, tokens: tokens}
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

  test "automatically releases expired tokens", %{pid: pid} do
    # Allocate a token to a user, then a usage
    token = insert(:token, status: "active", activated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
    usage = insert(:usage, token: token)

    # Update the token's activated_at to simulate expiration
    expiration_minutes = Utils.get(:max_active_token_duration_in_minutes)
    past_time =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-(expiration_minutes + 1) * 60, :second)
      |> NaiveDateTime.truncate(:second)

    Ecto.Changeset.change(token, activated_at: past_time)
    |> Repo.update!()

    # Verify token is active before expiry check
    {:ok, updated_token} = TokenService.get_one_token(token.uuid)
    assert updated_token.status == "active"

    # Trigger the expiry check
    send(pid, :check_expiry)

    # Allow time for the GenServer to process the message
    Process.sleep(50)

    # Verify the token was released
    {:ok, released_token} = TokenService.get_one_token(token.uuid)
    assert released_token.status == "available"  # This fails
    assert released_token.activated_at == past_time

    # Verify the token usage was ended
    {:ok, usages} = TokenService.get_token_usages(token.id)
    assert Enum.any?(usages, fn u -> u.id == usage.id and u.ended_at != nil end)
  end
end
