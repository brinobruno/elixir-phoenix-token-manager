defmodule TokenManager.Tokens.TokenServiceTest do
  use ExUnit.Case, async: true
  use ExMachina

  import Mox
  import TokenManager.Factory

  alias TokenManager.Repo
  alias TokenManager.Tokens

  alias TokenManager.TokenUsages.TokenUsage

  alias Tokens.Token
  alias Tokens.TokenService
  alias Tokens.Utils

  setup :verify_on_exit!

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    TokenService.initialize_tokens()

    # If we do not want to query all tokens on setup, uncomment
    # :ok
    {:ok, tokens} = TokenService.get_all_tokens()
    {:ok, tokens: tokens}
  end

  describe "initialize_tokens/0" do
    test "Initializes tokens successfully", %{tokens: tokens} do
      assert is_list(tokens) == true
      assert length(tokens) == Utils.get(:number_of_tokens)
      assert Enum.all?(tokens, fn token -> token.status == "available" end)
      assert Enum.all?(tokens, fn token -> token.uuid != nil end)
      assert Enum.all?(tokens, fn token -> length(token.usages) == 0 end)
      assert Enum.all?(tokens, fn token -> is_struct(token, Token) end)
    end
  end

  describe "get_one_token/1" do
    test "returns a token with preloaded usages when found" do
      token = insert(:token, status: "active", activated_at: NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second))
      insert(:usage, token: token, user_uuid: Ecto.UUID.generate())

      assert {:ok, fetched_token} = TokenService.get_one_token(token.uuid)
      assert fetched_token.id == token.id
      assert fetched_token.status == "active"
      assert length(fetched_token.usages) == 1
    end

    test "returns error when token not found" do
      assert {:error, :not_found} = TokenService.get_one_token(Ecto.UUID.generate())
    end
  end

  describe "get_token_usages/1" do
    test "Retrieves token usages successfully when 0 usages", %{tokens: tokens} do
      any_token = Enum.random(tokens)
      assert {:ok, token_usages} = TokenService.get_token_usages(any_token.id)

      assert is_list(token_usages) == true
      assert length(token_usages) == length(any_token.usages)
      assert length(token_usages) == 0
      assert Enum.all?(token_usages, fn usage -> is_struct(usage, TokenUsage) end)
    end

    test "Retrieves token usages successfully when more at least 1 usage", %{tokens: tokens} do
      available_token = Enum.random(tokens)
      user_uuid = Ecto.UUID.generate()

      {:ok, _} = TokenService.allocate_token(%{
        "token_id" => available_token.id,
        "token_uuid" => available_token.uuid,
        "user_uuid" => user_uuid
      })

      assert {:ok, token_usages} = TokenService.get_token_usages(available_token.id)
      assert {:ok, queried_token} = TokenService.get_one_token(available_token.uuid)

      assert length(token_usages) == length(queried_token.usages)
      assert length(token_usages) == 1
      assert queried_token.status == "active"
    end

    test "returns error when no usages found", %{tokens: tokens} do
      any_token = List.last(tokens)
      unexisting_token_id = any_token.id + 1
      existing_token_id = any_token.id

      assert {:error, :not_found} == TokenService.get_token_usages(unexisting_token_id)
      assert {:ok, []} == TokenService.get_token_usages(existing_token_id)
    end
  end

  describe "allocate_token/1" do
    test "Allocates a token successfully", %{tokens: tokens} do
      available_token = Enum.random(tokens)
      user_uuid = Ecto.UUID.generate()

      {:ok, usage} = TokenService.allocate_token(%{
        "token_id" => available_token.id,
        "token_uuid" => available_token.uuid,
        "user_uuid" => user_uuid
      })

      assert is_struct(usage, TokenUsage)
      assert usage.token.uuid == available_token.uuid
      assert usage.token_id == available_token.id
      assert usage.user_uuid == user_uuid
      assert usage.started_at != nil
      assert usage.ended_at == nil
      assert usage.token.status == "active"
    end

    test "returns error when allocating a token with invalid params", %{tokens: _tokens} do
      {:error, %{message: msg}} = TokenService.allocate_token(%{
        "token_id" => nil,
        "user_uuid" => nil,
        "token_uuid" => Ecto.UUID.generate(),
      })

      assert msg =~ "can't be blank"
    end
  end

  describe "release_tokens/1" do
    test "Releases all tokens successfully", %{tokens: tokens} do
      Enum.each(tokens, fn token ->
        {:ok, _} = TokenService.allocate_token(%{
          "token_id" => token.id,
          "token_uuid" => token.uuid,
          "user_uuid" => Ecto.UUID.generate()
        })
      end)

      {:ok, queried_tokens} = TokenService.get_all_tokens()
      assert Enum.all?(queried_tokens, fn token -> token.status == "active" end)

      assert {:ok, updated_tokens} = TokenService.release_tokens(tokens)
      assert is_list(updated_tokens) == true
      assert length(updated_tokens) == length(tokens)
      assert Enum.all?(updated_tokens, fn token -> token.status == "available" end)
    end
  end

  describe "release_token/1" do
    test "Releases a specific token successfully", %{tokens: tokens} do
      any_token = Enum.random(tokens)
      {:ok, _} = TokenService.allocate_token(%{
        "token_id" => any_token.id,
        "token_uuid" => any_token.uuid,
        "user_uuid" => Ecto.UUID.generate()
      })

      assert {:ok, queried_tokens} = TokenService.get_all_tokens()
      assert Enum.any?(queried_tokens, fn token ->
        token.uuid == any_token.uuid and token.status == "active"
      end)

      assert {:ok, %{token: updated_token}} = TokenService.release_token(any_token)
      assert is_struct(updated_token, Token)
      assert updated_token.status == "available"
    end
  end
end
