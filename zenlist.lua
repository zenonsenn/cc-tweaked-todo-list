--[[
This code builds on top of:

Feed the World To-Do List by DALVORON
(https://pastebin.com/njt5VDtx)

ToDo-List-ComputerCraft by vol1t
(https://github.com/vol1t/ToDo-List-ComputerCraft/tree/Main)

with new features and rewritten logic.

Created for CC: Tweaked
https://tweaked.cc/
]]

-- Imports
local strings = require "cc.strings"

-- If no monitor then use computer terminal
local mon = term.native()

-- Get monitor
local periList = peripheral.getNames()
for i = 1, #periList do
    if peripheral.getType(periList[i]) == "monitor" then
        mon = peripheral.wrap(periList[i])
        print("Monitor wrapped as... " .. periList[i])
    end
end

local currentPage = 1
local highestIndex = 1
local width, height = mon.getSize()
local line = height - 3

local parseTable = {} -- Makes a table for parsing things
local todo = {} -- Initialize the 'todo' table as an empty table
local clickBounds = {} -- For clicking entry status

-- Helpers
function openTodo()
    local file = fs.open("zenlist_data", "r")
    if file ~= nil then
        local data = file.readAll()
        file.close()
        if textutils.unserialize(data) == nil then
            todo[1] = {id = 1, page = 1, text = "Hello! Use the computer or the buttons to operate this app.", status = "Not Started"}
        else
            todo = textutils.unserialize(data)
            for _, task in pairs(todo) do
                task.page = task.page or 1
                task.status = task.status or "Not Started"
            end
        end
    else
        todo[1] = {id = 1, page = 1, text = "Hello! Use the computer or the buttons to operate this app.", status = "Not Started"}
    end
end

function saveTodo()
    local file = fs.open("zenlist_data", "w")
    file.write(textutils.serialize(todo))
    file.close()
end

function getLastId()
    counter = 1
    for i = 1, #todo do
        if i < 256 then
            if todo[i] ~= nil then
                counter = todo[i].id + 1
            else
                counter = counter + 1
            end
        else
            break
        end
    end
    highestIndex = counter
    return counter
end

function getMaxPage()
    counter = 1
    for i = 1, #todo do
        if todo[i] ~= nil then
            if todo[i].page > counter then
                counter = todo[i].page
            end
        end
    end
    return counter
end

function clearTable()
    for i = 1, #parseTable do
        table.remove(parseTable, 1)
    end
end

function addEntry()
    print("Write your todo:")
    io.write("add >> ")
    input = read()
    if input == nil or input == "" then
        print("[ERROR] User didn't specify input string")
        return
    end

    if string.len(tostring(input)) > 512 then
        print("[ERROR] Input too long")
        return
    end

    local newEntry = {id = getLastId(), page = 1, text = input, status = "Not Started"}

    table.insert(todo, newEntry)
    saveTodo()

    term.setTextColor(colors.white)
    print("Working on it...")
    saveTodo()
    os.sleep(1)
    print("Entry added")
end

function editEntry(index)
    if todo[index] == nil then
        print("[ERROR] This entry does not exist")
        return
    end

    print("Old entry:")
    print(todo[index].text)
    print("Write your new entry:")
    io.write("edit >> ")
    input = read()
    if input == nil or input == "" then
        print("[ERROR] User didn't specify input string")
        return
    end

    todo[index].text = input
    term.setTextColor(colors.white)
    print("Working on it...")
    saveTodo()
    os.sleep(1)
    print("Entry updated")
end

function deleteCompletedEntry()
    -- Create a new table for non-completed tasks
    local newTodo = {}
    for i = 1, #todo do
        if todo[i].status ~= "Completed" then
            table.insert(newTodo, todo[i])
        end
    end
    -- Update the 'todo' table with the filtered list
    todo = newTodo  
    saveTodo()
end

function deleteEntryIndex(index)
    for j = index, #todo, 1 do
        todo[j] = todo[j + 1]
    end
    print("Successfully deleted entry " .. index)
    saveTodo()
end

function setMonitorColor(color)
    if mon.isColor() then
        mon.setTextColor(color)
    end
end

function displayList(p)
    getLastId()
    
    mon.clear()
    mon.setCursorPos(2, 2)
    
    setMonitorColor(colors.gray)
    mon.write("ID | Status | Entry")
    setMonitorColor(colors.white)

    local lineNumber = 3

    for i = 1, #todo do
        mon.setCursorPos(2, lineNumber)

        page = p
        if lineNumber >= height - 2 then
            -- Update all entries that didn't make the first page
            for j = i, #todo do
                todo[j].page = page + 1
            end
            return
        end

        if todo[i] ~= nil then
            if todo[i].page == p then
                todo[i].page = page
                local status = todo[i].status   
                local textColor = colors.red
                
                if status == "Completed" then
                    textColor = colors.green
                elseif status == "In Progress" then
                    textColor = colors.orange
                end
                
                mon.write(todo[i].id)
                setMonitorColor(textColor)
                mon.write("    [" .. status .. "] ")

                boundEntry = {id = i, bound = lineNumber}
                table.insert(clickBounds, boundEntry)

                setMonitorColor(colors.white)
                lines = strings.wrap(todo[i].text, width - mon.getCursorPos() - 2)
                mon.setCursorPos(mon.getCursorPos(), lineNumber)

                if #lines > height - 2 - lineNumber then
                    warningLines = strings.wrap("Entry is too long to show... it'll appear in the next page", width - mon.getCursorPos() - 2)
                    for j = i, #todo do
                        -- Push it back to the next page
                        todo[j].page = page + 1
                    end
                    for _, line in ipairs(warningLines) do
                        mon.write(line)
                        lineNumber = lineNumber + 1
                        mon.setCursorPos(21, lineNumber)
                        boundEntry = {id = i, bound = lineNumber}
                        table.insert(clickBounds, boundEntry)
                    end
                    -- Give up writing something long prematurely
                    return
                end

                for _, line in ipairs(lines) do
                    mon.write(line)
                    lineNumber = lineNumber + 1
                    mon.setCursorPos(21, lineNumber)
                    boundEntry = {id = i, bound = lineNumber}
                    table.insert(clickBounds, boundEntry)

                    if lineNumber >= height - 2 then
                        -- If the entry is long enough to exceed page boundaries,
                        -- push it back to the next page
                        for j = i, #todo do
                            todo[j].page = page + 1
                        end
                        -- I think the code just giving up would be wiser than to
                        -- implement something cleaner
                        return
                    end
                end

                lineNumber = lineNumber + 1
            end
        end
    end
    -- print("DEBUG display")
    -- for i = 1, #clickBounds do
    --     print(clickBounds[i].id .. " " .. clickBounds[i].bound)
    -- end
end

function printButtons()
    local buttonY = height - 1

    -- Add Item Button
    mon.setCursorPos(2, buttonY)
    setMonitorColor(colors.green)
    mon.write("[ Add ]")

    -- Remove Completed Button
    mon.setCursorPos(10, buttonY)
    setMonitorColor(colors.red)
    mon.write("[ Del All Completed ]")

    -- Cycle Page Button
    mon.setCursorPos(32, buttonY)
    setMonitorColor(colors.yellow)
    mon.write("[ Prev ]")

    -- Cycle Page Button
    mon.setCursorPos(41, buttonY)
    setMonitorColor(colors.yellow)
    mon.write("[ Next ]")

    mon.setCursorPos(50, buttonY)
    setMonitorColor(colors.white)
    mon.write("[ CLI ]")
end

function refreshList()
    for i = 1, tonumber(getMaxPage()) do
        displayList(i)
    end
end

-- Thread prep
openTodo()

term.clear()
term.setCursorPos(1, 1)
printButtons()
displayList(currentPage)

-- Vars for thread
local showOnce = 0

-- Main thread
while true do
    getLastId()
    clearTable()
    printButtons()

    term.setTextColor(colors.orange)
    if showOnce == 0 then
        print("To list of all commands, input the word \"help\" and then hit enter.")
        showOnce = showOnce + 1
    end

    print("Waiting for input from monitor... (this computer terminal's input is blocked)")
    event, _, x, y = os.pullEvent("monitor_touch")

    isGUI = 0
    if y >= height - 1 then
        if x <= 9 then
            -- Add
            isGUI = 1
            mon.setCursorPos(1, height - 1)
            mon.clearLine()
            mon.setCursorPos(2, height - 1)
            setMonitorColor(colors.green)
            mon.write("Add your entry from the computer")
            addEntry()
            refreshList()
        elseif x >= 10 and x <= 32 then
            -- Delete all completed entries
            isGUI = 1
            deleteCompletedEntry()
            refreshList()
            mon.setCursorPos(1, height - 1)
            mon.clearLine()
            mon.setCursorPos(2, height - 1)
            setMonitorColor(colors.red)
            mon.write("Successfully deleted all completed entries")
            os.sleep(1)
        elseif x >= 33 and x <= 40 then
            -- Previous page
            isGUI = 1
            currentPage = currentPage - 1
            if currentPage < 1 then
                currentPage = 1
            end
        elseif x >= 41 and x <= 49 then
            -- Next page
            isGUI = 1
            currentPage = currentPage + 1
        elseif x >= 50 then
            -- CLI gets activated
            mon.setCursorPos(1, height - 1)
            mon.clearLine()
            mon.setCursorPos(2, height - 1)
            setMonitorColor(colors.white)
            mon.write("Write a command on the computer")
            isGUI = 0
        end
    elseif y >= 1 and y <= height - 3 then
        isGUI = 1
        -- Initiate check bounds to get index
        local index = 0
        for i = 1, #clickBounds do
            if clickBounds[i].bound == y then
                index = clickBounds[i].id
            end
        end
        print("DEBUG index " .. index)

        if todo[index] ~= nil and index > 0 then
            if todo[index].status == "Not Started" then
                todo[index].status = "In Progress"
            elseif todo[index].status == "In Progress" then
                todo[index].status = "Completed"
            else
                todo[index].status = "Not Started"
            end
            saveTodo()
        end
    end

    if isGUI == 0 then
        -- Wait for user input
        io.write("main >> ")
        input = read()

        for parse in string.gmatch(input, "%S+") do
            table.insert(parseTable, parse)
        end

        if parseTable[1] == "exit" then 
            print("Shutting down app...")
            break
        elseif parseTable[1] == "refr" then
            refreshList()
            clearTable()
        elseif parseTable[1] == "add" then
            addEntry()
            clearTable()
        elseif parseTable[1] == "edit" then
            editEntry(tonumber(parseTable[2]))
            clearTable()
        elseif parseTable[1] == "del" or parseTable[1] == "delete" then
            deleteEntryIndex(tonumber(parseTable[2]))
            clearTable()
        elseif parseTable[1] == "help" then
            term.clear()
            term.setCursorPos(1,1)
            print("Available commands:")
            print("* add   Invokes add wizard, e.g. \"add\"")
            print("* edit  \"edit <id>\", e.g. \"edit 3\"")
            print("* del   \"del <id>\", e.g. \"del 3\"")
            print("* refr  Refresh page, e.g. \"refr\"")
            print("* exit  Exit app, e.g. \"exit\"")
            clearTable()
        end
    end

    displayList(currentPage)
end