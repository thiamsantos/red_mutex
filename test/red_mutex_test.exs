defmodule RedMutexTest do
  use ExUnit.Case

  defmodule MyMutex do
    use RedMutex, otp_app: :red_mutex
  end

  defmodule Worker do
    def perform(arg) do
      {:ok, arg}
    end
  end

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

  describe "lock/0" do
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

  describe "exists_lock/0" do
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

  describe "synchronize/1" do
    test "accepts function", %{conn: conn} do
      assert Redix.command!(conn, ["GET", "key"]) == nil

      actual =
        MyMutex.synchronize(fn ->
          assert Redix.command!(conn, ["GET", "key"]) != nil
          {:ok, "something"}
        end)

      assert Redix.command!(conn, ["GET", "key"]) == nil

      assert actual == {:ok, "something"}
    end

    test "accepts mod/fun/args" do
      actual = MyMutex.synchronize({RedMutexTest.Worker, :perform, ["arg"]})
      expected = {:ok, "arg"}

      assert actual == expected
    end

    test "capture errors", %{conn: conn} do
      assert Redix.command!(conn, ["GET", "key"]) == nil

      actual =
        MyMutex.synchronize(fn ->
          assert Redix.command!(conn, ["GET", "key"]) != nil
          raise RuntimeError, "err"
        end)

      assert Redix.command!(conn, ["GET", "key"]) == nil

      assert {:error, %RuntimeError{message: "err"}} = actual
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
