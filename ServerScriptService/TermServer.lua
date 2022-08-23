local RunService = game:GetService("RunService")

local hardpointFolder = workspace:WaitForChild("HardPoints")
local eventFolder = game.ReplicatedStorage:WaitForChild("TermEvents")
local activePoint = nil
local timeRemaining = 0

local gameActive = false
local curOwner = nil
local curCap = nil
local touchedCapEvent = nil

--// Modules
local config = require(script.Config)

--// Events
local UpdateUI = eventFolder.UpdateUI
local gameOverEvent = eventFolder:WaitForChild("GameOver")
local alertMsg = eventFolder:WaitForChild("AlertMsg")
-- Need another for settings

--// Tables
local teamScore = {
	homeTeam = 0;
	awayTeam = 0;	
}

local commands = {
	["ActivationMessage"] = {"official", "start", "startraid"};
	["EndMessage"] = {"over", "end"};
	["SetScore"] = {"set", "setscore"};
	["SetRotationTime"] = {"rotate", "setrotation", "setrotate"};
}

--// Functions
local function activatePoint(point)
	if activePoint then
		activePoint.Trigger.Transparency = 1
		activePoint.Trigger.BrickColor = BrickColor.new("White")
		activePoint.Trigger.Label.Frame.BackgroundColor3 = BrickColor.new("White").Color
		activePoint.Trigger.Label.Enabled = false
		curOwner = nil
	end;
	
	if touchedCapEvent then
		touchedCapEvent:Disconnect()
	end

	activePoint = point
	activePoint:WaitForChild("Trigger").Transparency = 0
	activePoint.Trigger.Label.Enabled = true
	timeRemaining = config.PointTime
	curOwner = nil
	curCap = point
	
	local debounce = true
	touchedCapEvent = activePoint.Trigger.Touched:Connect(function(hit)
		if hit and game.Players:FindFirstChild(hit.Parent.Name) and debounce then
			local player = game.Players[hit.Parent.Name]
			local humanoid = player.Character:FindFirstChild("Humanoid")
			if humanoid then
				if (config.DeathCap or humanoid.Health > 0) and player.Team ~= game.Teams.Lobby then
					debounce = false
					curOwner = player.Team
					activePoint:WaitForChild("Trigger").BrickColor = curOwner.TeamColor
					activePoint.Trigger.Label.Frame.BackgroundColor3 = player.TeamColor.Color
					task.wait(0.5)
					debounce = true
				end
			end
		end
	end)
end

