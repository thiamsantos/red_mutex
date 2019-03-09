defmodule RedMutexTest.MyMutex do
  use RedMutex, otp_app: :red_mutex
end

defmodule RedMutexTest do
  use ExUnit.Case

  alias RedMutexTest.MyMutex
  require RedMutexTest.MyMutex

  setup do
    conn = start_supervised!({Redix, "redis://localhost:6379"})
    Redix.command!(conn, ["FLUSHALL"])
    Redix.command!(conn, ["SCRIPT", "FLUSH"])

    start_supervised!(MyMutex)

    wait_for_script_load(conn)

    %{conn: conn}
  end

  describe "start_link/1" do
    test "should update create an script", %{conn: conn} do
      assert [1] =
               Redix.command!(conn, [
                 "SCRIPT",
                 "EXISTS",
                 "5c252c1a0eaeeb4522fbbb982baba4e74ddfcd0d"
               ])
    end
  end

  describe "child_spec" do
    test "return correct child spec" do
      assert MyMutex.child_spec(name: :foo) == %{
               id: MyMutex,
               start: {MyMutex, :start_link, [[name: :foo]]},
               type: :supervisor
             }
    end
  end

  describe "lock/1" do
    test "expiration time"
    test "mutex format"
    test "invalid config"

    test "locked once", %{conn: conn} do
      assert Redix.command!(conn, ["GET", "key"]) == nil
      assert {:ok, mutex} = MyMutex.lock()
      assert Redix.command!(conn, ["GET", "key"]) == mutex
      assert MyMutex.lock() == {:error, :already_locked}
    end

    test "returns an valid mutex" do
      assert {:ok, mutex} = MyMutex.lock()
      assert :ok = MyMutex.unlock(mutex)
    end
  end

  describe "unlock/1" do
    test "unlock valid mutex", %{conn: conn} do
      assert {:ok, mutex} = MyMutex.lock()
      assert Redix.command!(conn, ["GET", "key"]) == mutex
      assert :ok = MyMutex.unlock(mutex)
      assert Redix.command!(conn, ["GET", "key"]) == nil
    end

    test "invalid mutex" do
      assert {:error, :unlock_fail} = MyMutex.unlock("invalid_mutex")
    end

    test "already unlocked" do
      assert {:ok, mutex} = MyMutex.lock()
      assert :ok = MyMutex.unlock(mutex)
      assert {:error, :unlock_fail} = MyMutex.unlock(mutex)
    end
  end

  describe "exists_lock" do
    test "return true when mutex is locked" do
      assert {:ok, _mutex} = MyMutex.lock()

      assert MyMutex.exists_lock() == {:ok, true}
    end

    test "return false when mutex is unlocked" do
      assert {:ok, mutex} = MyMutex.lock()
      assert :ok = MyMutex.unlock(mutex)

      assert MyMutex.exists_lock() == {:ok, false}
    end
  end

  defp wait_for_script_load(conn) do
    [response] =
      Redix.command!(conn, [
        "SCRIPT",
        "EXISTS",
        "5c252c1a0eaeeb4522fbbb982baba4e74ddfcd0d"
      ])

    if response == 1 do
      conn
    else
      wait_for_script_load(conn)
    end
  end
end
