--[[ Copyright (c) 2024 Li Jin, dragon-fly@qq.com

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. ]]

local Struct = require("Utils").Struct
local DB = require("DB")
local thread = require("thread")

local record DoraConfig
	embed Struct.Type
	loadAsync: function(self: DoraConfig)
end

return function(schema: string, ...: string): DoraConfig
	schema = schema or ""
	local Config =
		schema == "" and
		Struct.Config(...) or
		Struct[schema].Config(...)
	local tableName = schema == "" and "Config" or schema .. ".Config"
	local conf = Config()
	local oldValues: {string: any} = {}
	local insertValues: {string: any} = {}
	local updateValues: {string: any} = {}
	local deleteValues: {string} = {}
	local loaded = false
	local function notify(event: Struct.RecordEvent, key: string, value: any)
		assert(loaded, "Config should be loaded before updating")
		if event == "Modified" then
			if oldValues[key] == nil then
				insertValues[key] = value
			elseif value == nil then
				deleteValues[#deleteValues + 1] = key
			elseif oldValues[key] ~= value then
				updateValues[key] = value
			end
			oldValues[key] = value
		elseif event == "Updated" then
			local iValues: {{string, number | boolean, string | boolean}} = {}
			for k, v in pairs(insertValues) do
				local num: boolean | number = false
				local str: boolean | string = false
				if v is number then
					num = v
				elseif v is string then
					str = v
				end
				iValues[#iValues + 1] = {k, num, str}
			end
			insertValues = {}
			local uValues: {{number | boolean, string | boolean, string}} = {}
			for k, v in pairs(updateValues) do
				local num: boolean | number = false
				local str: boolean | string = false
				if v is number then
					num = v
				elseif v is string then
					str = v
				end
				uValues[#uValues + 1] = {num, str, k}
			end
			updateValues = {}
			local dValues: {{string}} = {}
			for i = 1, #deleteValues do
				dValues[#dValues + 1] = {deleteValues[i]}
			end
			deleteValues = {}
			thread(function(): boolean
				if #iValues > 0 then
					DB:insertAsync(tableName, iValues)
				end
				if #uValues > 0 then
					DB:execAsync("update " .. tableName .. " set value_num = ?, value_str = ? where name = ?", uValues)
				end
				if #dValues > 0 then
					DB:execAsync("delete from " .. tableName .. " where name = ?", dValues)
				end
			end)
		end
	end

	if not DB:exist("Config", schema) then
		DB:exec([[
			CREATE TABLE ]] .. tableName .. [[(
				name TEXT(90) NOT NULL, --配置项名称
				value_num REAL(24,6), --配置项数值
				value_str TEXT(255), --配置项文本
				PRIMARY KEY (name)
			); --通用配置表
		]])
	end

	local function initConfig(self: DoraConfig, rows: {{string, number, string}})
		local mt = getmetatable(self) as {string}
		local fields = {}
		for i = 1, #mt do
			local fieldName = mt[i]
			fields[fieldName] = true
		end
		for i = 1, #rows do
			local key = rows[i][1]
			if fields[key] then
				local value: number | string = rows[i][2] or rows[i][3]
				oldValues[key] = value
				self[key] = value
			else
				print("Config key \"" .. key .. "\" is no longer exist")
			end
		end
	end

	rawset(conf as table, "loadAsync", function(self: DoraConfig)
		local rows = DB:queryAsync("select name, value_num, value_str from " .. tableName) as {{string, number, string}}
		loaded = true
		initConfig(self, rows)
	end)

	rawset(conf as table, "load", function(self: DoraConfig)
		local rows = DB:query("select name, value_num, value_str from " .. tableName) as {{string, number, string}}
		loaded = true
		initConfig(self, rows)
	end)

	rawset(conf as table, "__notify", notify)

	return conf as DoraConfig
end


