defmodule Example.Types do
  defmodule UserId do
    @moduledoc """
    A prefixed user identifier.

    Stored internally as a plain string (e.g. `"1"`), but encoded in JSON and
    URL path segments with a `"user:"` prefix (e.g. `"user:1"`).

    The prefix is configured via `type_parameters` so the same codec module
    could be reused for other resource types (e.g. `"org:"`) just by changing
    the annotation.
    """

    use Spectral
    use Spectral.Codec

    spectral(
      title: "User ID",
      description: "A prefixed user identifier (e.g. \"user:1\")",
      type_parameters: "user:"
    )

    @type t :: String.t()

    @impl Spectral.Codec
    def encode(_format, UserId, {:type, :t, 0}, id, _sp_type, prefix) when is_binary(id) do
      {:ok, prefix <> id}
    end

    def encode(_format, _module, _type_ref, _data, _sp_type, _params), do: :continue

    @impl Spectral.Codec
    def decode(_format, UserId, {:type, :t, 0}, encoded, _sp_type, prefix)
        when is_binary(encoded) do
      prefix_len = byte_size(prefix)

      case encoded do
        <<^prefix::binary-size(prefix_len), id::binary>> -> {:ok, id}
        _ -> {:error, ["expected ID with prefix \"#{prefix}\", got: #{inspect(encoded)}"]}
      end
    end

    def decode(_format, _module, _type_ref, _input, _sp_type, _params), do: :continue

    @impl Spectral.Codec
    def schema(_format, UserId, {:type, :t, 0}, _sp_type, prefix) do
      %{type: "string", pattern: "^" <> prefix}
    end
  end

  defmodule User do
    use Spectral

    defstruct [:id, :name, :email, :created_at]

    spectral(
      title: "User",
      description: "A user resource",
      examples_function: {__MODULE__, :examples, []}
    )

    @type t :: %User{
            id: non_neg_integer() | nil,
            name: String.t(),
            email: String.t() | nil,
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

    defstruct [:name, :email]

    spectral(
      title: "UserInput",
      description: "Input for creating or updating a user",
      examples_function: {__MODULE__, :examples, []}
    )

    @type t :: %UserInput{
            name: String.t(),
            email: String.t()
          }

    def examples do
      [
        %UserInput{name: "Alice", email: "alice@example.com"}
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
