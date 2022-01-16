require "/scripts/vec2.lua"

SniperBowShot = WeaponAbility:new()

function SniperBowShot:init()
  self.energyPerShot = self.energyPerShot or 0

  self.drawTime = 0
  self.cooldownTimer = self.cooldownTime

  self:reset()

  self.weapon.onLeaveAbility = function()
    self:reset()
  end
end

function SniperBowShot:update(dt, fireMode, shiftHeld)
  WeaponAbility.update(self, dt, fireMode, shiftHeld)

  self.cooldownTimer = math.max(0, self.cooldownTimer - self.dt)

  if not self.weapon.currentAbility and self.fireMode == (self.activatingFireMode or self.abilitySlot) and self.cooldownTimer == 0 and (self.energyPerShot == 0 or not status.resourceLocked("energy")) then
    self:setState(self.draw)
  end
end

function SniperBowShot:uninit()
  self:reset()
end

function SniperBowShot:reset()
  animator.setGlobalTag("drawFrame", "0")
  self.weapon:setStance(self.stances.idle)
end

function SniperBowShot:draw()
  self.weapon:setStance(self.stances.draw)

  animator.playSound("draw")

  while self.fireMode == (self.activatingFireMode or self.abilitySlot) do
    if self.walkWhileFiring then mcontroller.controlModifiers({runningSuppressed = true}) end

    self.drawTime = self.drawTime + self.dt

    local drawFrame = math.floor(root.evalFunction(self.drawFrameSelector, self.drawTime))
    animator.setGlobalTag("drawFrame", drawFrame)
    self.stances.draw.frontArmFrame = self.drawArmFrames[drawFrame + 1]

    coroutine.yield()
  end

  self:setState(self.fire)
end

function SniperBowShot:fire()
  self.weapon:setStance(self.stances.fire)
	
	animator.setPartTag("muzzleFlash", "variant", math.random(1, 3))
	animator.setAnimationState("muzzleFlash", "fire")
	animator.burstParticleEmitter("muzzleFlash")
	animator.playSound("fire")

  animator.stopAllSounds("draw")
  animator.setGlobalTag("drawFrame", "0")

  if not world.pointTileCollision(self:firePosition()) and status.overConsumeResource("energy", self.energyPerShot) then
    world.spawnProjectile(
        self:perfectTiming() and self.powerProjectileType or self.projectileType,
        self:firePosition(),
        activeItem.ownerEntityId(),
        self:aimVector(),
        false,
        self:currentProjectileParameters()
      )

    if self:perfectTiming() then
      animator.playSound("perfectRelease")
    else
      animator.playSound("release")
    end

    self.drawTime = 0

    util.wait(self.stances.fire.duration)
  else
    self.drawTime = 0
  end

  self.cooldownTimer = self.cooldownTime
end

function SniperBowShot:perfectTiming()
  return self.drawTime > self.powerProjectileTime[1] and self.drawTime < self.powerProjectileTime[2]
end

function SniperBowShot:currentProjectileParameters()
  local projectileParameters = copy(self.projectileParameters or {})
  local projectileConfig = root.projectileConfig(self:perfectTiming() and self.powerProjectileType or self.projectileType)
  projectileParameters.speed = projectileParameters.speed or projectileConfig.speed
  projectileParameters.speed = projectileParameters.speed * root.evalFunction(self.drawSpeedMultiplier, self.drawTime)
  projectileParameters.power = projectileParameters.power or projectileConfig.power
  projectileParameters.power = projectileParameters.power
      * self.weapon.damageLevelMultiplier
      * root.evalFunction(self.drawPowerMultiplier, self.drawTime)
  projectileParameters.powerMultiplier = activeItem.ownerPowerMultiplier()

  return projectileParameters
end

function SniperBowShot:aimVector()
  local aimVector = vec2.rotate({1, 0}, self.weapon.aimAngle + sb.nrand(self.inaccuracy or 0, 0))
  aimVector[1] = aimVector[1] * self.weapon.aimDirection
  return aimVector
end

function SniperBowShot:firePosition()
  return vec2.add(mcontroller.position(), activeItem.handPosition(self.fireOffset))
end
