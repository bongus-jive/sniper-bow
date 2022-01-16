require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
	sourceId = projectile.sourceEntity()
	cfg = config.getParameter("config")
	
	shots = cfg.shots or 1
	rotationSpeed = cfg.rotationSpeed or 1
  entityBounces = cfg.entityBounces or 0
  entityBounceFactor = (cfg.entityBounceFactor or 1) * -1
end

function update(dt)
	local vel = mcontroller.velocity()
	local dir = vel[1] > 0 and 1 or -1
	local rotation = (vec2.mag(vel) / 180 * math.pi) * -dir * dt * rotationSpeed
  mcontroller.setRotation(mcontroller.rotation() + rotation)
	
	if cfg.muzzleflashActions then
		for _,action in ipairs(cfg.muzzleflashActions) do
			action.time = action.time or 0
			action["repeat"] = action["repeat"] or false
		end
	end
end

function bounce()
	--targets
	local mpos = mcontroller.position()
	local ents = world.entityQuery(mpos, 100, {withoutEntityId = sourceId, order = "nearest", includedTypes = {"creature"}})
	local target, tpos
	for _,id in ipairs(ents) do
		local epos = world.entityPosition(id)
		if world.entityCanDamage(sourceId, id) and not world.lineTileCollision(mpos, epos) then
			target = id
			tpos = epos
			break
		end
	end
	if target then
		local angle = vec2.angle(world.distance(tpos, mpos))
		mcontroller.setRotation(angle)
		mpos = mcontroller.position()
	end
	
	--projectile
	local mrot = mcontroller.rotation()
	local firePos = vec2.add(mpos, vec2.rotate(cfg.muzzleOffset, mrot))
	
	local collision = world.lineCollision(mpos, firePos)
	
	local params = {
		power = projectile.power() / cfg.projectileCount * (cfg.inheritDamageFactor or 1),
		powerMultiplier = projectile.powerMultiplier(),
		damageTeam = world.entityDamageTeam(sourceId)
	}
	if cfg.projectileParameters then
		params = sb.jsonMerge(params, cfg.projectileParameters)
	end
	
	for i = 1, cfg.projectileCount do
		if cfg.projectileParameters then
			params.speed = util.randomInRange(cfg.projectileParameters.speed)
		end
		local aimVec = vec2.rotate({1,0}, mrot + sb.nrand(cfg.inaccuracy, 0))
		world.spawnProjectile(cfg.projectileType, collision or firePos, entity.id(), aimVec, false, params)
	end
	
	--muzzleflash
	local mparams = {periodicActions = cfg.muzzleflashActions}
	if cfg.muzzleflashVariants and cfg.muzzleflashVariants > 0 then
		mparams.processing = "."..math.random(1, cfg.muzzleflashVariants)
	end
	world.spawnProjectile(cfg.muzzleflash, firePos, sourceId, vec2.rotate({1,0}, mrot), false, mparams)
end

function hit(entityId)
	--nebulox is gay
  if entityBounces ~= 0 then
		local vel = mcontroller.velocity()
		local epos = world.entityPosition(entityId)
		local estimatedPosition = vec2.mul(mcontroller.position(), vel)
		local angle = math.atan(estimatedPosition[2] - epos[2], estimatedPosition[1] - epos[1])
		
		local topQuarter = (angle < (3 * math.pi/4)) and (angle > (math.pi/4))
		local bottomQuarter = (angle < (-math.pi/4)) and (angle > (3 * -math.pi/4))
		local rightQuarter = (angle < (math.pi/4)) and (angle > (-math.pi/4))
		local leftQuarter = (angle < (3 * -math.pi/4)) and (angle > (-math.pi)) or (angle < (math.pi)) and (angle > (3 * math.pi/4))
		
		if rightQuarter or leftQuarter then
			mcontroller.setXVelocity(vel[1] * entityBounceFactor)
		elseif topQuarter or bottomQuarter then
			mcontroller.setYVelocity(vel[2] * entityBounceFactor)
		end
		if entityBounces > 0 then
      entityBounces = entityBounces - 1
    end
  end
end