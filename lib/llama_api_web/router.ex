defmodule LlamaApiWeb.Router do
  use LlamaApiWeb, :router

  pipeline :browser do
    plug :accepts, ["html", "json"]
    plug :fetch_session
    # plug :fetch_live_flash
    plug :fetch_flash
    # plug :put_root_layout, html: {LlamaApiWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Other scopes may use custom stacks.
  scope "/api", LlamaApiWeb do
    pipe_through :api

    scope "/v1", V1, as: :v1 do
      get "/ping",                      PageController, :ping
      post "/generate_text",            PageController, :generate_text

      scope "/threads" do                        
        post "/",                       ThreadController, :create

        scope "/:thread_id" do
          delete "/",                   ThreadController, :delete
          get "/",                      ThreadController, :show
          get "/messages",              ThreadController, :messages
          post "/messages",             ThreadController, :create_message

          scope "/runs" do
            post "/",                    ProcessRunController, :create
            scope "/:run_id" do
              get "/",                    ProcessRunController, :show
            end
          end
        end
      end

      scope "/:page_id" do
        scope "/assistant" do
          get "/",                      AssistantController, :list_assistants
          post "/create",               AssistantController, :create
          put "/",                      AssistantController, :update
          delete "/",                   AssistantController, :delete
        end
        put "/",                         PageController, :update
        delete "/",                      PageController, :delete
      end
    end
  end

  scope "/", LlamaApiWeb do
    pipe_through :browser

    get "/*path", PageController, :home
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  # if Application.compile_env(:llama_api, :dev_routes) do
  #   # If you want to use the LiveDashboard in production, you should put
  #   # it behind authentication and allow only admins to access it.
  #   # If your application does not have an admins-only section yet,
  #   # you can use Plug.BasicAuth to set up some basic authentication
  #   # as long as you are also using SSL (which you should anyway).
  #   import Phoenix.LiveDashboard.Router

  #   scope "/dev" do
  #     pipe_through :browser

  #     live_dashboard "/dashboard", metrics: LlamaApiWeb.Telemetry
  #     forward "/mailbox", Plug.Swoosh.MailboxPreview
  #   end
  # end
end
