ExUnit.configure(max_cases: System.schedulers_online() * 4)
TestcontainersElixir.Reaper.start_link()
ExUnit.start()
