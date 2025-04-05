defmodule TokenManager.TokenUsages.TokenUsageTest do
  use ExUnit.Case

  import Mox

  alias TokenManager.Repo
  alias TokenManager.Tokens.Token
  alias TokenManager.TokenUsages.TokenUsage

  setup :verify_on_exit!

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    # Insert a token to associate with the usage
    {:ok, token} =
      %{status: "active"}
      |> Token.changeset()
      |> Repo.insert()

    [token: token]
  end

  describe "TokenUsage changeset" do
    test "creates a valid changeset", %{token: token} do
      params = %{
        token_id: token.id,
        user_uuid: Ecto.UUID.generate(),
        started_at: NaiveDateTime.utc_now()
      }

      changeset = TokenUsage.changeset(params)

      assert changeset.valid?
      assert changeset.errors == []
    end

    test "returns error when required fields are missing" do
      changeset = TokenUsage.changeset(%{})

      refute changeset.valid?
      assert List.keyfind(changeset.errors, :token_id, 0)
      assert List.keyfind(changeset.errors, :user_uuid, 0)
      assert List.keyfind(changeset.errors, :started_at, 0)
    end

    test "returns error for invalid user_uuid format", %{token: token} do
      params = %{
        token_id: token.id,
        user_uuid: "invalid-uuid",
        started_at: NaiveDateTime.utc_now()
      }

      changeset = TokenUsage.changeset(params)

      refute changeset.valid?
      assert {:user_uuid, {"has invalid format", _}} = List.keyfind(changeset.errors, :user_uuid, 0)
    end

    test "returns error if ended_at is before started_at" do
      started_at = ~N[2025-04-05 12:00:00]
      ended_at = ~N[2025-04-05 11:00:00]

      usage = %TokenUsage{
        token_id: 1,
        user_uuid: Ecto.UUID.generate(),
        started_at: started_at
      }

      params = %{
        token_id: 1,
        user_uuid: usage.user_uuid,
        started_at: started_at,
        ended_at: ended_at
      }

      changeset = TokenUsage.changeset(usage, params)

      refute changeset.valid?
      assert {:ended_at, {"must be after started_at", []}} in changeset.errors
    end
  end

  describe "Persistence" do
    test "persists a valid usage", %{token: token} do
      params = %{
        token_id: token.id,
        user_uuid: Ecto.UUID.generate(),
        started_at: NaiveDateTime.utc_now()
      }

      {:ok, usage} =
        params
        |> TokenUsage.changeset()
        |> Repo.insert()

      assert usage.id
      assert usage.inserted_at
      assert usage.updated_at
      assert usage.user_uuid == params.user_uuid
    end
  end
end
