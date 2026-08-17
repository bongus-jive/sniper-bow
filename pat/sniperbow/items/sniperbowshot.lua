require "/items/active/weapons/bow/abilities/bowshot.lua"

SniperBowShot = setmetatable({}, { __index = BowShot })

function SniperBowShot:fire()
  if self.doMuzzleflash ~= false then
    local variants = animator.partProperty("muzzleFlash", "variants") or 1
    animator.setPartTag("muzzleFlash", "variant", math.random(variants))
    animator.setAnimationState("muzzleFlash", "fire")
    animator.burstParticleEmitter("muzzleFlash")
    animator.playSound("fire")
    animator.playSound("fire2")
  end

  BowShot.fire(self)
end

function SniperBowShot:currentProjectileParameters()
  local perfect = self:perfectTiming()
  local cfg = root.projectileConfig(perfect and self.powerProjectileType or self.projectileType)
  local params = sb.jsonMerge(self.projectileParameters or {}, perfect and self.powerProjectileParameters or {})

  params.speed = (params.speed or cfg.speed) * root.evalFunction(self.drawSpeedMultiplier, self.drawTime)
  params.powerMultiplier = activeItem.ownerPowerMultiplier() * self.weapon.damageLevelMultiplier * root.evalFunction(self.drawPowerMultiplier, self.drawTime)

  if self.flipParameters and mcontroller.facingDirection() == -1 then
    params = sb.jsonMerge(params, self.flipParameters)
  end

  return params
end

function SniperBowShot:firePosition()
  local pos = BowShot.firePosition(self)
  local coll = world.lineCollision(mcontroller.position(), pos)
  return coll or pos
end
