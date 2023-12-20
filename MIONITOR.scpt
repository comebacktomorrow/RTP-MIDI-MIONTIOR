use AppleScript version "2.4"
use scripting additions
use framework "Foundation"
use framework "AppKit"

property StatusItem : missing value
property selectedMenu : "" -- each menu action will set this to a number, this will determin which IP is shown

property theDisplay : ""
property defaults : class "NSUserDefaults"
property internalMenuItem : class "NSMenuItem"
property externalMenuItem : class "NSMenuItem"
property newMenu : class "NSMenu"

-- MIONITOR (MIO MONITOR)
-- Copyright © David Tilley
-- Quick and somewhat dirty tool to gracefully disconnect RTP-Midi clients (specifically iConnectivity MIO's)
-- so that (what I assume is) a bug in Ventura and Sonoma doesn't cause the session to restart
-- and then require what ever midi host applications don't require a restart

-- Note: Devices can be referred to by their Bonjour name by using "DeviceName._udp.local" for the IP address.

-- Credits:
-- uses Late Night Software's PrefsStorageLib
-- Menu bar code based on https://apple.stackexchange.com/a/293392
-- Greatly inspired by and a a very distant decendant of https://forums.iconnectivity.com/index.php?p=/discussion/2495/auto-connect-network-midi-session-on-a-mac
-- (Feat Spiritviews Activate and Patch Midi Network Session)

--This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation,  either version 3 of the License, or (at your option) any later version.
-- This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
-- See <https://www.gnu.org/licenses/> for license details.


set bonjourName to missing value -- Replace with the actual Bonjour name

-- Number of ping attempts before considering it a failure
set maxAttempts to 5

-- Delay between successful ping attempts (in seconds)
set successInterval to 3

-- Delay between ping attempts after a failure (in seconds)
set failureInterval to 1

set sleepInterval to 10

-- state of the system
set status to -1

-- check we are running in foreground - YOU MUST RUN AS APPLICATION. to be thread safe and not crash
if not (current application's NSThread's isMainThread()) as boolean then
	display alert "This script must be run from the main thread." buttons {"Cancel"} as critical
	error number -128
end if

on menuNeedsUpdate:(menu)
	(* NSMenu's delegates method, when the menu is clicked this is called.

    We use it here to call the method makeMenus(). Which removes the old menuItems and builds new ones.

    This means the menu items can be changed dynamically.

    *)
	
	my makeMenus()
end menuNeedsUpdate:

on makeMenus()
	
	newMenu's removeAllItems() -- remove existing menu items	
	
	-- display stored ip (or not) menu item
	set storedIP to readPlist("MIOIPAddressProperty") -- read plist
	if storedIP is missing value then set storedIP to "localhost" -- if plist not found
	set currentIP to (storedIP)
	
	
	if (currentIP as string) does not contain "localhost" then
		set displayIP to (current application's NSMenuItem's alloc()'s initWithTitle:("MIO Address: " & (currentIP as string)) action:"xIPClick:" keyEquivalent:"")
		-- display dialog (currentIP as text)
		(newMenu's addItem:displayIP)
		(displayIP's setTarget:me)
	else
		set displayIP to (current application's NSMenuItem's alloc()'s initWithTitle:("MIO Address not set ") action:"xIPClick:" keyEquivalent:"")
		-- display dialog (currentIP as text)
		(newMenu's addItem:displayIP)
		(displayIP's setTarget:me)
	end if
	
	
	-- set ip menu item
	set SetIP to (current application's NSMenuItem's alloc()'s initWithTitle:"Set IP" action:"xSetIPAction:" keyEquivalent:"")
	
	(newMenu's addItem:SetIP)
	(SetIP's setTarget:me)
	
	
	-- quit menu item
	set xQuit to (current application's NSMenuItem's alloc()'s initWithTitle:"Quit" action:"xquitAction:" keyEquivalent:"")
	
	(newMenu's addItem:xQuit)
	(xQuit's setTarget:me)
	
end makeMenus



-- set ip action \ responder to menu item
on xSetIPAction:sender
	--MenuItem --do some thing 
	display dialog "Enter IP or Bonjour name of MIO" default answer "" with icon note buttons {"Cancel", "Set Address"} default button "Set Address"
	set newIP to text returned of result
	-- display dialog "Hellox, " & (newIP as string) & "."
	writePlist("MIOIPAddressProperty", (newIP as string))
	menuNeedsUpdate
	
end xSetIPAction:

-- quit action \ responder to menu item
on xquitAction:sender
	current application's NSStatusBar's systemStatusBar()'s removeStatusItem:StatusItem
	tell current application to quit
end xquitAction:

-- no action menu item
on xIPClick:sender
	--
end xIPClick:

-- create an NSStatusBar
on makeStatusBar()
	set bar to current application's NSStatusBar's systemStatusBar
	set StatusItem to bar's statusItemWithLength:-1.0
	
	-- set up the initial NSStatusBars title
	StatusItem's setTitle:"🎹"
	-- set up the initial NSMenu of the statusbar
	set newMenu to current application's NSMenu's alloc()'s initWithTitle:"Custom"
	
	newMenu's setDelegate:me (*
    Requied delegation for when the Status bar Menu is clicked  the menu will use the delegates method (menuNeedsUpdate:(menu)) to run dynamically update.


    *)
	
	StatusItem's setMenu:newMenu
	
end makeStatusBar

-- code for reading and writing defaults
on readPlist(theKey)
	set theDefaults to current application's NSUserDefaults's alloc()'s initWithSuiteName:"com.gatewaybaptistchurch.MIOIP"
	return theDefaults's objectForKey:theKey
end readPlist

on writePlist(theKey, theValue)
	set theDefaults to current application's NSUserDefaults's alloc()'s initWithSuiteName:"com.gatewaybaptistchurch.MIOIP"
	theDefaults's setObject:theValue forKey:theKey
end writePlist


my makeStatusBar()


on showMIDINetworkSetup()
	try
		activate application "Audio MIDI Setup"
		tell application "System Events"
			tell process "Audio MIDI Setup"
				keystroke return
				key code 53 (* escape *)
				try
					click menu item "Show MIDI Studio" of menu 1 of menu bar item "Window" of menu bar 1
				end try
				delay 2
				try
					click menu item "Open MIDI Network Setup…" of menu 1 of menu bar item "MIDI Studio" of menu bar 1
				end try
			end tell
		end tell
	on error
		return false
	end try
end showMIDINetworkSetup

on selectMidiSession(sessionNum)
	--activate application "Audio MIDI Setup"
	tell application "System Events"
		tell process "Audio MIDI Setup"
			try
				set numSessions to count UI elements of table 1 of scroll area 1 of group 1 of window "MIDI Network Setup"
				--log "Start: Rows to try " & numSessions - 1
				repeat with sn from 1 to numSessions - 1
					try
						-- this is the checkbox that says a session is enabled
						set theCheckbox to checkbox 1 of UI element 1 of row sn of table 1 of scroll area 1 of group 1 of window "MIDI Network Setup"
						tell theCheckbox
							set checkboxStatus to value of theCheckbox as boolean
						end tell
						
						set participants to false
						-- this is the little participants icon that appears when someone connects to a session
						set hasUsers to value of attribute "AXDescription" of image 1 of UI element 1 of row sn of table 1 of scroll area 1 of group 1 of window "MIDI Network Setup"
						if hasUsers is not equal to "" then set participants to true
						--log "Row " & sn & " is " & checkboxStatus & " participants " & participants
						
						-- if the session is enabled and there are participants, we have stuff to do!
						if checkboxStatus is equal to true and participants is true then
							--log "  proceed with disconnecting session"
							
							-- select the x session
							select row sn of table 1 of scroll area 1 of group 1 of window "MIDI Network Setup"
							
							-- participants removal block
							delay 0.5
							try
								try
									set numParticipants to count UI elements of table 1 of scroll area 1 of group 2 of window "MIDI Network Setup"
									--log "  Participants to disconnect " & numParticipants - 3
									repeat with px from 1 to numParticipants - 3
										try
											select row px of table 1 of scroll area 1 of group 2 of window "Midi Network Setup"
											click button "Disconnect" of group 2 of window "MIDI Network Setup"
										end try
									end repeat
								end try
							end try
							
							
						end if
					end try
					delay 0.5
				end repeat
				
				tell application "Audio MIDI Setup" to if it is running then quit
			end try
		end tell
	end tell
end selectMidiSession

-- Loop to perform ping attempts
repeat
	
	set bonjourName to readPlist("MIOIPAddressProperty") -- read plist
	if bonjourName is not missing value then
		-- display dialog "Pinging for " & bonjourName
		-- Perform the ping using the 'ping' command in the shell
		set ping to do shell script ("ping -c 1 " & bonjourName & "| head -2 | tail -1 |cut -d = -f 4")
		
		-- Check the result of the ping
		if ping contains "ms" then
			-- Ping successful, log the success
			--log "Ping successful for " & bonjourName
			
			if status = 2 then
				display notification "MIO connection restablished"
			end if
			
			if status = -1 then
				tell application "Finder" to activate
				display notification "MIO connection established"
			end if
			
			set status to 0
			--log status
			-- Wait for the specified interval before the next attempt
			delay successInterval
		else
			-- Ping failed, perform additional attempts with shorter intervals
			if status is not equal to 2 then
				tell application "Finder" to activate
				display notification "MIO connection is down"
				repeat with i from 1 to maxAttempts - 1
					delay failureInterval
					set status to 1
					--log status
					-- set ping to do shell script ("ping -c 1 " & bonjourName & "| head -2 | tail -1 |cut -d = -f 4")
					--log "fail " & i
					if ping contains "ms" then
						tell application "Finder" to activate
						display notification "MIO connection restored"
						exit repeat
					end if
				end repeat
			end if
			
			-- If all ping attempts fail, log the failure and disconnect the participant in the Network MIDI window
			if i = maxAttempts - 1 and status = 1 then
				--log "All ping attempts failed for " & bonjourName & " performing pre-emptive disconnection"
				tell application "Finder" to activate
				display notification "Attempting to gracefully disconnect"
				showMIDINetworkSetup()
				delay 2
				selectMidiSession(2)
				delay 2
				
				set status to 2
				tell application "Finder" to activate
				display notification "MIO connections gracefully disconnected"
			end if
			
			if status = 2 then
				--log "sleep mode"
				delay sleepInterval
			end if
		end if
	end if
end repeat
