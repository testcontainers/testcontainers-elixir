{:ok, _} = TestcontainersElixir.Reaper.start_link()
ExUnit.configure(max_cases: System.schedulers_online() * 4)
ExUnit.start()