local function SelectPoint()
	alertMsg:FireAllClients("POINT HAS MOVED", true)
	-- Move to points at random
	local list = {}
	
	for _, v in ipairs(hardpointFolder:GetChildren()) do
		if v and v ~= curCap then -- Not counting the current cap we're on
			table.insert(list,v)
		end
	end

	local index = math.random(1, #list)
	activatePoint(list[index])
end

local function EndGame(winner)
	gameOverEvent:FireAllClients(winner, config.HomeTeam.Name, config.AwayTeam.Name, teamScore.homeTeam, teamScore.awayTeam)
	gameActive = false
	timeRemaining = 0
	
	if activePoint then
		activePoint.Trigger.Transparency = 1
		activePoint.Trigger.BrickColor = BrickColor.new("White")
		activePoint.Trigger.Label.Frame.BackgroundColor3 = BrickColor.new("White").Color
		activePoint.Trigger.Label.Enabled = false
		curOwner = nil
	end;

	if touchedCapEvent then
		touchedCapEvent:Disconnect()
	end
	
	-- Team everyone to lobby and respawn them
	for _, plr in ipairs(game.Players:GetPlayers()) do
		plr.Team = config.SpectatorTeam 
		plr:LoadCharacter()
	end
end

-- https://developer.roblox.com/en-us/api-reference/property/DataModel/PrivateServerId
local function getServerType()
	if game.PrivateServerId ~= "" then
		if game.PrivateServerOwnerId ~= 0 then
			return "VIPServer"
		else
			return "ReservedServer"
		end
	else
		return "StandardServer"
	end
end

local function hasPermission(player)
	print("Checking permission...")
	-- Generally for normal raids
	if player:IsInGroup(config.GroupID) and player:GetRankInGroup(config.GroupID) >= config.RankNum then
		print(player.Name .. " has the adequate rank in configured group.")
		return true
	end
	
	-- For testing purposes in studio
	if RunService:IsStudio() then
		print("In Studio")
		return true
	end
	
	-- Private server support, owners of private servers should be able to start a raid
	if getServerType() == "VIPServer" and game.PrivateServerOwnerId == player.UserId then
		print(player.Name .. " is the private server owner.")
		return true
	end
	
	return false
end

--// Player Connections
game.Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(msg)
		if config.prefix ~= string.sub(msg, 1, 1) then return end
		
		-- For officializing
		for _, ActivationMessage in ipairs(commands.ActivationMessage) do
			if string.lower(msg) == string.lower(config.prefix .. ActivationMessage) and not gameActive then
				if hasPermission(player) then
					print("Activated")

					-- Respawn the characters on start
					for _, plr in ipairs(game.Players:GetPlayers()) do
						if plr.Team ~= config.SpectatorTeam then
							plr:LoadCharacter()
						end
					end
					
					teamScore.homeTeam = 0
					teamScore.awayTeam = 0
					UpdateUI:FireAllClients(curOwner, teamScore.homeTeam, teamScore.awayTeam, config.MaxPoints, config.HomeTeam, config.AwayTeam)
					
					-- Starting the game
					gameActive = true
					SelectPoint()
				else
					-- Error logging for rank and group configurations
					warn(player.Name .. " tried to start with invalid permission.")
					print("Player in configured group: ", player:IsInGroup(config.GroupID))
					print("Required group: " .. config.GroupID)
					print("Player at rank: " .. player:GetRankInGroup(config.GroupID))
					print("Configured Rank: " .. config.RankNum)
				end
			end
		end
		
		-- To end the match
		for _, overMessage in ipairs(commands.EndMessage) do
			if string.lower(msg) == string.lower(config.prefix .. overMessage) then
				if gameActive then
					if teamScore.homeTeam > teamScore.awayTeam then
						EndGame(config.HomeTeam)
					else
						EndGame(config.AwayTeam)
					end
				end
			end
		end
		
		-- Setting the score
		for _, setScore in ipairs(commands.SetScore) do
			local parse = string.split(msg, " ")
			if string.lower(parse[1]) == string.lower(config.prefix .. setScore) then
				-- Expect 2nd argument to be an integer
				if parse[2] then
					local newScore = tonumber(parse[2])
					config.MaxPoints = math.max(newScore, 0)
					print("Max Score Updated: " .. config.MaxPoints)
					alertMsg:FireAllClients("NEW MAX SCORE SET TO " .. config.MaxPoints, false)
					UpdateUI:FireAllClients(curOwner, teamScore.homeTeam, teamScore.awayTeam, config.MaxPoints, config.HomeTeam, config.AwayTeam)
				end
			end
		end
		
		
		-- Setting rotation time
		for _, setScore in ipairs(commands.SetRotationTime) do
			local parse = string.split(msg, " ")
			if string.lower(parse[1]) == string.lower(config.prefix .. setScore) then
				-- Expect 2nd argument to be an integer
				if parse[2] then
					local newTime = tonumber(parse[2])
					config.PointTime = math.max(newTime, 0)
					
					if gameActive then
						timeRemaining = config.PointTime
					end
					
					print("Rotation Time Updated: " .. config.PointTime)
					alertMsg:FireAllClients("NEW ROTATION TIME SET TO " .. config.PointTime, false)
					UpdateUI:FireAllClients(curOwner, teamScore.homeTeam, teamScore.awayTeam, config.MaxPoints, config.HomeTeam, config.AwayTeam)
				end
			end
		end
	end)
end)

--// Event Connection
UpdateUI.OnServerEvent:Connect(function(player)
	UpdateUI:FireAllClients(curOwner, teamScore.homeTeam, teamScore.awayTeam, config.MaxPoints, config.HomeTeam, config.AwayTeam)
end)

task.spawn(function()
	while true do
		if gameActive then
			-- Win condition
			if teamScore.homeTeam >= config.MaxPoints then
				EndGame(config.HomeTeam)
			elseif teamScore.awayTeam >= config.MaxPoints then
				EndGame(config.AwayTeam)
			end
		end
		
		-- Time to move to another point
		if gameActive and timeRemaining <= 0 then
			SelectPoint()
		end
		
		task.wait(1)
		
		if gameActive then
			if curOwner then
				if curOwner == config.HomeTeam then
					teamScore.homeTeam = teamScore.homeTeam + 1
				elseif curOwner == config.AwayTeam then
					teamScore.awayTeam = teamScore.awayTeam + 1
				end
				
				UpdateUI:FireAllClients(curOwner, teamScore.homeTeam, teamScore.awayTeam, config.MaxPoints, config.HomeTeam, config.AwayTeam)
			end
			
			timeRemaining = timeRemaining - 1
		end
	end
end)
