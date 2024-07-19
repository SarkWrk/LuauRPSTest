-- Inspired by: https://youtu.be/tCoEYFbDVoI ("Simulating the Evolution of Rock, Paper, Scissors" by Primer), only includes base + mutations

-- Table to easily convert between values
referenceTable = {[1] = "Rock", [2] = "Scissors", [3] = "Paper", [4] = "Lizard", ["Rock"] = 1, ["Scissors"] = 2, ["Paper"] = 3, ["Lizard"] = 4} -- Reference table to convert between an action's string descriptor and number index
winReferenceTable = {[1] = 2, [2] = 4, [4] = 3, [3] = 1} -- Table for calculating who wins "[#] beats #"
totalTypesOfActions = 4 -- Total amount of actions
totalWinsTable = {} -- Table to keep track of what wins and in how many turns
stopSimulationPlayerTable = {} -- Keep track of players who want to stop their simulation

-- Let clients know how many action tyoes there are
game:GetService("ReplicatedStorage").TotalTypes.Value = totalTypesOfActions

game:GetService("ReplicatedStorage").StopSim.OnServerEvent:Connect(function(player)
	stopSimulationPlayerTable[player.Name] = true
end)

function RemoveActionFromGroup(actionValue:number, actionsTable:any):any
	-- Remove from action group based off value
	local success:boolean, problem:string = pcall(function()
		actionsTable[referenceTable[actionValue]] -= 1
	end)
	if not success then
		warn("Given an action value (" .. actionValue ..") outside removeable scope. Did not remove any actions from '" .. actionsTable .. "'.")
		if problem then
			warn("Associated warning: " .. problem)
		else
			warn("No associated warning.")
		end
	end
	
	return actionsTable
end

local function GetRandomNumber(actionNumber:number?, disallowedNumbers:any?):number
	if actionNumber == nil then
		actionNumber = 0
	end

	local totalElements = 0
	local createATableOfAllowedNumbers = {}
	for i = 1, totalTypesOfActions do
		if not (i == actionNumber or table.find(disallowedNumbers, i)) then
			totalElements += 1
			table.insert(createATableOfAllowedNumbers, i)
		end
	end
	local ChosenNumber = createATableOfAllowedNumbers[math.random(1, totalElements)]

	-- Logging
	--for i, v in pairs(disallowedNumbers) do
		--print("Disabled: " .. referenceTable[v])
	--end
	--print("Chose: " .. referenceTable[ChosenNumber])
		
	return ChosenNumber
end

function MutateAction(actionNumber:number, arrayToReturn, mutationChance:number, repeatTImes:number):any
	debug.profilebegin("MutateAction")
	
	-- Possibly mutate an action (twice)
	for i = 1, repeatTImes do
		if math.random(1, mutationChance) == 1 then
			local mutatedAction = GetRandomNumber(actionNumber)
			
			-- Logging
			--print(referenceTable[actionNumer] .. " mutated into " .. referenceTable[mutatedAction] .. ".")
			
			arrayToReturn[referenceTable[mutatedAction]] += 1
		else
			arrayToReturn[referenceTable[actionNumber]] += 1
		end
	end
	debug.profileend()
	
	return arrayToReturn
end

