defmodule RedMutex.LoadScript do
  @moduledoc false
  use Task, restart: :transient

  alias RedMutex.Command

  def start_link(conn) do
    Task.start_link(__MODULE__, :run, [conn])
  end

  def run(conn) do
    Command.load_script!(conn)
  end
end
