defmodule TestUser do
  @moduledoc false
  use Spectral

  defstruct id: nil, name: nil, email: nil

  spectral(title: "User", description: "A user resource")

  @type t :: %TestUser{
          id: non_neg_integer() | nil,
          name: String.t() | nil,
          email: String.t() | nil
        }
end

defmodule TestUserInput do
  @moduledoc false
  use Spectral

  defstruct name: nil, email: nil

  spectral(title: "UserInput", description: "Input for creating a user")

  @type t :: %TestUserInput{
          name: String.t() | nil,
          email: String.t() | nil
        }
end

defmodule TestUserPublic do
  @moduledoc false
  use Spectral

  defstruct id: nil, name: nil, email: nil, password_hash: nil

  spectral(
    title: "User (Public)",
    description: "User response without sensitive fields",
    only: [:id, :name, :email]
  )

  @type t :: %TestUserPublic{
          id: non_neg_integer() | nil,
          name: String.t() | nil,
          email: String.t() | nil,
          password_hash: String.t() | nil
        }
end

defmodule TestError do
  @moduledoc false
  use Spectral

  defstruct [:message]

  spectral(title: "Error", description: "An error response")
  @type t :: %TestError{message: String.t()}
end
