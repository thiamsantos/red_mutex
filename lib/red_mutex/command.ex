defmodule RedMutex.Command do
  @moduledoc false

  @helper_script ~S"""
  if redis.call("get",KEYS[1]) == ARGV[1] then
    return redis.call("del",KEYS[1])
  else
    return 0
  end
  """

  @helper_hash :sha |> :crypto.hash(@helper_script) |> Base.encode16(case: :lower)

  def lock(conn, key, expiration_in_seconds)
      when is_atom(conn) and is_binary(key) and is_integer(expiration_in_seconds) do
    mutex = gen_mutex()

    case Redix.command(conn, ["SET", key, mutex, "NX", "EX", expiration_in_seconds]) do
      {:ok, "OK"} -> {:ok, mutex}
      {:ok, nil} -> {:error, :already_locked}
      {:error, reason} -> {:error, reason}
    end
  end

  def unlock(conn, key, mutex) when is_atom(conn) and is_binary(key) and is_binary(mutex) do
    case Redix.command(conn, ["EVALSHA", @helper_hash, "1", key, mutex]) do
      {:ok, 1} -> :ok
      {:ok, 0} -> {:error, :unlock_fail}
      {:error, reason} -> {:error, reason}
    end
  end

  def load_script!(conn) do
    @helper_hash = Redix.command!(conn, ["SCRIPT", "LOAD", @helper_script])
  end

  def exists_lock(conn, key) do
    case Redix.command(conn, ["EXISTS", key]) do
      {:ok, 1} -> {:ok, true}
      {:ok, 0} -> {:ok, false}
      {:error, reason} -> {:error, reason}
    end
  end

  defp gen_mutex do
    :sha256
    |> :crypto.hash(:crypto.strong_rand_bytes(32))
    |> Base.encode64()
  end
end
