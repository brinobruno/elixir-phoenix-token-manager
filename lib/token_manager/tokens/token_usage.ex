defmodule TokenManager.TokenUsages.TokenUsage do
  use Ecto.Schema
  import Ecto.Changeset

  alias TokenManager.Tokens.Token

  @required_params_create [:token_id, :user_uuid, :started_at]
  @required_params_update [:token_id, :user_uuid, :started_at, :ended_at]

  @derive {Jason.Encoder, only: [:id, :token_id, :user_uuid, :started_at, :ended_at]}
  schema "token_usages" do
    field :user_uuid, :binary_id
    field :started_at, :naive_datetime
    field :ended_at, :naive_datetime
    belongs_to :token, Token

    timestamps()
  end

  # struct empty = create
  def changeset(params) do
    %__MODULE__{}
    |> cast(params, @required_params_create)
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
    |> validate_format(:user_uuid, ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
    |> validate_change(:ended_at, fn :ended_at, ended_at ->
      started_at = get_field(changeset, :started_at) || changeset.data.started_at

      case started_at do
        nil -> []
        _ when ended_at >= started_at -> []
        _ -> [ended_at: "must be after started_at"]
      end
    end)
    |> foreign_key_constraint(:token_id)
  end
end
