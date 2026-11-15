--!strict
-- Remote names (GDD Appendix B). The server creates the instances in
-- ReplicatedStorage.Remotes; clients wait for them.
--
-- One RemoteFunction "Request" carries every client -> server request as
-- (name, payload) and returns a NetResult. "StatePush" is server -> client.

local Remotes = {
	FolderName = "Remotes",
	Request = "Request",
	StatePush = "StatePush",

	-- Request names (M0 subset; add the rest of Appendix B as milestones land)
	ClaimPlot = "ClaimPlot",
	ReleasePlot = "ReleasePlot",
}

return Remotes
