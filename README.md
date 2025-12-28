# SafeConnection

SafeConnection is a server-side Luau module designed to provide a safer, standardized way to handle Roblox remotes (`RemoteEvent`, `RemoteFunction`, and `UnreliableRemoteEvent`).

It validates and sanitizes all remote arguments **before your server logic executes**, helping protect against malformed data, exploit spam, and accidental misuse.

SafeConnection focuses on being:
- Easy to use
- Explicit and configurable
- Defensive by default
- Flexible for different security needs

## What SafeConnection Protects Against

- Invalid or malicious numbers (`NaN`, `inf`)
- Oversized or abusive strings
- Invalid or unexpected argument types
- Deeply nested or cyclic tables
- Remote spam via per-player, per-remote cooldowns
- High-frequency RemoteFunction abuse

## FilterOptions Reference

The table below documents **every supported filter option**, its behavior, and its default.

| Option Name | Type | Default | Description |
|------------|------|---------|-------------|
| `BlockImpVal` | `boolean` | `false` | Blocks invalid numbers such as `NaN`, `inf`, and `-inf / -nan`. |
| `NumRange` | `{ min: number, max: number }` | No filtering | Blocks numbers outside the specified range. |
| `StrRange` | `{ min: number, max: number }` | No filtering | Restricts string length to a specific range. |
| `AllowNegetives` | `boolean` | `true` | When `false`, all negative numbers are blocked. |
| `AllowPositives` | `boolean` | `true` | When `false`, all positive numbers are blocked. |
| `AllowedTypes` | `{ string }` | No filtering | Uses `type()` to restrict Lua primitive types. |
| `AllowedTypesOf` | `{ string }` | No filtering | Uses `typeof()` to restrict Roblox-specific datatypes (recommended). |
| `FilteringStrings` | `boolean` | `false` | Filters strings using Roblox `TextService`. |
| `CoolDown` | `number` | No cooldown | Enforces a per-player, per-remote cooldown in seconds. |
| `CheckInTables` | `boolean` | `false` | Recursively validates keys and values inside tables. |
| `EniBufSize` | `number` | No check | Limits decompressed buffer size using `EncodingService:GetDecompressedBufferSize` (only typically works with EncodingService buffers). |
| `Handling` | `"Default"` \| `"Kick"` | `"Default"` | Determines how blocked remotes are handled. |
| `KickMsg` | `string` | `"Detected suspicious behavior in your client"` | Kick message used when `Handling` is `"Kick"`. |
| `CustomPunishment` | `(Player?, number?) -> ()` | `nil` | Custom async function called whenever a remote is blocked. |

---

## Built-in Safety Limits

SafeConnection enforces several internal limits to protect the server:

- Maximum table recursion depth
- Maximum table key count
- Maximum string length
- Minimum effective cooldown resolution

These limits are internal safeguards and do not require configuration unless you know what your doing.

## Important Behavioral Notes

- `AllowNegetives` and `AllowPositives` cannot both be `false`.  
  If they are, SafeConnection resets both to `true` and prints a warning.

- `AllowedTypes` uses `type()` and does not recognize Roblox-specific types.  
  Prefer `AllowedTypesOf` whenever possible.
  
- `EniBufSize` only works with compressed buffers by ``EncodingService``

- Cooldowns are enforced **per player per remote**, not globally.

- Table scanning is cycle-safe and applies to both keys and values.

- RemoteFunctions always return explicitly to prevent invocation abuse.

## Usage Examples

### Example 1: Basic Filter

A simple remote with basic number and string validation.

```Luau
local SafeConnect = require(ServerScriptService.SafeConnection)

SafeConnect({
	BlockImpVal = true,
	NumRange = { min = 0, max = 100 },
	StrRange = { min = 1, max = 32 },
}, RemoteEvent, function(player, amount, reason)
	print(player.Name, amount, reason)
end)
```

### Example 2: Advanced Filter

A more restrictive setup using type checks, table scanning, cooldowns, string character limit
```Luau
SafeConnect({
	BlockImpVal = true,
	AllowedTypesOf = { "number", "string", "Vector3", "table" },
	CheckInTables = true,
	CoolDown = 0.25,
	NumRange = { min = -50, max = 50 },
	StrRange = { min = 1, max = 64 },
}, RemoteEvent, function(player, data)
	print("Validated data from", player.Name)
end)
```

### Example 3: Custom Punishment (Reset Leaderstats)

This example applies a custom punishment when a remote is blocked by resetting all leaderstats to `0`.

```Luau
SafeConnect({
	BlockImpVal = true,
	CheckInTables = true,
	CoolDown = 0.1,
	Handling = "Default",
	CustomPunishment = function(player)
		if not player then
			return
		end

		local leaderstats = player:FindFirstChild("leaderstats")
		if not leaderstats then
			return
		end

		for _, stat in leaderstats:GetChildren() do
			if stat:IsA("NumberValue") or stat:IsA("IntValue") then
				stat.Value = 0
			end
		end
	end,
}, RemoteEvent, function(player, ...)
	print("Remote passed validation")
end)
```
> [!NOTE]
> SafeConnect returns the Remote RbxScriptConnection
> 
> another note that the module uses the metatable method ``__call`` so the required module can execute like a function ``require(module)(code)`` instead of what other modules do ``require(module).func(code)``

---

## Security Philosophy

SafeConnection is designed to:

- Fail fast
- Reject malformed or suspicious input
- Reduce trust in the client
- Encourage explicit validation
- Provide a consistent security layer for remotes

It is a defensive foundation, not a replacement for game-specific logic or permission checks.

> but.. quick reminder it still not a good idea to relay on this module heavily, we still recommend adding extra security
> this module WON'T 100% guarantee protection against exploits toward remotes

## Best Practices

- Always assume the client is untrusted
- Enable `CheckInTables` for user-supplied data
- Apply cooldowns to high-frequency or sensitive remotes
- Keep custom punishments lightweight and non-blocking

# Misc...
[![License: ](https://img.shields.io/badge/License%3A-MIT-green?style=plastic)](https://github.com/not-mentally-stable/RemoteSafeConnection//blob/main/LICENSE)

[![Scripting Language: LUAU](https://img.shields.io/badge/Scripting%20Language%3A-LUAU-blue?style=plastic)](https://github.com/luau-lang/luau)