function ConfigureWhoWins(firstActionValue:number, secondActionValue:number, resultsTable:any, mutations:boolean, mutationChance:number?):any
	-- Keep the tally of what to add
	local addTo = {}
	
	-- Dynamically create addTo array based on indexes within resultsTable
	for resultType, _ in pairs(resultsTable) do
		addTo[resultType] = 0
	end
	
	-- Funky mutations stuff
	local function occuredMutationSpecialAddTo(returnedArray):nil
		for returnedType, returnedValue in pairs(returnedArray) do
			for addToType, _ in pairs(addTo) do
				if returnedType == addToType then
					addTo[addToType] = returnedValue
				end
			end
		end
	end
	
	-- Use logic to figure out who wins
	if winReferenceTable[firstActionValue] == secondActionValue then -- First action wins
		if mutations then
			addTo= occuredMutationSpecialAddTo(MutateAction(firstActionValue, addTo, mutationChance, 2))
		else
			addTo[referenceTable[firstActionValue]] += 2
		end
	elseif winReferenceTable[secondActionValue] == firstActionValue then -- Second action wins
		if mutations then
			addTo= occuredMutationSpecialAddTo(MutateAction(secondActionValue, addTo, mutationChance, 2))
		else
			addTo[referenceTable[secondActionValue]] += 2
		end
	else -- Neither action affects each other
		if mutations then
			addTo = occuredMutationSpecialAddTo(MutateAction(firstActionValue, addTo, mutationChance, 1))
			addTo = occuredMutationSpecialAddTo(MutateAction(secondActionValue, addTo, mutationChance, 1))
		else
			addTo[referenceTable[firstActionValue]] += 1
			addTo[referenceTable[secondActionValue]] += 1
		end
	end
	
	-- Add to the results table and logging
	--print(resultsTable, addTo, "Before values")
	--task.synchronize()
	for resultType, _ in pairs(resultsTable) do
		for addToType, addToValue in pairs(addTo) do
			if resultType == addToType then
				--print(resultType, addToType, "Types")
				resultsTable[resultType] += addToValue
			end
		end
	end
	--task.desynchronize()
	--print(resultsTable, addTo, "After values")
	
	return resultsTable
end

function CheckIfWon(player:Player, resultsTable:any, totalActions:number, rounds:number, mutationChance:number?):boolean
	for typeOfAction, amountOfAction:number in pairs(resultsTable) do
		if amountOfAction == totalActions then
			table.insert(totalWinsTable, typeOfAction .. " wins! (" .. rounds .. ") total rounds.")
			--print(totalWinsTable)
			game:GetService("ReplicatedStorage").SimulationFinished:FireClient(player, typeOfAction, rounds, mutationChance, totalActions)
			return true
		end
	end
end

function Report(player:Player, resultsTable:any, totalActions:number):nil
	local reportString = "There are currently:"
	local firstReport = true
	for actionType, actionValue in pairs(resultsTable) do
		if firstReport == false then
			reportString = reportString .. " / " .. actionValue .. " " .. actionType .. " actions"
		else
			reportString = reportString .. " " .. actionValue .. " " .. actionType .. " actions"
			firstReport = false
		end
	end
	--print(reportString)
	game:GetService("ReplicatedStorage").ReportRound:FireClient(player, resultsTable, totalActions)
end

