defmodule TestWebhookEvents do
  @moduledoc false
  use Spectral

  @type user_created :: TestUser.t()

  @type webhook_headers :: %{
          required(:"x-signature") => String.t(),
          optional(:"x-event-id") => non_neg_integer()
        }

  @type not_a_map :: binary()
end
