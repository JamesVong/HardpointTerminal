local config = {
	PointTime = 60; -- The number of seconds it takes to move to another point
	GroupID = 2990288;  -- Your group ID for perms
	RankNum = 1; -- Minimum rank to activate command
	MaxPoints = 100; -- Points to win
	HomeTeam = game.Teams["Defenders"]; -- Change teams to reflect the place
	AwayTeam = game.Teams["Hostiles"];
	SpectatorTeam = game.Teams["Lobby"];
	prefix = "!";
	DeathCap = false;
}

return config
