defmodule TokenManager.Tokens.Token do
  use Ecto.Schema
  import Ecto.Changeset

  alias TokenManager.TokenUsages.TokenUsage

  @required_params_create [:status]
  @required_params_update [:status, :activated_at]

  @derive Jason.Encoder
  schema "tokens" do
    field :uuid, :binary_id
    field :status, :string
    field :activated_at, :naive_datetime
    has_many :usages, TokenUsage

    timestamps()
  end

  # struct empty = create
  def changeset(params) do
    %__MODULE__{}
    |> cast(params, @required_params_create)
    |> put_change(:uuid, Ecto.UUID.generate())
    |> handle_validation(@required_params_create)
  end

  # struct not empty = update
  def changeset(token, params) do
    token
    |> cast(params, @required_params_update)
    |> handle_validation(@required_params_update)
  end

  defp handle_validation(changeset, fields) do
    changeset
    |> validate_required(fields)
    |> validate_inclusion(:status, ["active", "available"])
    |> unique_constraint(:uuid, name: :unique_token_uuid)
  end
end
