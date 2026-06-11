-- ClientState
-- Tiny shared state holder so client modules don't need to re-derive
-- "am I flying?" or fight over the mouse.

local ClientState = {
	ship = nil :: Model?, -- ship currently being piloted by the local player
	menuOpen = false,     -- any full-screen panel open (unlocks the mouse)
}

local shipChanged = Instance.new("BindableEvent")
ClientState.shipChanged = shipChanged.Event

function ClientState.setShip(ship: Model?)
	if ClientState.ship ~= ship then
		ClientState.ship = ship
		shipChanged:Fire(ship)
	end
end

function ClientState.isFlying(): boolean
	local ship = ClientState.ship
	return ship ~= nil and ship.Parent ~= nil
end

return ClientState
