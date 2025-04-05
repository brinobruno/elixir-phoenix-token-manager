defmodule TokenManager.Repo.Migrations.AddTokenUsagesTable do
  use Ecto.Migration

  def up do
    create table("token_usages") do
      add :token_id, references(:tokens), null: false
      add :user_uuid, :uuid, null: false
      add :started_at, :naive_datetime
      add :ended_at, :naive_datetime

      timestamps()
    end

    create index(:token_usages, [:token_id])
  end

  def down do
    nil
  end
end
