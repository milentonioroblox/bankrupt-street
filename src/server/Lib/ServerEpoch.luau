--!strict
-- One server start time (os.time) for every server-relative schedule, so rent ticks and crash
-- windows line up to the second (GDD §6.1: crashes are server-relative, not wall clock).

return os.time()
