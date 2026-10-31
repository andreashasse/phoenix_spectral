defmodule TestWebhookEvents do
  @moduledoc false
  use Spectral

  @type user_created :: TestUser.t()

  @type payment_done :: %{required(:id) => String.t(), required(:note) => String.t() | nil}

  @type webhook_headers :: %{
          required(:"x-signature") => String.t(),
          optional(:"x-event-id") => non_neg_integer()
        }

  @type shared_headers :: TestSharedTypes.headers()

  @type not_a_map :: binary()
end
