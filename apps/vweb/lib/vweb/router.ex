defmodule Vweb.Router do
  use Vweb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {DemoWeb.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
    plug(OpenApiSpex.Plug.PutApiSpec, module: Vweb.ApiSpec)
  end

  scope "/api/v1", Vweb do
    pipe_through(:api)

    get("/nodes/list", NodeController, :list)
    get("/master_state", NodeController, :state)
    post("/update_app_version", NodeController, :update_app_version)
    post("/install_app", NodeController, :install_app)
    post("/remove_app", NodeController, :remove_app)
    post("/check_cve", NodeController, :check_node)
  end

  scope "/api" do
    pipe_through(:api)

    get("/openapi", OpenApiSpex.Plug.RenderSpec, [])
  end

  scope "/" do
    pipe_through(:browser)
    get("/swaggerui", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi")
  end
end
