ExUnit.configure(max_cases: System.schedulers_online() * 4)
ExUnit.start()
TestcontainersElixir.ReaperSupervisor.start_link()
