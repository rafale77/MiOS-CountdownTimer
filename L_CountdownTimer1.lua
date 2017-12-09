--
-- Countdown Timer plugin
-- Copyright (C) 2012 Deborah Pickett
-- 
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
-- 
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
--
-- Version 0.0 2012-02-05 by Deborah Pickett
--

Duration = nil
Device = nil
ServiceId = "urn:futzle-com:serviceId:CountdownTimer1"

function initialize(lul_device)
  Device = lul_device

  Duration = luup.variable_get(ServiceId, "Duration", Device)
  if (Duration == nil) then
    -- First-run default.
    Duration = 60
    luup.variable_set(ServiceId, "Duration", Duration, Device)
  end

  -- Is a timer due? Might be recovering from a crash.
  local dueTimestamp = luup.variable_get(ServiceId, "DueTimestamp", Device)
  local counting = luup.variable_get(ServiceId, "Counting", Device)
  if (dueTimestamp ~= nil and dueTimestamp ~= ""
      and counting ~= nil and counting ~= "0") then
    -- Timer is still underway.
    return luup.call_delay("tick", 1, "") == 0
  end

  -- Initialize state variables.
  local muted = luup.variable_get(ServiceId, "Muted", Device)
  if (muted == nil) then
    luup.variable_set(ServiceId, "Muted", 0, Device)
  end
  luup.variable_set(ServiceId, "Remaining", 0, Device)
  luup.variable_set(ServiceId, "DueTimestamp", "", Device)
  luup.variable_set(ServiceId, "Counting", 0, Device)

  return true
end

function tick()
  -- Timer may have been cancelled or forced.
  -- If so, break out.
  local counting = luup.variable_get(ServiceId, "Counting", Device)
  if (counting == "0") then
    return false
  end
  if (updateRemaining()) then
    -- Timer is still underway.
    return luup.call_delay("tick", 1, "") == 0
  end
  -- Timer has completed.
  luup.variable_set(ServiceId, "DueTimestamp", "", Device)
  luup.variable_set(ServiceId, "Remaining", 0, Device)
  luup.variable_set(ServiceId, "Counting", 0, Device)
  luup.variable_set(ServiceId, "Event", 1, Device) -- 1 = complete
  luup.call_delay("resetevent", 1)
  return true
end

function StartTimer()
  local counting = luup.variable_get(ServiceId, "Counting", Device)
  if (counting == "1") then
    luup.variable_set(ServiceId, "Event", 6, Device) -- 6 = failed to start
    luup.variable_set(ServiceId, "Event", 0, Device)
    return false
  end
  return startTimerAlways()
end

function RestartTimer()
  return startTimerAlways()
end

function startTimerAlways()
  local counting = luup.variable_get(ServiceId, "Counting", Device)
  local dueTimestamp = os.time() + Duration
  luup.variable_set(ServiceId, "DueTimestamp",
    dueTimestamp, Device)
  updateRemaining()
  luup.variable_set(ServiceId, "Counting", 1, Device)
  if (counting == "1") then
    luup.variable_set(ServiceId, "Event", 7, Device) -- 7 = restart
    luup.variable_set(ServiceId, "Event", 0, Device)
		return true
  else
    luup.variable_set(ServiceId, "Event", 5, Device) -- 5 = start
    luup.variable_set(ServiceId, "Event", 0, Device)
    return luup.call_delay("tick", 1, "") == 0
  end
end

function updateRemaining()
  local dueTimestamp = luup.variable_get(ServiceId, "DueTimestamp", Device)
  local remaining = tonumber(dueTimestamp) - os.time()
  if (remaining < 0) then remaining = 0 end
  luup.variable_set(ServiceId, "Remaining", remaining, Device)
  return remaining > 0
end

function CancelTimer()
  local counting = luup.variable_get(ServiceId, "Counting", Device)
  if (counting == "0") then
    luup.variable_set(ServiceId, "Event", 4, Device) -- 4 = cancel failed
    luup.variable_set(ServiceId, "Event", 0, Device)
    return false
  end
  luup.variable_set(ServiceId, "Counting", 0, Device)
  luup.variable_set(ServiceId, "DueTimestamp", "", Device)
  luup.variable_set(ServiceId, "Remaining", 0, Device)
  luup.variable_set(ServiceId, "Event", 2, Device) -- 2 = cancelled
  luup.variable_set(ServiceId, "Event", 0, Device)
  return true
end

function ForceComplete()
  local counting = luup.variable_get(ServiceId, "Counting", Device)
  if (counting == "0") then
    luup.variable_set(ServiceId, "Event", 3, Device) -- 3 = force failed
    luup.variable_set(ServiceId, "Event", 0, Device)
    return false
  end
  luup.variable_set(ServiceId, "DueTimestamp", "", Device)
  luup.variable_set(ServiceId, "Remaining", 0, Device)
  luup.variable_set(ServiceId, "Counting", 0, Device)
  luup.variable_set(ServiceId, "Event", 1, Device) -- 1 = complete
  luup.call_delay("resetevent",1)
  return true
end

function resetevent
  luup.variable_set(ServiceId, "Event", 0, Device)
end

function SetTimerDuration(lul_device, lul_settings)
  local newDuration = lul_settings.newDuration
  Duration = tonumber(newDuration)
  luup.variable_set(ServiceId, "Duration", Duration, Device)
  return true
end

function SetMute(lul_device, lul_settings)
  local newStatus = lul_settings.newStatus
  luup.variable_set(ServiceId, "Muted", newStatus, Device)
  return true
end

