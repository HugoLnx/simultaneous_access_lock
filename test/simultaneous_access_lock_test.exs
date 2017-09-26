defmodule SimultaneousAccessLockTest do
  use ExUnit.Case
  doctest SimultaneousAccessLock

  @redis_false 0
  @redis_true 1

  setup do
    Redix.command(:redix, ["FLUSHALL"])
    :ok
  end

  describe "getting new lock" do
    test "get new lock when there are free slots" do
      assert {:ok, _} = SimultaneousAccessLock.get_lock("hugo", 2)
      assert {:ok, _} = SimultaneousAccessLock.get_lock("hugo", 2)
    end

    test "can not get a new lock when all slots are being used" do
      SimultaneousAccessLock.get_lock("hugo", 2)
      SimultaneousAccessLock.get_lock("hugo", 2)
      assert {:error, :no_slots} = SimultaneousAccessLock.get_lock("hugo", 2)
    end

    test "can get new locks after one expires" do
      SimultaneousAccessLock.get_lock("hugo", 2)
      Process.sleep(25)
      SimultaneousAccessLock.get_lock("hugo", 2)
      Process.sleep(30)
      assert {:ok, _} = SimultaneousAccessLock.get_lock("hugo", 2)
      assert {:error, :no_slots} = SimultaneousAccessLock.get_lock("hugo", 2)
    end

    test "the user key disapears if all locks expires" do
      SimultaneousAccessLock.get_lock("hugo", 2)
      Process.sleep(55)
      assert {:ok, @redis_false} = Redix.command(:redix, ["EXISTS", "lock:hugo"])
    end
  end

  describe "renewing locks" do
    test "can renew a lock that already exist" do
      {:ok, lock_id} = SimultaneousAccessLock.get_lock("hugo", 2)
      assert {:ok, lock_id} = SimultaneousAccessLock.renew_lock("hugo", lock_id)
    end

    test "can not renew a lock that does not exist" do
      SimultaneousAccessLock.get_lock("hugo", 2)
      assert {:error, :not_found} = SimultaneousAccessLock.renew_lock("hugo", "non-existent-lock")
    end

    test "can not renew a expired lock" do
      {:ok, lock_id} = SimultaneousAccessLock.get_lock("hugo", 2)
      Process.sleep(55)
      assert {:error, :not_found} = SimultaneousAccessLock.renew_lock("hugo", lock_id)
    end

    test "a renewed lock expires later" do
      {:ok, lock1_id} = SimultaneousAccessLock.get_lock("hugo", 2)
      {:ok, lock2_id} = SimultaneousAccessLock.get_lock("hugo", 2)
      Process.sleep(30)
      SimultaneousAccessLock.renew_lock("hugo", lock1_id)
      Process.sleep(25)
      assert {:ok, lock1_id} = SimultaneousAccessLock.renew_lock("hugo", lock1_id)
      assert {:error, :not_found} = SimultaneousAccessLock.renew_lock("hugo", lock2_id)
    end
  end
end
