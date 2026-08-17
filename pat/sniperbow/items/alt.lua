require "/items/active/weapons/bow/abilities/bowshot.lua"

local oldcpp = BowShot.currentProjectileParameters or function() end

function BowShot:currentProjectileParameters()
	local projectileParameters = oldcpp(self) or {}
	
	if mcontroller.facingDirection() == 1 then
		projectileParameters.gunFlipped = true
		projectileParameters.processing = "?flipy"
	end
	
	return projectileParameters
end