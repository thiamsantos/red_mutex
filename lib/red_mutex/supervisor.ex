defmodule RedMutex.Supervisor do
  @moduledoc false
  use Supervisor

  def start_link(opts) do
    mutex = Keyword.fetch!(opts, :mutex)

    Supervisor.start_link(__MODULE__, opts, name: Module.concat([mutex, Supervisor]))
  end

  def init(opts) do
    mutex = Keyword.fetch!(opts, :mutex)
    url = Keyword.fetch!(opts, :url)

    children = [
      {Redix, {url, name: mutex}},
      {RedMutex.LoadScript, mutex}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
