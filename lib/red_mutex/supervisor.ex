defmodule RedMutex.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(mutex, otp_app, opts) do
    Supervisor.start_link(__MODULE__, {mutex, otp_app, opts},
      name: Module.concat([mutex, Supervisor])
    )
  end

  def init({mutex, otp_app, opts}) do
    url =
      otp_app
      |> Application.fetch_env!(mutex)
      |> Keyword.fetch!(:url)

    children = [
      {Redix, {url, name: mutex}},
      {RedMutex.LoadScript, mutex}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
