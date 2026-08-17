require "/scripts/util.lua"
require "/scripts/vec2.lua"

function init()
  local cfg = config.getParameter("thrownGunConfig")
  
  local params = config.getParameter("thrownGunParameters")
  if params then cfg = sb.jsonMerge(cfg, params) end

  self.sourceId = projectile.sourceEntity() or entity.id()

  self.ammo = cfg.ammo or 1
  self.recoil = cfg.recoil
  self.hitBounceFactor = -(cfg.hitBounceFactor or 1)
  self.rotationRate = sb.nrand(cfg.rotationDeviation or 0, cfg.rotationRate or 1)

  self.emptyTimer = 0
  self.emptyTimeToLive = cfg.emptyTimeToLive or 0
  self.emptyBounces = cfg.emptyBounces or -1

  self.targetQueryRange = cfg.targetQueryRange or 100
  self.targetQueryOptions = sb.jsonMerge({
    order = "nearest",
    includedTypes = { "creature" },
    withoutEntityId = self.sourceId
  }, cfg.targetQueryOptions)
  
  self.muzzleOffset = cfg.muzzleOffset or {0, 0}
  self.projectileType = cfg.projectileType
  self.projectileDamageFactor = cfg.projectileDamageFactor or 1
  self.projectileParameters = sb.jsonMerge({ powerMultiplier = projectile.powerMultiplier() }, cfg.projectileParameters)

  self.muzzleflashType = cfg.muzzleflash
  self.muzzleflashParameters = cfg.muzzleflashParameters

  if config.getParameter("gunFlipped", false) then
    self.muzzleOffset[2] = -self.muzzleOffset[2]
  end
end

function update(dt)
  self.hasHitBounced = false
  
  if self.ammo <= 0 then
    self.emptyTimer = self.emptyTimer + dt
  elseif self.emptyTimer ~= 0 then
    self.emptyTimer = 0
  end

  local vel = mcontroller.velocity()
  local dir = vel[1] > 0 and -1 or 1
  local rot = math.rad(vec2.mag(vel)) * self.rotationRate * dir * dt
  mcontroller.setRotation(mcontroller.rotation() + rot)
end

function fireProjectile()
  if self.ammo <= 0 then return end
  self.ammo = self.ammo - 1

  snapToTarget()

  local aimAngle = mcontroller.rotation()
  local aimVector = {math.cos(aimAngle), math.sin(aimAngle)}
  local firePos, muzzlePos = firePosition(aimAngle)

  self.projectileParameters.power = projectile.power() * self.projectileDamageFactor

  world.spawnProjectile(self.projectileType, firePos, self.sourceId, aimVector, nil, self.projectileParameters)
  world.spawnProjectile(self.muzzleflashType, muzzlePos, self.sourceId, aimVector, nil, self.muzzleflashParameters)
  
  if self.recoil then
    local recoil = vec2.mul(aimVector, -self.recoil)
    mcontroller.addMomentum(recoil)
  end
end

function firePosition(angle)
  local pos = mcontroller.position()
  local muzzlePos = vec2.add(pos, vec2.rotate(self.muzzleOffset, angle))
  local firePos = world.lineCollision(pos, muzzlePos) or muzzlePos
  return firePos, muzzlePos
end

function snapToTarget()
  if self.targetQueryRange <= 0 then return end
  
  local targets = world.entityQuery(mcontroller.position(), self.targetQueryRange, self.targetQueryOptions)
  for _, id in ipairs(targets) do
    if entity.entityInSight(id) and world.entityCanDamage(entity.id(), id) then
      local angle = vec2.angle(entity.distanceToEntity(id))
      mcontroller.setRotation(angle)
      break
    end
  end
end

function hit(id)
  if self.hasHitBounced then return end
  self.hasHitBounced = true

  local vel = mcontroller.velocity()
  local pos = vec2.sub(mcontroller.position(), vec2.norm(vel))
  local diff = world.distance(world.entityPosition(id), pos)

  local norm = vec2.norm({diff[2], -diff[1]})
  local dot = vec2.dot(vel, norm) * 2
  
  mcontroller.setVelocity({
    (vel[1] - dot * norm[1]) * self.hitBounceFactor,
    (vel[2] - dot * norm[2]) * self.hitBounceFactor
  })
end

function bounce()
  fireProjectile()
  if self.emptyBounces > 0 and self.ammo <= 0 then
    self.emptyBounces = self.emptyBounces - 1
  end
end

function shouldDestroy()
  if projectile.timeToLive() <= 0 then return true end

  if self.ammo <= 0 and self.emptyTimer >= self.emptyTimeToLive and self.emptyBounces <= 0 then
    local mc = mcontroller
    if mc.zeroG() or mc.onGround() or mc.isCollisionStuck() or mc.stickingDirection() then
      return true
    end
  end

  return false
end
