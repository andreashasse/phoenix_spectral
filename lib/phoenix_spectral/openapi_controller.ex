defmodule PhoenixSpectral.OpenAPIController do
  @moduledoc """
  A plug-and-play Phoenix controller that serves the OpenAPI spec and Swagger UI.

  ## Usage

      defmodule MyAppWeb.OpenAPIController do
        use PhoenixSpectral.OpenAPIController,
          router: MyAppWeb.Router,
          title: "My API",
          version: "1.0.0"
      end

  Then add routes in your router:

      get "/openapi", MyAppWeb.OpenAPIController, :show
      get "/swagger", MyAppWeb.OpenAPIController, :swagger

  ## Options

  - `:router` — (required) your Phoenix router module
  - `:title` — (required) API title for the OpenAPI spec
  - `:version` — (required) API version string
  - `:summary` — (optional) short summary of the API
  - `:description` — (optional) longer description of the API
  - `:terms_of_service` — (optional) URL to the terms of service
  - `:contact` — (optional) contact map with `:name`, `:url`, `:email`
  - `:license` — (optional) license map with `:name` and optional `:url`, `:identifier`
  - `:servers` — (optional) list of server objects, each with `:url` and optional `:description`
  - `:openapi_url` — URL path where the JSON spec is served, used by Swagger UI. Defaults to
    the path of this controller's `:show` route as declared in the router (scope prefixes
    included). Set explicitly to use a different path.
  - `:cache` — when `true`, the generated JSON is stored in `:persistent_term` after the first
    request and served from there on subsequent requests (default: `false`)
  """

  @metadata_keys [
    :title,
    :version,
    :summary,
    :description,
    :terms_of_service,
    :contact,
    :license,
    :servers
  ]

  defmacro __using__(opts) do
    router = Keyword.fetch!(opts, :router)
    openapi_url = Keyword.get(opts, :openapi_url)
    cache = Keyword.get(opts, :cache, false)
    metadata_kv = Keyword.take(opts, @metadata_keys)

    quote do
      use Phoenix.Controller, formats: [:html, :json]

      def show(conn, _params) do
        json =
          if unquote(cache) do
            PhoenixSpectral.OpenAPIController.fetch_json(
              __MODULE__,
              unquote(router),
              %{unquote_splicing(metadata_kv)}
            )
          else
            {:ok, iodata} =
              PhoenixSpectral.generate_openapi(unquote(router), %{unquote_splicing(metadata_kv)})

            IO.iodata_to_binary(iodata)
          end

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, json)
      end

      def swagger(conn, _params) do
        openapi_url =
          unquote(openapi_url) ||
            case Enum.find(
                   Phoenix.Router.routes(unquote(router)),
                   &(&1.plug == __MODULE__ && &1.plug_opts == :show)
                 ) do
              %{path: path} -> path
              nil -> "/openapi"
            end

        html = PhoenixSpectral.OpenAPIController.swagger_html(openapi_url)

        conn
        |> put_resp_content_type("text/html")
        |> send_resp(200, html)
      end
    end
  end

  @doc false
  def fetch_json(controller, router, metadata) do
    key = {__MODULE__, controller}

    case :persistent_term.get(key, :not_cached) do
      :not_cached ->
        {:ok, iodata} = PhoenixSpectral.generate_openapi(router, metadata)
        json = IO.iodata_to_binary(iodata)
        :persistent_term.put(key, json)
        json

      cached ->
        cached
    end
  end

  @doc false
  def swagger_html(openapi_url) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8" />
      <title>Swagger UI</title>
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <link rel="stylesheet" href="https://unpkg.com/swagger-ui-dist@5.32.0/swagger-ui.css" />
    </head>
    <body>
      <div id="swagger-ui"></div>
      <script src="https://unpkg.com/swagger-ui-dist@5.32.0/swagger-ui-bundle.js"></script>
      <script>
        SwaggerUIBundle({
          url: #{Phoenix.json_library().encode!(openapi_url)},
          dom_id: "#swagger-ui",
          presets: [SwaggerUIBundle.presets.apis, SwaggerUIBundle.SwaggerUIStandalonePreset],
          layout: "BaseLayout",
          deepLinking: true
        });
      </script>
    </body>
    </html>
    """
  end
end
