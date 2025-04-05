defmodule TokenManager.Repo.Migrations.AddTokensTable do
  use Ecto.Migration

  def up do
    create table("tokens") do
      add :uuid, :uuid, default: fragment("gen_random_uuid()"), null: false
      add :status, :string, default: "available"
      add :activated_at, :naive_datetime, default: nil

      timestamps()
    end

    create unique_index(:tokens, [:uuid], name: :unique_token_uuid)
  end

  def down do
    nil
  end
end
