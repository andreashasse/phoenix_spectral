defmodule Example.Types do
  defmodule UserId do
    @moduledoc """
    A prefixed user identifier.

    Stored internally as a plain string (e.g. `"1"`), but encoded in JSON and
    URL path segments with a `"user:"` prefix (e.g. `"user:1"`).
    """

    use Spectral
    use Spectral.Codec

    @prefix "user:"

    spectral(
      title: "User ID",
      description: "A prefixed user identifier (e.g. \"user:1\")"
    )

    @type t :: String.t()

    @impl Spectral.Codec
    def encode(_format, _caller_type_info, {:type, :t, 0}, _target_type, id, _config)
        when is_binary(id) do
      {:ok, @prefix <> id}
    end

    def encode(_format, _caller_type_info, _type_ref, _target_type, _data, _config), do: :continue

    @impl Spectral.Codec
    def decode(_format, _caller_type_info, {:type, :t, 0}, _target_type, encoded, _config)
        when is_binary(encoded) do
      prefix_len = byte_size(@prefix)

      case encoded do
        <<prefix::binary-size(prefix_len), id::binary>> when prefix == @prefix -> {:ok, id}
        _ -> {:error, ["expected ID with prefix \"#{@prefix}\", got: #{inspect(encoded)}"]}
      end
    end

    def decode(_format, _caller_type_info, _type_ref, _target_type, _input, _config), do: :continue

    @impl Spectral.Codec
    def schema(_format, _caller_type_info, {:type, :t, 0}, _target_type, _config) do
      %{type: "string", pattern: "^" <> @prefix}
    end
  end

  defmodule User do
    use Spectral

    # password_hash is stored internally but never exposed via the API.
    # The `only:` option restricts encode, decode, and schema generation to
    # the listed fields; password_hash is filled from its struct default (nil)
    # on decode and omitted on encode.
    defstruct [:id, :name, :email, :password_hash, :created_at]

    spectral(
      title: "User",
      description: "A user resource",
      only: [:id, :name, :email, :created_at],
      examples_function: {__MODULE__, :examples, []}
    )

    @type t :: %User{
            id: non_neg_integer() | nil,
            name: String.t(),
            email: String.t() | nil,
            password_hash: binary() | nil,
            created_at: DateTime.t() | nil
          }

    def examples do
      {:ok, dt, _} = DateTime.from_iso8601("2024-01-15T09:00:00Z")

      [
        %User{id: 1, name: "Alice", email: "alice@example.com", created_at: dt},
        %User{id: 2, name: "Bob", email: "bob@example.com", created_at: dt}
      ]
    end
  end

  defmodule UserInput do
    use Spectral

    # email has a nil struct default and a nullable type, so it is optional in
    # the request body — a missing email field decodes as nil rather than an error.
    defstruct [:name, email: nil]

    spectral(
      title: "UserInput",
      description: "Input for creating or updating a user. email is optional.",
      examples_function: {__MODULE__, :examples, []}
    )

    @type t :: %UserInput{
            name: String.t(),
            email: String.t() | nil
          }

    def examples do
      [
        %UserInput{name: "Alice", email: "alice@example.com"},
        %UserInput{name: "Bob"}
      ]
    end
  end

  defmodule Error do
    use Spectral

    defstruct [:message]

    spectral(
      title: "Error",
      description: "An error response",
      examples_function: {__MODULE__, :examples, []}
    )

    @type t :: %Error{message: String.t()}

    def examples do
      [
        %Error{message: "User not found"}
      ]
    end
  end
end