function StartBattle(player:Player, config:any, actionsTable:any, roundNumber:number, shouldMutate:boolean, mutationChance:number?):nil
	-- Dynamically get the total number of actions from actionsTable
	local totalActions:number = 0
	
	for acionType, actionValue in pairs(actionsTable) do
		totalActions += actionValue
	end
	
	-- Sets up the table to track results and calculates how many rounds there are (and if there's an extra action unable to fit in the rounds)
	roundNumber += 1
	local resultsTable = {}
	local remainderRounds:number = math.fmod(totalActions, 2)
	local totalRounds:number = (totalActions-remainderRounds)/2
	
	-- Dynamically create resultsTable based off totalTypesOfActions and referenceTable
	for i = 1, totalTypesOfActions do
		resultsTable[referenceTable[i]] = 0
	end
	
	-- Start tracking the time it takes for all the calculations to happen
	local startTime = tick()
	
	-- Create variables for implementing coroutines
	debug.profilebegin("Battle")
	local totalCreatedCoroutines = 0 --
	local totalWrites = 0
	local totalCoroutines= 500
	
	-- Create a table to make a table of actions that have no more actions in them
	local emptyValues = {}

	-- Runs the rounds by randomly selecting two numbers and then calculating the outcome from there
	for i = 1, totalRounds do
		
		-- Create a coroutine for multi-threading
		coroutine.resume(coroutine.create(function()
			task.desynchronize()
			totalCreatedCoroutines += 1
			
			emptyValues = {}
			
			for possibleEmptyActionType:string, totaleActions:number in pairs(actionsTable) do
				--print(possibleEmptyActionType .. " : " .. totaleActions)
				if totaleActions <= 0 then
					--print("Disallowed: " .. possibleEmptyActionType)
					table.insert(emptyValues, referenceTable[possibleEmptyActionType])
				end
			end
			
			-- Generate our action values, then remove them from the table
			local firstRandomAction:number = GetRandomNumber(nil, emptyValues)
			
			actionsTable = RemoveActionFromGroup(firstRandomAction, actionsTable)
			if actionsTable[referenceTable[firstRandomAction]] <= 0 then
				--print("Disallowed: " .. referenceTable[firstRandomAction])
				table.insert(emptyValues, firstRandomAction)
			end
			local secondRandomAction:number = GetRandomNumber(nil, emptyValues)
			actionsTable = RemoveActionFromGroup(secondRandomAction, actionsTable)

			-- Figure out which won, then change the results table
			resultsTable = ConfigureWhoWins(firstRandomAction, secondRandomAction, resultsTable, shouldMutate, mutationChance)
			totalWrites += 1
		end))
		
		-- Wait once the maximum allowed coroutines are created, then wait for them to finishing updating the table
		if totalCreatedCoroutines >= totalCoroutines then
			while totalWrites ~= totalCreatedCoroutines do
				task.wait()
				--print("Waiting for writes to finish")
			end
			--print("Writes finished")
			
			-- Reset variables
			totalCreatedCoroutines = 0
			totalWrites = 0
			
			debug.profileend()
			task.wait()
			debug.profilebegin("Battle")
		end
		--task.wait(1)
	end
	debug.profileend()
	
	-- If the time taken for calculations is less than WaitTimeAfterBattle, wait until that much time has passed
	if tick()-startTime < config.WaitTimeAfterBattle then
		while task.wait() do
			if tick()-startTime >= config.WaitTimeAfterBattle then
				break
			end
		end
	end
	
	-- Remainder just gets chucked back into the next battle (it gets lucky)
	for actionType, actionValue in pairs(actionsTable) do
		for resultType, _ in pairs(resultsTable) do
			if actionType == resultType then
				resultsTable[resultType] += actionValue
			end
		end
	end
	
	-- Report current action amount states
	Report(player, resultsTable, totalActions)
	
	-- Check if there's only one action type remaining
	local won = CheckIfWon(player, resultsTable, totalActions, roundNumber, mutationChance)
	
	-- Some more logging
	--print(actionsTable)
	--print(resultsTable)
	
	-- check if player wants to stop the battle
	if stopSimulationPlayerTable[player.Name] == true then
		stopSimulationPlayerTable[player.Name] = false
		game:GetService("ReplicatedStorage").StopSim:FireClient(player)
		won = true
	end
	
	if not won then
		StartBattle(player, config, resultsTable, roundNumber, shouldMutate, mutationChance)
	end
end

function SetupScene(player:Player, configs:any, totalActions:number, mutate:boolean, mutationChance:number?):nil
	-- Sets up a table to keep track of all the groups that actions are in and how many should be in each group based on totalActions, remainder actions are used later
	local actionsTable = {}
	local remainder:number = math.fmod(totalActions, totalTypesOfActions)
	local dividableActions:number, dividedActions:number = totalActions-remainder, (totalActions-remainder)/totalTypesOfActions
	
	-- Dynamically create actionsTable based off totalTypesOfActions and referenceTable
	for i = 1, totalTypesOfActions do
		actionsTable[referenceTable[i]] = dividedActions
	end
	
	-- Extra logging stuff
	--print(remainder, dividableActions, dividedActions)
	
	-- Distributes the remaining actions randomly to the groups
	for i = 1, remainder do
		local assignedAction = math.random(1, totalTypesOfActions)
		actionsTable[referenceTable[assignedAction]] += 1
	end
	
	-- More extra logging stuff
	--print(actionsTable, totalActions, mutationChance)
	
	-- Call on the StartBattle function with table and totalActions
	StartBattle(player, configs, actionsTable, 0, mutate, mutationChance)
end


-- Event that cals the SetupScene function (required to run code)
game:GetService("ReplicatedStorage").StartUpRemote.OnServerEvent:Connect(function(player:Player, configs:any, value:number, mutate:boolean, mutateChance:number) -- Should actions randomly change on a win?, 1/x chance
	if mutate == true then
		print("Mutations set to " .. tostring(mutate) .. " at " .. math.round((100/mutateChance)*1000)/1000 .. "% chance of mutation occuring.")
	end
	
	SetupScene(player, configs, value, mutate, mutateChance)
end)